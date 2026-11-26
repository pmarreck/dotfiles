local ffi = require("ffi")

local snapshot = {}

local function sanitize_name(name)
	local sanitized = (name or "unknown"):gsub("[\t\r\n]", " ")
	return sanitized
end

function snapshot.collect(api, uid)
	local rows = {}
	for _, pid in ipairs(api.list_pids(uid)) do
		local usage = api.rusage(pid)
		if usage then
			rows[#rows + 1] = table.concat({
				tostring(pid),
				tostring(usage.start),
				tostring(usage.read),
				tostring(usage.write),
				sanitize_name(api.name(pid)),
			}, "\t")
		end
	end
	return table.concat(rows, "\n") .. (#rows > 0 and "\n" or "")
end

function snapshot.libproc_api()
	if ffi.os ~= "OSX" then
		error("libproc process I/O sampling is available only on macOS")
	end

	ffi.cdef([[
		typedef unsigned char uint8_t;
		typedef unsigned int uint32_t;
		typedef unsigned long long uint64_t;

		struct rusage_info_v4 {
			uint8_t ri_uuid[16];
			uint64_t ri_user_time;
			uint64_t ri_system_time;
			uint64_t ri_pkg_idle_wkups;
			uint64_t ri_interrupt_wkups;
			uint64_t ri_pageins;
			uint64_t ri_wired_size;
			uint64_t ri_resident_size;
			uint64_t ri_phys_footprint;
			uint64_t ri_proc_start_abstime;
			uint64_t ri_proc_exit_abstime;
			uint64_t ri_child_user_time;
			uint64_t ri_child_system_time;
			uint64_t ri_child_pkg_idle_wkups;
			uint64_t ri_child_interrupt_wkups;
			uint64_t ri_child_pageins;
			uint64_t ri_child_elapsed_abstime;
			uint64_t ri_diskio_bytesread;
			uint64_t ri_diskio_byteswritten;
			uint64_t ri_cpu_time_qos_default;
			uint64_t ri_cpu_time_qos_maintenance;
			uint64_t ri_cpu_time_qos_background;
			uint64_t ri_cpu_time_qos_utility;
			uint64_t ri_cpu_time_qos_legacy;
			uint64_t ri_cpu_time_qos_user_initiated;
			uint64_t ri_cpu_time_qos_user_interactive;
			uint64_t ri_billed_system_time;
			uint64_t ri_serviced_system_time;
			uint64_t ri_logical_writes;
			uint64_t ri_lifetime_max_phys_footprint;
			uint64_t ri_instructions;
			uint64_t ri_cycles;
			uint64_t ri_billed_energy;
			uint64_t ri_serviced_energy;
			uint64_t ri_interval_max_phys_footprint;
			uint64_t ri_runnable_time;
		};

		int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize);
		int proc_name(int pid, void *buffer, uint32_t buffersize);
		int proc_pid_rusage(int pid, int flavor, void *buffer);
	]])

	local libproc = ffi.load("proc")
	local PROC_UID_ONLY = 4
	local RUSAGE_INFO_V4 = 4
	local api = {}

	function api.list_pids(uid)
		local required_bytes = libproc.proc_listpids(PROC_UID_ONLY, uid, nil, 0)
		if required_bytes <= 0 then
			return {}
		end
		local capacity = math.floor(required_bytes / ffi.sizeof("int")) + 32
		local pids = ffi.new("int[?]", capacity)
		local used_bytes = libproc.proc_listpids(
			PROC_UID_ONLY,
			uid,
			pids,
			capacity * ffi.sizeof("int")
		)
		local result = {}
		for index = 0, math.floor(used_bytes / ffi.sizeof("int")) - 1 do
			if pids[index] > 0 then
				result[#result + 1] = tonumber(pids[index])
			end
		end
		return result
	end

	function api.rusage(pid)
		local info = ffi.new("struct rusage_info_v4")
		if libproc.proc_pid_rusage(pid, RUSAGE_INFO_V4, info) ~= 0 then
			return nil
		end
		return {
			start = tonumber(info.ri_proc_start_abstime),
			read = tonumber(info.ri_diskio_bytesread),
			write = tonumber(info.ri_diskio_byteswritten),
		}
	end

	function api.name(pid)
		local buffer = ffi.new("char[1024]")
		local length = libproc.proc_name(pid, buffer, 1024)
		if length <= 0 then
			return "pid-" .. tostring(pid)
		end
		return ffi.string(buffer, length)
	end

	return api
end

return snapshot
