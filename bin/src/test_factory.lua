local color
color = function(code, str)
  return "\027[" .. tostring(code) .. "m" .. tostring(str) .. "\027[0m"
end
local red
red = function(s)
  return color("31", s)
end
local green
green = function(s)
  return color("32", s)
end
local yellow
yellow = function(s)
  return color("33", s)
end
local test_factory
test_factory = function(output_style, writer, verbose)
  if output_style == nil then
    output_style = "dot"
  end
  if writer == nil then
    writer = io.write
  end
  if verbose == nil then
    verbose = false
  end
  local fails = 0
  local passes = 0
  local count = 0
  local output_buffer = ""
  local is_finished = false
  local write
  write = function(s)
    writer(s)
    output_buffer = output_buffer .. s
    return s
  end
  local writeln
  writeln = function(s)
    return write(s .. "\n")
  end
  local emit
  emit = function(success, label, trace)
    if trace == nil then
      trace = nil
    end
    count = count + 1
    if success then
      passes = passes + 1
    else
      fails = fails + 1
    end
    local _exp_0 = output_style
    if "dot" == _exp_0 then
      write((function()
        if success then
          return "."
        else
          return red("F")
        end
      end)())
      if not success and trace then
        writeln("\n" .. trace)
      end
      if verbose and not success then
        return writeln("\n" .. red("FAIL: ") .. label)
      end
    elseif "tap" == _exp_0 then
      if success then
        return writeln(green("ok " .. tostring(count) .. " - " .. tostring(label)))
      else
        writeln(red("not ok " .. tostring(count) .. " - " .. tostring(label)))
        writeln("#   Failed test '" .. tostring(label) .. "'")
        if trace then
          for line in trace:gmatch("[^\n]+") do
            writeln("#   " .. line)
          end
        end
      end
    end
  end
  local assert
  assert = function(expr, msg)
    if msg == nil then
      msg = "Assertion failed"
    end
    if expr then
      emit(true, msg)
      return true
    else
      local trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    end
  end
  local refute
  refute = function(expr, msg)
    if msg == nil then
      msg = "Refutation failed"
    end
    if not expr then
      emit(true, msg)
      return true
    else
      local trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    end
  end
  local assert_equal
  assert_equal = function(got, expected, msg)
    if msg == nil then
      msg = nil
    end
    msg = msg or "Expected " .. tostring(expected and expected.inspect and expected.inspect() or tostring(expected)) .. ", got " .. tostring(got and got.inspect and got.inspect() or tostring(got))
    if got == expected then
      emit(true, msg)
      return true
    else
      local trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    end
  end
  local refute_equal
  refute_equal = function(got, not_expected, msg)
    if msg == nil then
      msg = nil
    end
    msg = msg or "Expected values to not be equal: " .. tostring(got and got.inspect and got.inspect() or tostring(got)) .. " != " .. tostring(not_expected and not_expected.inspect and not_expected.inspect() or tostring(not_expected))
    if got ~= not_expected then
      emit(true, msg)
      return true
    else
      local trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    end
  end
  local assert_not_equal = refute_equal
  local deep_equal
  deep_equal = function(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
      return a == b
    end
    if #a ~= #b then
      return false
    end
    for k, v in pairs(a) do
      if not (deep_equal(v, b[k])) then
        return false
      end
    end
    for k, v in pairs(b) do
      if not (deep_equal(v, a[k])) then
        return false
      end
    end
    return true
  end
  local assert_deep_equal
  assert_deep_equal = function(got, expected, msg)
    if msg == nil then
      msg = nil
    end
    msg = msg or "Expected tables to be deeply equal"
    if deep_equal(got, expected) then
      emit(true, msg)
      return true
    else
      local trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    end
  end
  local refute_deep_equal
  refute_deep_equal = function(got, not_expected, msg)
    if msg == nil then
      msg = nil
    end
    msg = msg or "Expected tables to not be deeply equal"
    if not deep_equal(got, not_expected) then
      emit(true, msg)
      return true
    else
      local trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    end
  end
  local assert_contains
  assert_contains = function(haystack, needle, msg)
    if msg == nil then
      msg = nil
    end
    msg = msg or "Expected '" .. tostring(haystack) .. "' to contain '" .. tostring(needle) .. "'"
    if string.find(haystack, needle, 1, true) then
      emit(true, msg)
      return true
    else
      local trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    end
  end
  local refute_contains
  refute_contains = function(haystack, needle, msg)
    if msg == nil then
      msg = nil
    end
    msg = msg or "Expected '" .. tostring(haystack) .. "' to not contain '" .. tostring(needle) .. "'"
    if not string.find(haystack, needle, 1, true) then
      emit(true, msg)
      return true
    else
      local trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    end
  end
  local contains_pattern
  contains_pattern = function(str, pattern)
    return str:match(pattern) ~= nil
  end
  local get_trace
  get_trace = function(fn)
    local trace = ""
    local handler
    handler = function(e)
      trace = debug.traceback(e, 2)
      return trace
    end
    local ok, result = xpcall(fn, handler)
    return {
      ok,
      result,
      trace
    }
  end
  local assert_raise
  assert_raise = function(fn, msg)
    if msg == nil then
      msg = "Expected an error to be raised"
    end
    local ok, result, trace
    do
      local _obj_0 = get_trace(fn)
      ok, result, trace = _obj_0[1], _obj_0[2], _obj_0[3]
    end
    if ok then
      trace = debug.traceback("", 2)
      emit(false, msg, trace)
      return false
    else
      emit(true, msg, trace)
      return true
    end
  end
  local refute_raise
  refute_raise = function(fn, msg)
    if msg == nil then
      msg = "Expected no error to be raised"
    end
    local ok, result, trace
    do
      local _obj_0 = get_trace(fn)
      ok, result, trace = _obj_0[1], _obj_0[2], _obj_0[3]
    end
    if not ok then
      trace = debug.traceback("", 2)
      emit(false, tostring(msg) .. ": " .. tostring(result), trace)
      return false
    else
      emit(true, msg)
      return true
    end
  end
  local assert_no_raise = refute_raise
  local report_text
  report_text = function()
    return output_buffer
  end
  local get_stats
  get_stats = function()
    local total = passes + fails
    return "Tests run: " .. tostring(total) .. ", Passed: " .. tostring(passes) .. ", Failed: " .. tostring(fails)
  end
  local finish_test
  finish_test = function()
    local total = passes + fails
    if output_style == "tap" then
      writeln("\n1.." .. tostring(total))
    end
    writeln("\n" .. tostring(get_stats()))
    is_finished = true
    return output_buffer
  end
  local report
  report = function()
    return finish_test()
  end
  local run_tests
  run_tests = function(tests)
    local results = { }
    for name, fn in pairs(tests) do
      local result = fn()
      results[name] = result
    end
    return results
  end
  return {
    assert = assert,
    refute = refute,
    assert_equal = assert_equal,
    refute_equal = refute_equal,
    assert_not_equal = assert_not_equal,
    deep_equal = deep_equal,
    assert_deep_equal = assert_deep_equal,
    refute_deep_equal = refute_deep_equal,
    assert_raise = assert_raise,
    refute_raise = refute_raise,
    assert_no_raise = assert_no_raise,
    assert_contains = assert_contains,
    refute_contains = refute_contains,
    contains_pattern = contains_pattern,
    report = report,
    report_text = report_text,
    get_stats = get_stats,
    finish_test = finish_test,
    get_output = report_text,
    run_tests = run_tests,
    passes = function()
      return passes
    end,
    fails = function()
      return fails
    end,
    count = function()
      return count
    end,
    is_finished = function()
      return is_finished
    end
  }
end
local return_value = {
  test_factory = test_factory
}
if arg and arg[0] and arg[1] == "--test" then
  local is_verbose = false
  for i = 1, #arg do
    if arg[i] == "--verbose" or arg[i] == "-v" then
      is_verbose = true
      break
    end
  end
  local tf = test_factory("dot", io.write, is_verbose)
  tf.assert(true, "Basic assertion should pass")
  tf.assert(not false, "Negated false should pass")
  tf.refute(false, "Basic refutation should pass")
  tf.refute(not true, "Negated true refutation should pass")
  tf.assert_equal(42, 42, "Numbers should be equal")
  tf.assert_equal("test", "test", "Strings should be equal")
  tf.refute_equal(42, 43, "Different numbers should not be equal")
  tf.refute_equal("test", "test2", "Different strings should not be equal")
  local a = {
    1,
    2,
    3
  }
  local b = {
    1,
    2,
    3
  }
  local c = {
    1,
    2,
    4
  }
  local d = {
    a = 1,
    b = 2,
    c = {
      x = 1,
      y = 2
    }
  }
  local e = {
    a = 1,
    b = 2,
    c = {
      x = 1,
      y = 2
    }
  }
  local f = {
    a = 1,
    b = 2,
    c = {
      x = 1,
      y = 3
    }
  }
  tf.assert_deep_equal(a, b, "Arrays with same values should be deeply equal")
  tf.refute_deep_equal(a, c, "Arrays with different values should not be deeply equal")
  tf.assert_deep_equal(d, e, "Nested tables with same values should be deeply equal")
  tf.refute_deep_equal(d, f, "Nested tables with different values should not be deeply equal")
  tf.assert_not_equal(42, 43, "Different numbers should not be equal")
  tf.assert_not_equal("test", "test2", "Different strings should not be equal")
  tf.assert_contains("hello world", "world", "String should contain substring")
  tf.assert_contains("testing 123", "123", "String should contain numbers")
  tf.refute_contains("hello world", "goodbye", "String should not contain substring")
  tf.refute_contains("testing 123", "456", "String should not contain certain numbers")
  tf.assert_raise(function()
    return error("test error"), "Should catch errors"
  end)
  tf.refute_raise(function()
    return 42, "Should not raise on valid function"
  end)
  local _ = tf.assert_no_raise(function()
    return 42
  end), "Should not raise on valid function"
  local fail_tf = test_factory("dot", function(_s)
    return nil
  end)
  local result = fail_tf.assert(true, "This should pass")
  tf.assert_equal(result, true, "Assert should return true on success")
  result = fail_tf.assert(false, "This should fail but not raise")
  tf.assert_equal(result, false, "Assert should return false on failure")
  tf.assert_equal(fail_tf.passes(), 1, "Pass count should be 1")
  tf.assert_equal(fail_tf.fails(), 1, "Fail count should be 1")
  local inspect_obj = {
    inspect = function()
      return "inspected value"
    end
  }
  local expected_msg = "Expected inspected value, got something else"
  local actual_msg = "Expected " .. tostring(inspect_obj.inspect()) .. ", got something else"
  tf.assert_equal(actual_msg, expected_msg, "Should use inspect when available")
  tf.assert(tf.passes() > 0, "Should have at least one passing test")
  local tap_output = ""
  local tap_writer
  tap_writer = function(s)
    tap_output = tap_output .. s
  end
  local tap_tf = test_factory("tap", tap_writer)
  tap_tf.assert(true, "TAP passing test")
  pcall(function()
    tap_tf.assert(false, "TAP failing test")
    return tap_tf.assert_raise((function()
      return 42
    end), "Should raise but doesn't")
  end)
  tap_tf.finish_test()
  if is_verbose then
    print("\nTAP test report: [" .. tap_output .. "]")
  end
  tf.assert_contains(tap_output, "ok 1", "TAP output should contain passing test marker")
  tf.assert_contains(tap_output, "not ok 2", "TAP output should contain failing test marker")
  tf.assert_contains(tap_output, "1..3", "TAP output should contain test count summary")
  tf.assert_contains(tap_output, "Tests run: 3", "TAP output should contain test statistics")
  local dot_output = ""
  local dot_writer
  dot_writer = function(s)
    dot_output = dot_output .. s
  end
  local dot_tf = test_factory("dot", dot_writer)
  dot_tf.assert(true, "Dot passing test")
  pcall(function()
    return dot_tf.assert(false, "Dot failing test")
  end)
  dot_tf.finish_test()
  if is_verbose then
    print("\nDot test report: [" .. dot_output .. "]")
  end
  tf.assert_contains(dot_output, ".", "Dot output should contain dot for passing test")
  tf.assert_contains(dot_output, "F", "Dot output should contain F for failing test")
  tf.assert_contains(dot_output, "Tests run:", "Dot output should contain test statistics")
  tf.report()
  os.exit(tf.fails())
end
return return_value
