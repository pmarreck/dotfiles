#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";

const [fixtureRoot, project, otherProject] = process.argv.slice(2);
if (!fixtureRoot || !project || !otherProject) {
	throw new Error("usage: write_context_fixtures.mjs FIXTURE_ROOT PROJECT OTHER_PROJECT");
}

const isoMs = (value) => Date.parse(value);
const mkdir = (value) => fs.mkdirSync(value, { recursive: true });
const writeJson = (file, value) => {
	mkdir(path.dirname(file));
	fs.writeFileSync(file, `${JSON.stringify(value)}\n`);
};
const writeJsonl = (file, values) => {
	mkdir(path.dirname(file));
	fs.writeFileSync(file, `${values.map((value) => JSON.stringify(value)).join("\n")}\n`);
};
const futureMtime = new Date("2035-01-01T00:00:00.000Z");

const codexHome = path.join(fixtureRoot, "codex");
mkdir(codexHome);
const codexDb = new DatabaseSync(path.join(codexHome, "state_5.sqlite"));
codexDb.exec(`
	CREATE TABLE threads (
		id TEXT PRIMARY KEY,
		rollout_path TEXT,
		updated_at INTEGER,
		updated_at_ms INTEGER,
		source TEXT,
		cwd TEXT,
		thread_source TEXT,
		agent_path TEXT
	)
`);
const insertThread = codexDb.prepare(`
	INSERT INTO threads
		(id, rollout_path, updated_at, updated_at_ms, source, cwd, thread_source, agent_path)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?)
`);
const addCodex = (id, cwd, timestamp, source, threadSource = "user", available = true) => {
	const rollout = path.join(codexHome, "sessions", `${id}.jsonl`);
	if (available) writeJsonl(rollout, [{ type: "session_meta", id }]);
	const milliseconds = isoMs(timestamp);
	insertThread.run(id, rollout, Math.floor(milliseconds / 1000), milliseconds, source, cwd, threadSource, threadSource === "subagent" ? "child" : null);
};
addCodex("codex-cli", project, "2026-09-10T10:00:00.000Z", "cli");
addCodex("codex-vscode", project, "2026-09-10T11:00:00.000Z", "vscode");
addCodex("codex-exec", project, "2026-09-10T12:00:00.000Z", "exec");
addCodex("codex-child", project, "2026-09-20T00:00:00.000Z", JSON.stringify({ subagent: { type: "other" } }), "subagent");
addCodex("codex-unavailable", project, "2026-09-09T00:00:00.000Z", "cli", "user", false);
addCodex("codex-other-project", otherProject, "2026-09-30T00:00:00.000Z", "cli");
codexDb.close();

const claudeHome = path.join(fixtureRoot, "claude");
const claudeDir = path.join(claudeHome, "projects", "legacy-directory-name");
const claudeRoot = path.join(claudeDir, "claude-root.jsonl");
writeJsonl(claudeRoot, [
	{ type: "user", cwd: project, isSidechain: false, sessionId: "claude-root", timestamp: "2026-09-11T09:00:00.000Z", message: { content: "not inspected" } },
	{ type: "assistant", cwd: project, isSidechain: false, sessionId: "claude-root", timestamp: "2026-09-11T10:00:00.000Z", message: { content: "not inspected" } },
]);
writeJsonl(path.join(claudeDir, "claude-root", "subagents", "claude-child.jsonl"), [
	{ type: "assistant", cwd: project, isSidechain: true, sessionId: "claude-parent", agentId: "claude-child-1", timestamp: "2026-09-22T00:00:00.000Z" },
]);
writeJsonl(path.join(claudeDir, "claude-root", "subagents", "claude-child-2.jsonl"), [
	{ type: "assistant", cwd: project, isSidechain: true, sessionId: "claude-parent", agentId: "claude-child-2", timestamp: "2026-09-22T01:00:00.000Z" },
]);
writeJsonl(path.join(claudeHome, "projects", "collision-name", "claude-other.jsonl"), [
	{ type: "assistant", cwd: otherProject, isSidechain: false, sessionId: "claude-other-project", timestamp: "2026-09-30T00:00:00.000Z" },
]);
writeJson(path.join(claudeDir, "sessions-index.json"), {
	originalPath: "/Users/pmarreck/a project",
	entries: [
		{ sessionId: "claude-moved", projectPath: "/Users/pmarreck/a project", fullPath: "/Users/pmarreck/.claude/projects/a-project/claude-moved.jsonl", modified: "2026-09-23T00:00:00.000Z" },
		{ sessionId: "claude-index-only", projectPath: project, fullPath: path.join(claudeDir, "missing-claude-index-only.jsonl"), modified: "2026-09-08T00:00:00.000Z" },
	],
});

const grokHome = path.join(fixtureRoot, "grok");
const grokSessions = path.join(grokHome, "sessions");
mkdir(grokSessions);
const grokDb = new DatabaseSync(path.join(grokSessions, "session_search.sqlite"));
grokDb.exec("CREATE TABLE session_docs (session_id TEXT, cwd TEXT, updated_at INTEGER, title TEXT)");
const insertGrokIndex = grokDb.prepare("INSERT INTO session_docs VALUES (?, ?, ?, ?)");
insertGrokIndex.run("grok-native", project, Math.floor(isoMs("2026-08-19T00:00:00.000Z") / 1000), "stale index");
insertGrokIndex.run("grok-index-only", project, Math.floor(isoMs("2026-09-11T00:00:00.000Z") / 1000), "missing native record");
grokDb.close();
const encodedProject = encodeURIComponent(project);
const grokSummary = path.join(grokSessions, encodedProject, "grok-native", "summary.json");
writeJson(grokSummary, {
	updated_at: "2026-09-12T12:00:00.000Z",
	last_active_at: "2026-09-12T11:59:59.000Z",
	git_root_dir: `${project}/`,
	info: { id: "grok-native", cwd: project },
});
writeJsonl(path.join(path.dirname(grokSummary), "chat_history.jsonl"), [{ role: "user", content: "not inspected" }]);
const otherGrokSummary = path.join(grokSessions, encodeURIComponent(otherProject), "grok-other-project", "summary.json");
writeJson(otherGrokSummary, {
	updated_at: "2026-09-30T00:00:00.000Z",
	info: { id: "grok-other-project", cwd: otherProject },
});

const geminiHome = path.join(fixtureRoot, "gemini");
const projectHash = crypto.createHash("sha256").update(project).digest("hex");
const otherHash = crypto.createHash("sha256").update(otherProject).digest("hex");
writeJson(path.join(geminiHome, "projects.json"), { projects: { [project]: "a-project-slug" } });
const geminiSlug = path.join(geminiHome, "tmp", "a-project-slug");
mkdir(geminiSlug);
fs.writeFileSync(path.join(geminiSlug, ".project_root"), `${project}\n`);
writeJsonl(path.join(geminiSlug, "chats", "session-current-gemini.jsonl"), [
	{ sessionId: "gemini-root", projectHash, startTime: "2026-09-13T09:00:00.000Z", lastUpdated: "2026-09-13T10:00:00.000Z", kind: "main" },
	{ id: "user-1", type: "user", timestamp: "2026-09-13T09:00:01.000Z", content: "not inspected" },
]);
writeJsonl(path.join(geminiSlug, "chats", "parent", "gemini-child.jsonl"), [
	{ sessionId: "gemini-child", projectHash, startTime: "2026-09-24T00:00:00.000Z", lastUpdated: "2026-09-24T00:00:00.000Z", kind: "subagent" },
]);
writeJsonl(path.join(geminiSlug, "chats", "session-wrong-hash.jsonl"), [
	{ sessionId: "gemini-wrong-hash", projectHash: otherHash, startTime: "2026-09-29T00:00:00.000Z", lastUpdated: "2026-09-29T00:00:00.000Z", kind: "main" },
]);
writeJsonl(path.join(geminiHome, "tmp", projectHash, "chats", "session-legacy-gemini.jsonl"), [
	{ sessionId: "gemini-legacy", projectHash, startTime: "2026-09-12T10:00:00.000Z", lastUpdated: "2026-09-12T10:00:00.000Z", kind: "main" },
	{ id: "user-legacy", type: "user", timestamp: "2026-09-12T10:00:00.000Z", content: "not inspected" },
]);

for (const file of [claudeRoot, grokSummary, path.join(geminiSlug, "chats", "session-current-gemini.jsonl")]) {
	fs.utimesSync(file, futureMtime, futureMtime);
}
