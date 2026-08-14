--- Stable fleet-status facade and hexagonal composition root.
--- Domain modules receive every adapter explicitly; callers retain one API.
local M = {
	VERSION = "0.3.0",
	NETWORK_CACHE_VERSION = 4,
}

local runtime = require("fleet_status.runtime")
local state_factory = require("fleet_status.state")
local attention = require("fleet_status.attention")
local scheduler = require("fleet_status.scheduler")
local renderers = require("fleet_status.renderers")
local collector_factory = require("fleet_status.local_collector")
local lock_parsers = require("fleet_status.lock_parsers")
local provider_factory = require("fleet_status.providers")
local network_factory = require("fleet_status.network")
local repository_profile = require("fleet_status.repository_profile")

local state = state_factory.new(runtime)
local collector = collector_factory.new(runtime, repository_profile)
local providers = provider_factory.new(runtime, state, M.NETWORK_CACHE_VERSION)
local network = network_factory.new(
	runtime, state, lock_parsers, providers, scheduler, repository_profile
)

M.render_one_line = renderers.render_one_line
M.render_markdown = function(snapshot, previous, options)
	options = options or {}
	options.classify_attention = attention.classify
	return renderers.render_markdown(snapshot, previous, options)
end
M.collect_roots = collector.collect_roots
M.classify_attention = attention.classify

M.encode_json = state.encode_json
M.decode_json = state.decode_json
M.load_json_file = state.load_json_file
M.write_atomic = state.write_atomic
M.publication_due = state.publication_due
M.file_times = state.file_times
M.persist_snapshot = state.persist_snapshot
M.acquire_state_lock = state.acquire_state_lock
M.release_state_lock = state.release_state_lock

M.configure_provider_cache = network.configure_provider_cache
M.collect_network_repo = network.collect_network_repo
M.probe_network_repo = network.probe_network_repo
M.enrich_network = network.enrich_network

return M
