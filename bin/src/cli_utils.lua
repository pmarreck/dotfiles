local ffi = require("ffi")
local test_factory = require("test_factory").test_factory
ffi.cdef([[  typedef long time_t;
  typedef struct timeval {
    time_t tv_sec;
    time_t tv_usec;
  } timeval;
  int gettimeofday(struct timeval* tv, void* tz);
]])
local seed_rng
seed_rng = function()
  local tv = ffi.new("timeval")
  ffi.C.gettimeofday(tv, nil)
  local sec = tonumber(tv.tv_sec)
  local usec = tonumber(tv.tv_usec)
  math.randomseed(sec * 1e6 + usec)
  return math.random()
end
local default_validator
default_validator = function()
  return true
end
local parse_args
parse_args = function(config, argv)
  if argv == nil then
    argv = arg
  end
  local options = { }
  local positionals = { }
  local helptext = { }
  local spec_by_flag = { }
  for _index_0 = 1, #config do
    local entry = config[_index_0]
    local _list_0 = entry.flags
    for _index_1 = 1, #_list_0 do
      local flag = _list_0[_index_1]
      spec_by_flag[flag] = entry
    end
    if entry.description then
      helptext[#helptext + 1] = table.concat(entry.flags, ", ") .. "\t" .. entry.description
    end
  end
  local i = 1
  while i <= #argv do
    local token = argv[i]
    if token == "-h" or token == "--help" then
      print("Usage:")
      for _index_0 = 1, #helptext do
        local line = helptext[_index_0]
        print("  ", line)
      end
      os.exit(0)
    end
    local entry = spec_by_flag[token]
    if entry then
      if entry.has_arg then
        i = i + 1
        local argval = argv[i]
        if not (argval) then
          io.stderr:write("Missing argument for " .. tostring(token) .. "\n")
          os.exit(1)
        end
        local validator = entry.validator or default_validator
        if not (validator(argval)) then
          io.stderr:write("Invalid argument for " .. tostring(token) .. ": " .. tostring(argval) .. "\n")
          os.exit(2)
        end
        options[entry.name] = argval
      else
        options[entry.name] = true
      end
    else
      positionals[#positionals + 1] = token
    end
    i = i + 1
  end
  return {
    options,
    positionals
  }
end
return {
  seed_rng = seed_rng,
  assert_factory = test_factory,
  parse_args = parse_args
}
