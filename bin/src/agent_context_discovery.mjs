#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";

const SCHEMA = "erect-agent-stack/latest-context/v1";
const MAX_PROVIDER_DIRECTORIES = 2048;
let configurationError = null;
let MAX_FILES = 4096;
try {
	MAX_FILES = parseLimit(process.env.ERECT_CONTEXT_MAX_FILES, MAX_FILES);
} catch (error) {
	configurationError = error;
}
const MAX_JSON_BYTES = 1024 * 1024;
const JSONL_HEAD_BYTES = 64 * 1024;
const JSONL_TAIL_BYTES = 256 * 1024;

function parseLimit(raw, fallback) {
	if (raw === undefined) return fallback;
	if (!/^[1-9][0-9]{0,5}$/.test(raw)) throw new Error("ERECT_CONTEXT_MAX_FILES must be 1..999999");
	return Number(raw);
}

function storagePath(environmentName, fallback) {
	return process.env[environmentName] || fallback;
}

function statState(file) {
	try {
		return { status: "present", stat: fs.statSync(file) };
	} catch (error) {
		if (error?.code === "ENOENT") return { status: "missing" };
		return { status: "unreadable", error };
	}
}

function errorText(error) {
	return error instanceof Error ? error.message : String(error);
}

function canonicalExisting(value) {
	try {
		return fs.realpathSync(value);
	} catch {
		return path.resolve(value);
	}
}

function sameProject(value, project) {
	return typeof value === "string" && value.length > 0 && canonicalExisting(value) === project;
}

function parseTimestamp(value) {
	if (typeof value === "number" && Number.isFinite(value) && value > 0) {
		const milliseconds = Math.trunc(value);
		return { rankNs: BigInt(milliseconds) * 1000000n, milliseconds };
	}
	if (typeof value !== "string" || value.length === 0) return null;
	const precise = value.match(/^(.*T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:\d{2})$/);
	if (precise) {
		const seconds = Date.parse(`${precise[1]}${precise[3]}`);
		if (Number.isFinite(seconds)) {
			const fraction = (precise[2] || "").slice(0, 9).padEnd(9, "0");
			const rankNs = BigInt(seconds) * 1000000n + BigInt(fraction || "0");
			return { rankNs, milliseconds: Number(rankNs / 1000000n) };
		}
	}
	const milliseconds = Date.parse(value);
	if (!Number.isFinite(milliseconds)) return null;
	return { rankNs: BigInt(milliseconds) * 1000000n, milliseconds };
}

function makeRecord(backend, sessionId, timestamp, sourcePath, evidence, extra = {}) {
	const parsed = parseTimestamp(timestamp);
	if (typeof sessionId !== "string" || sessionId.length === 0 || !parsed) return null;
	return {
		backend,
		session_id: sessionId,
		conversation_timestamp: typeof timestamp === "string" ? timestamp : new Date(parsed.milliseconds).toISOString(),
		timestamp_ms: parsed.milliseconds,
		source_path: sourcePath,
		confidence: "exact",
		evidence,
		_rank_ns: parsed.rankNs,
		...extra,
	};
}

function outputRecord(record) {
	if (!record) return null;
	const { _rank_ns, ...output } = record;
	return output;
}

function warning(backend, code, message, extra = {}) {
	return { backend, code, message, ...extra };
}

function provider(status = "ok") {
	return { status, candidates: [], excluded_children: [], warnings: [], _blocking: [], _unknown_blocking: false };
}

function boundedJson(file) {
	const state = statState(file);
	if (state.status !== "present") throw state.error || Object.assign(new Error(`missing file: ${file}`), { code: "ENOENT" });
	if (!state.stat.isFile()) throw new Error(`not a regular file: ${file}`);
	if (state.stat.size > MAX_JSON_BYTES) throw new Error(`JSON metadata exceeds ${MAX_JSON_BYTES} bytes: ${file}`);
	return JSON.parse(fs.readFileSync(file, "utf8"));
}

function readRange(file, offset, length) {
	const descriptor = fs.openSync(file, "r");
	try {
		const buffer = Buffer.alloc(length);
		const bytesRead = fs.readSync(descriptor, buffer, 0, length, offset);
		return buffer.subarray(0, bytesRead).toString("utf8");
	} finally {
		fs.closeSync(descriptor);
	}
}

function boundedJsonl(file) {
	const state = statState(file);
	if (state.status !== "present") throw state.error || Object.assign(new Error(`missing file: ${file}`), { code: "ENOENT" });
	if (!state.stat.isFile()) throw new Error(`not a regular file: ${file}`);
	const size = state.stat.size;
	const chunks = [];
	const headLength = Math.min(size, JSONL_HEAD_BYTES);
	let head = readRange(file, 0, headLength);
	if (headLength < size && !head.endsWith("\n")) head = head.slice(0, head.lastIndexOf("\n") + 1);
	chunks.push(head);
	if (size > headLength) {
		const tailStart = Math.max(headLength, size - JSONL_TAIL_BYTES);
		let tail = readRange(file, tailStart, size - tailStart);
		if (tailStart > 0) {
			const firstNewline = tail.indexOf("\n");
			tail = firstNewline === -1 ? "" : tail.slice(firstNewline + 1);
		}
		chunks.push(tail);
	}
	const records = [];
	for (const line of chunks.join("\n").split("\n")) {
		if (line.length === 0) continue;
		try {
			records.push(JSON.parse(line));
		} catch {
			// Bounded edge fragments and interrupted final writes are not records.
		}
	}
	return { records, size };
}

function listDirectories(directory) {
	const entries = fs.readdirSync(directory, { withFileTypes: true });
	if (entries.length > MAX_PROVIDER_DIRECTORIES) throw new Error(`directory limit exceeded at ${directory}`);
	return entries.filter((entry) => entry.isDirectory());
}

function listFiles(directory) {
	return fs.readdirSync(directory, { withFileTypes: true }).filter((entry) => entry.isFile());
}

function discoverCodex(project, home) {
	const result = provider();
	const databasePath = path.join(home, "state_5.sqlite");
	const state = statState(databasePath);
	if (state.status === "missing") return provider("missing");
	if (state.status === "unreadable" || !state.stat.isFile()) return unreadableProvider("codex", databasePath, state.error || new Error("not a regular file"));
	let database;
	try {
		database = new DatabaseSync(databasePath, { readOnly: true });
		database.exec("PRAGMA query_only = ON");
		const columns = new Set(database.prepare("PRAGMA table_info(threads)").all().map((row) => row.name));
		for (const required of ["id", "cwd", "rollout_path", "source"]) {
			if (!columns.has(required)) throw new Error(`threads table lacks ${required}`);
		}
		if (!columns.has("updated_at_ms") && !columns.has("updated_at")) throw new Error("threads table lacks an update timestamp");
		const optional = (name, fallback = "NULL") => columns.has(name) ? name : `${fallback} AS ${name}`;
		const query = `SELECT id,cwd,rollout_path,source,${optional("updated_at")},${optional("updated_at_ms")},${optional("thread_source")},${optional("agent_path")} FROM threads`;
		for (const row of database.prepare(query).iterate()) {
			if (!sameProject(row.cwd, project)) continue;
			const timestamp = Number.isFinite(row.updated_at_ms) && row.updated_at_ms > 0 ? row.updated_at_ms : Number(row.updated_at) * 1000;
			const sourceObject = typeof row.source === "string" && row.source.startsWith("{") ? safeJson(row.source) : null;
			const child = row.thread_source === "subagent" || (typeof row.agent_path === "string" && row.agent_path.length > 0) || sourceObject?.subagent !== undefined;
			const record = makeRecord("codex", row.id, timestamp, row.rollout_path, ["threads.cwd exact project match", "threads update timestamp", "native rollout path"]);
			if (!record) {
				result.warnings.push(warning("codex", "codex_invalid_thread_record", "Ignored a matching thread with an invalid ID or timestamp.", { source_path: databasePath }));
				continue;
			}
			if (child) {
				result.excluded_children.push({ ...record, reason: "subagent thread is not an automatic root resume candidate" });
				continue;
			}
			const rolloutState = statState(row.rollout_path);
			if (rolloutState.status !== "present" || !rolloutState.stat.isFile()) {
				const item = warning("codex", "codex_native_record_missing", "Thread metadata matches the project, but its native rollout is unavailable.", {
					session_id: row.id,
					conversation_timestamp: record.conversation_timestamp,
					source_path: row.rollout_path,
				});
				result.warnings.push(item);
				result._blocking.push(record);
				continue;
			}
			result.candidates.push(record);
		}
	} catch (error) {
		return unreadableProvider("codex", databasePath, error);
	} finally {
		try { database?.close(); } catch {}
	}
	return result;
}

function safeJson(value) {
	try { return JSON.parse(value); } catch { return null; }
}

function unreadableProvider(backend, sourcePath, error) {
	const result = provider("unreadable");
	result.warnings.push(warning(backend, `${backend}_storage_unreadable`, `Cannot read ${backend} native storage: ${errorText(error)}`, { source_path: sourcePath }));
	return result;
}

function discoverClaude(project, home) {
	const projectsRoot = path.join(home, "projects");
	const state = statState(projectsRoot);
	if (state.status === "missing") return provider("missing");
	if (state.status === "unreadable" || !state.stat.isDirectory()) return unreadableProvider("claude", projectsRoot, state.error || new Error("not a directory"));
	const result = provider();
	let seenFiles = 0;
	const scanned = new Set();
	try {
		const directories = listDirectories(projectsRoot);
		const transcriptFiles = [];
		for (const entry of directories) {
			const pending = [{ directory: path.join(projectsRoot, entry.name), depth: 0 }];
			while (pending.length > 0) {
				const current = pending.pop();
				for (const child of fs.readdirSync(current.directory, { withFileTypes: true })) {
					seenFiles += 1;
					if (seenFiles > MAX_FILES) throw new Error(`file limit exceeded at ${projectsRoot}`);
					const childPath = path.join(current.directory, child.name);
					if (child.isFile() && child.name.endsWith(".jsonl")) transcriptFiles.push(childPath);
					if (child.isFile() && child.name === "sessions-index.json") inspectClaudeIndex(childPath, project, result, transcriptFiles);
					if (child.isDirectory() && current.depth < 2) pending.push({ directory: childPath, depth: current.depth + 1 });
				}
			}
		}
		for (const file of transcriptFiles) {
			const canonicalFile = canonicalExisting(file);
			if (scanned.has(canonicalFile)) continue;
			scanned.add(canonicalFile);
			inspectClaudeTranscript(file, project, result);
		}
	} catch (error) {
		return unreadableProvider("claude", projectsRoot, error);
	}
	return result;
}

function inspectClaudeIndex(file, project, result, transcriptFiles) {
	let index;
	try {
		index = boundedJson(file);
	} catch (error) {
		result.warnings.push(warning("claude", "claude_index_unreadable", `Cannot read Claude session index: ${errorText(error)}`, { source_path: file }));
		return;
	}
	const entries = Array.isArray(index.entries) ? index.entries.slice(0, MAX_FILES) : [];
	for (const entry of entries) {
		if (sameProject(entry.projectPath, project) && typeof entry.fullPath === "string") {
			const transcriptState = statState(entry.fullPath);
			if (transcriptState.status === "present" && transcriptState.stat.isFile()) transcriptFiles.push(entry.fullPath);
			else {
				const unavailable = makeRecord("claude", entry.sessionId, entry.modified, entry.fullPath, ["session index projectPath exact match", "indexed conversation timestamp"]);
				result.warnings.push(warning("claude", "claude_index_record_unavailable", "Claude index matches this project, but the referenced transcript is unavailable.", {
					session_id: entry.sessionId,
					conversation_timestamp: unavailable?.conversation_timestamp,
					source_path: entry.fullPath,
				}));
				if (unavailable) result._blocking.push(unavailable);
				else result._unknown_blocking = true;
			}
		} else if (
			typeof entry.projectPath === "string" &&
			path.basename(entry.projectPath) === path.basename(project) &&
			entry.projectPath !== project &&
			typeof entry.fullPath === "string" &&
			statState(entry.fullPath).status === "missing"
		) {
			result.warnings.push(warning("claude", "claude_moved_index_record", "Claude index references a similarly named project at another path; no relocation was inferred.", { session_id: entry.sessionId, indexed_project: entry.projectPath, source_path: entry.fullPath }));
		}
	}
}

function inspectClaudeTranscript(file, project, result) {
	let records;
	try {
		records = boundedJsonl(file).records;
	} catch (error) {
		result.warnings.push(warning("claude", "claude_transcript_unreadable", `Cannot read Claude transcript: ${errorText(error)}`, { source_path: file }));
		return;
	}
	const sessions = new Map();
	for (const record of records) {
		if (record?.type !== "user" && record?.type !== "assistant") continue;
		if (!sameProject(record.cwd, project)) continue;
		const parentSessionId = typeof record.sessionId === "string" && record.sessionId.length > 0 ? record.sessionId : path.basename(file, ".jsonl");
		const sessionId = record.isSidechain === true && typeof record.agentId === "string" && record.agentId.length > 0 ? record.agentId : parentSessionId;
		const candidate = makeRecord("claude", sessionId, record.timestamp, file, ["transcript record cwd exact project match", "native message timestamp"]);
		if (!candidate) continue;
		const key = `${record.isSidechain === true ? "child" : "root"}\0${sessionId}`;
		const current = sessions.get(key);
		if (!current || candidate._rank_ns > current._rank_ns) sessions.set(key, candidate);
	}
	for (const [key, record] of sessions) {
		if (key.startsWith("child\0")) result.excluded_children.push({ ...record, reason: "sidechain transcript is not an automatic root resume candidate" });
		else result.candidates.push(record);
	}
}

function discoverGrok(project, home) {
	const sessionsRoot = path.join(home, "sessions");
	const state = statState(sessionsRoot);
	if (state.status === "missing") return provider("missing");
	if (state.status === "unreadable" || !state.stat.isDirectory()) return unreadableProvider("grok", sessionsRoot, state.error || new Error("not a directory"));
	const result = provider();
	const nativeById = new Map();
	let sessionCount = 0;
	try {
		for (const projectEntry of listDirectories(sessionsRoot)) {
			const projectDirectory = path.join(sessionsRoot, projectEntry.name);
			let decodedDirectory = null;
			try { decodedDirectory = decodeURIComponent(projectEntry.name); } catch {}
			const nativeDirectoryMatches = sameProject(decodedDirectory, project);
			for (const sessionEntry of listDirectories(projectDirectory)) {
				sessionCount += 1;
				if (sessionCount > MAX_FILES) throw new Error(`session limit exceeded at ${sessionsRoot}`);
				const sessionDirectory = path.join(projectDirectory, sessionEntry.name);
				const summaryPath = path.join(sessionDirectory, "summary.json");
				if (statState(summaryPath).status !== "present") {
					if (nativeDirectoryMatches) {
						result.warnings.push(warning("grok", "grok_summary_unavailable", "Grok native session directory matches the project, but its summary is unavailable.", { session_id: sessionEntry.name, source_path: summaryPath }));
						result._unknown_blocking = true;
					}
					continue;
				}
				let summary;
				try { summary = boundedJson(summaryPath); }
				catch (error) {
					result.warnings.push(warning("grok", "grok_summary_unreadable", `Cannot read Grok summary: ${errorText(error)}`, { source_path: summaryPath }));
					if (nativeDirectoryMatches) result._unknown_blocking = true;
					continue;
				}
				const cwdProof = [summary?.info?.cwd, summary?.git_root_dir, decodedDirectory].find((value) => sameProject(value, project));
				if (!cwdProof) continue;
				const sessionId = summary?.info?.id || sessionEntry.name;
				const timestamps = [summary.updated_at, summary.last_active_at]
					.map((value) => ({ value, parsed: parseTimestamp(value) }))
					.filter((item) => item.parsed);
				if (timestamps.length === 0) {
					result.warnings.push(warning("grok", "grok_summary_timestamp_invalid", "Grok summary matches the project but has no valid conversation timestamp.", { session_id: sessionId, source_path: summaryPath }));
					continue;
				}
				const latest = timestamps.reduce((left, right) => right.parsed.rankNs > left.parsed.rankNs ? right : left);
				const chatPath = path.join(sessionDirectory, "chat_history.jsonl");
				const chatState = statState(chatPath);
				const record = makeRecord("grok", sessionId, latest.value, summaryPath, ["summary cwd metadata or reversible native directory exact project match", "summary activity timestamp", "native chat history"]);
				if (chatState.status !== "present" || !chatState.stat.isFile()) {
					result.warnings.push(warning("grok", "grok_native_record_missing", "Grok summary matches the project, but its native chat history is unavailable.", { session_id: sessionId, conversation_timestamp: record?.conversation_timestamp, source_path: chatPath }));
					if (record) result._blocking.push(record);
					continue;
				}
				if (record) {
					result.candidates.push(record);
					nativeById.set(sessionId, record);
				}
			}
		}
		inspectGrokIndex(path.join(sessionsRoot, "session_search.sqlite"), project, result, nativeById);
	} catch (error) {
		return unreadableProvider("grok", sessionsRoot, error);
	}
	return result;
}

function inspectGrokIndex(databasePath, project, result, nativeById) {
	const state = statState(databasePath);
	if (state.status === "missing") return;
	if (state.status !== "present" || !state.stat.isFile()) {
		result.warnings.push(warning("grok", "grok_search_index_unreadable", "Grok search index is unavailable; native sessions were still inspected.", { source_path: databasePath }));
		return;
	}
	let database;
	try {
		database = new DatabaseSync(databasePath, { readOnly: true });
		database.exec("PRAGMA query_only = ON");
		for (const row of database.prepare("SELECT session_id,cwd,updated_at FROM session_docs").iterate()) {
			if (!sameProject(row.cwd, project)) continue;
			const indexedTimestamp = typeof row.updated_at === "number" && row.updated_at < 100000000000 ? row.updated_at * 1000 : row.updated_at;
			const indexed = makeRecord("grok", row.session_id, indexedTimestamp, databasePath, ["search index cwd exact project match"]);
			const native = nativeById.get(row.session_id);
			if (!native) {
				result.warnings.push(warning("grok", "grok_search_record_unavailable", "Grok search index matches the project, but no native session is available.", { session_id: row.session_id, conversation_timestamp: indexed?.conversation_timestamp, source_path: databasePath }));
				if (indexed) result._blocking.push(indexed);
			} else if (indexed && native._rank_ns > indexed._rank_ns) {
				result.warnings.push(warning("grok", "grok_stale_search_index", "Grok native summary is newer than its search-index row.", { session_id: row.session_id, source_path: databasePath }));
			}
		}
	} catch (error) {
		result.warnings.push(warning("grok", "grok_search_index_unreadable", `Cannot read Grok search index; native sessions were still inspected: ${errorText(error)}`, { source_path: databasePath }));
	} finally {
		try { database?.close(); } catch {}
	}
}

function discoverGemini(project, home) {
	const state = statState(home);
	if (state.status === "missing") return provider("missing");
	if (state.status === "unreadable" || !state.stat.isDirectory()) return unreadableProvider("gemini", home, state.error || new Error("not a directory"));
	const result = provider();
	const projectHash = crypto.createHash("sha256").update(project).digest("hex");
	const identifiers = new Set([projectHash]);
	const registryPath = path.join(home, "projects.json");
	const registryState = statState(registryPath);
	if (registryState.status === "present") {
		try {
			const registry = boundedJson(registryPath);
			if (!registry || typeof registry.projects !== "object" || Array.isArray(registry.projects)) throw new Error("invalid projects.json schema");
			for (const [registeredPath, identifier] of Object.entries(registry.projects)) {
				if (!sameProject(registeredPath, project)) continue;
				if (typeof identifier !== "string" || !/^[a-z0-9-]+$/.test(identifier)) throw new Error("invalid project identifier");
				const markerPath = path.join(home, "tmp", identifier, ".project_root");
				const markerState = statState(markerPath);
				if (markerState.status === "present" && fs.readFileSync(markerPath, "utf8").trim() !== project) throw new Error(`project marker contradicts registry: ${markerPath}`);
				identifiers.add(identifier);
			}
		} catch (error) {
			return unreadableProvider("gemini", registryPath, error);
		}
	} else if (registryState.status === "unreadable") {
		return unreadableProvider("gemini", registryPath, registryState.error);
	}
	let fileCount = 0;
	try {
		for (const identifier of identifiers) {
			const chats = path.join(home, "tmp", identifier, "chats");
			if (statState(chats).status !== "present") continue;
			for (const file of walkSessionFiles(chats, 1)) {
				fileCount += 1;
				if (fileCount > MAX_FILES) throw new Error(`file limit exceeded at ${chats}`);
				inspectGeminiSession(file, chats, projectHash, result);
			}
		}
	} catch (error) {
		return unreadableProvider("gemini", home, error);
	}
	return result;
}

function walkSessionFiles(directory, childDepth) {
	const files = [];
	for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
		const file = path.join(directory, entry.name);
		if (entry.isFile() && (entry.name.endsWith(".jsonl") || entry.name.endsWith(".json"))) files.push(file);
		else if (entry.isDirectory() && childDepth > 0) {
			for (const child of fs.readdirSync(file, { withFileTypes: true })) {
				if (child.isFile() && (child.name.endsWith(".jsonl") || child.name.endsWith(".json"))) files.push(path.join(file, child.name));
			}
		}
	}
	return files;
}

function inspectGeminiSession(file, chatsRoot, projectHash, result) {
	let records;
	try {
		if (file.endsWith(".json")) {
			const document = boundedJson(file);
			records = [document, ...(Array.isArray(document.messages) ? document.messages : [])];
		} else records = boundedJsonl(file).records;
	} catch (error) {
		result.warnings.push(warning("gemini", "gemini_session_unreadable", `Cannot read Gemini session: ${errorText(error)}`, { source_path: file }));
		result._unknown_blocking = true;
		return;
	}
	let metadata = records.find((record) => typeof record?.sessionId === "string" && typeof record?.projectHash === "string");
	if (!metadata) {
		result.warnings.push(warning("gemini", "gemini_session_metadata_missing", "Gemini session under an exact project identifier lacks native identity metadata.", { source_path: file }));
		result._unknown_blocking = true;
		return;
	}
	for (const record of records) {
		if (record?.$set && typeof record.$set === "object") metadata = { ...metadata, ...record.$set };
	}
	if (metadata.projectHash !== projectHash) {
		result.warnings.push(warning("gemini", "gemini_project_hash_mismatch", "Gemini session is stored under this project identifier, but its native project hash differs.", { session_id: metadata.sessionId, source_path: file }));
		return;
	}
	const record = makeRecord("gemini", metadata.sessionId, metadata.lastUpdated || metadata.startTime, file, ["SHA-256 native project hash exact match", "native session metadata timestamp"]);
	if (!record) return;
	const relative = path.relative(chatsRoot, file);
	const child = metadata.kind === "subagent" || relative.split(path.sep).length > 1;
	if (child) result.excluded_children.push({ ...record, reason: "subagent session is not an automatic root resume candidate" });
	else result.candidates.push(record);
}

function deduplicate(records) {
	const chosen = new Map();
	for (const record of records) {
		const key = `${record.backend}\0${record.session_id}`;
		const current = chosen.get(key);
		if (!current || record._rank_ns > current._rank_ns) chosen.set(key, record);
	}
	return [...chosen.values()];
}

function main() {
	if (configurationError) throw configurationError;
	const arguments_ = process.argv.slice(2);
	const text = arguments_[0] === "--text";
	if (text) arguments_.shift();
	if (arguments_.length !== 1) throw new Error("usage: agent_context_discovery.mjs [--text] PROJECT");
	const projectState = statState(arguments_[0]);
	if (projectState.status !== "present" || !projectState.stat.isDirectory()) throw new Error(`project directory is unavailable: ${arguments_[0]}`);
	const project = fs.realpathSync(arguments_[0]);
	const userHome = process.env.HOME || "";
	const providers = {
		codex: discoverCodex(project, storagePath("ERECT_CONTEXT_CODEX_HOME", path.join(userHome, ".codex"))),
		claude: discoverClaude(project, storagePath("ERECT_CONTEXT_CLAUDE_HOME", path.join(userHome, ".claude"))),
		grok: discoverGrok(project, storagePath("ERECT_CONTEXT_GROK_HOME", path.join(userHome, ".grok"))),
		gemini: discoverGemini(project, storagePath("ERECT_CONTEXT_GEMINI_HOME", path.join(userHome, ".gemini"))),
	};
	const candidates = deduplicate(Object.values(providers).flatMap((item) => item.candidates));
	const excludedChildren = deduplicate(Object.values(providers).flatMap((item) => item.excluded_children));
	const warnings = Object.values(providers).flatMap((item) => item.warnings);
	const unreadable = Object.values(providers).some((item) => item.status === "unreadable");
	const unknownBlocking = Object.values(providers).some((item) => item._unknown_blocking);
	let latestCandidates = [];
	if (candidates.length > 0) {
		const newest = candidates.reduce((value, candidate) => candidate._rank_ns > value ? candidate._rank_ns : value, candidates[0]._rank_ns);
		latestCandidates = candidates.filter((candidate) => candidate._rank_ns === newest);
	}
	const newestAvailable = latestCandidates[0]?._rank_ns;
	const blockingRecord = Object.values(providers).flatMap((item) => item._blocking).some((record) => newestAvailable === undefined || record._rank_ns >= newestAvailable);
	let status;
	let exitCode;
	let latest = null;
	if (unreadable || unknownBlocking || blockingRecord) {
		status = "incomplete";
		exitCode = 74;
	} else if (candidates.length === 0) {
		status = "none";
		exitCode = 1;
	} else if (latestCandidates.length > 1) {
		status = "ambiguous";
		exitCode = 69;
	} else {
		status = "found";
		exitCode = 0;
		latest = latestCandidates[0];
	}
	const cleanProviders = Object.fromEntries(Object.entries(providers).map(([name, item]) => [name, {
		status: item.status,
		candidates: item.candidates.map(outputRecord),
		warnings: item.warnings,
	}]));
	const output = {
		schema: SCHEMA,
		status,
		project,
		latest: outputRecord(latest),
		latest_candidates: latestCandidates.map(outputRecord),
		providers: cleanProviders,
		excluded_children: excludedChildren.map(outputRecord),
		warnings,
	};
	if (text) {
		if (status === "found") process.stdout.write(`${latest.backend}\n`);
		else process.stderr.write(`erect-agent-stack: latest-context ${status}; rerun with --json for evidence\n`);
	} else process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
	process.exitCode = exitCode;
}

try {
	main();
} catch (error) {
	const message = errorText(error);
	if (process.argv.includes("--text")) process.stderr.write(`erect-agent-stack: ${message}\n`);
	else process.stdout.write(`${JSON.stringify({ schema: SCHEMA, status: "incomplete", latest: null, error: message }, null, 2)}\n`);
	process.exitCode = 74;
}
