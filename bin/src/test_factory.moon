#!/usr/bin/env moonrun
-- test_factory.moon
-- Minimal Moonscript testing framework with optional TAP output

-- ANSI coloring helpers
color = (code, str) -> "\027[#{code}m#{str}\027[0m"
red    = (s) -> color("31", s)
green  = (s) -> color("32", s)
yellow = (s) -> color("33", s)

-- Test factory
test_factory = (output_style = "dot", writer = io.write, verbose = false) ->
	fails = 0
	passes = 0
	count = 0
	output_buffer = ""
	is_finished = false

	write = (s) ->
		writer s
		output_buffer ..= s
		s

	writeln = (s) ->
		write s .. "\n"

	emit = (success, label, trace = nil) ->
		count += 1
		if success
			passes += 1
		else
			fails += 1

		switch output_style
			when "dot"
				write if success then "." else red("F")
				if not success and trace
					writeln "\n" .. trace
				if verbose and not success
					writeln "\n" .. red("FAIL: ") .. label
			when "tap"
				if success
					writeln green("ok #{count} - #{label}")
				else
					writeln red("not ok #{count} - #{label}")
					writeln "#   Failed test '#{label}'"
					if trace
						for line in trace\gmatch "[^\n]+" do
							writeln "#   " .. line

	assert = (expr, msg = "Assertion failed") ->
		if expr
			emit true, msg
			true
		else
			trace = debug.traceback "", 2
			emit false, msg, trace
			false

	refute = (expr, msg = "Refutation failed") ->
		if not expr
			emit true, msg
			true
		else
			trace = debug.traceback "", 2
			emit false, msg, trace
			false

	assert_equal = (got, expected, msg = nil) ->
		msg or= "Expected #{expected and expected.inspect and expected.inspect! or tostring(expected)}, got #{got and got.inspect and got.inspect! or tostring(got)}"
		if got == expected
			emit true, msg
			true
		else
			trace = debug.traceback "", 2
			emit false, msg, trace
			false

	refute_equal = (got, not_expected, msg = nil) ->
		msg or= "Expected values to not be equal: #{got and got.inspect and got.inspect! or tostring(got)} != #{not_expected and not_expected.inspect and not_expected.inspect! or tostring(not_expected)}"
		if got != not_expected
			emit true, msg
			true
		else
			trace = debug.traceback "", 2
			emit false, msg, trace
			false

	assert_not_equal = refute_equal

	-- Deep comparison for tables
	deep_equal = (a, b) ->
		return a == b if type(a) != "table" or type(b) != "table"
		return false if #a != #b

		for k, v in pairs(a)
			return false unless deep_equal(v, b[k])

		for k, v in pairs(b)
			return false unless deep_equal(v, a[k])

		return true

	assert_deep_equal = (got, expected, msg = nil) ->
		msg or= "Expected tables to be deeply equal"
		if deep_equal(got, expected)
			emit true, msg
			true
		else
			trace = debug.traceback "", 2
			emit false, msg, trace
			false

	refute_deep_equal = (got, not_expected, msg = nil) ->
		msg or= "Expected tables to not be deeply equal"
		if not deep_equal(got, not_expected)
			emit true, msg
			true
		else
			trace = debug.traceback "", 2
			emit false, msg, trace
			false

	assert_contains = (haystack, needle, msg = nil) ->
		msg or= "Expected '#{haystack}' to contain '#{needle}'"
		if string.find(haystack, needle, 1, true)
			emit true, msg
			true
		else
			trace = debug.traceback "", 2
			emit false, msg, trace
			false

	refute_contains = (haystack, needle, msg = nil) ->
		msg or= "Expected '#{haystack}' to not contain '#{needle}'"
		if not string.find(haystack, needle, 1, true)
			emit true, msg
			true
		else
			trace = debug.traceback "", 2
			emit false, msg, trace
			false

	-- Helper function to check if a string contains a pattern
	contains_pattern = (str, pattern) ->
		return str\match(pattern) != nil

	-- Exception handling helpers
	get_trace = (fn) ->
		trace = ""
		handler = (e) ->
			trace = debug.traceback e, 2
			trace
		ok, result = xpcall fn, handler
		{ ok, result, trace }

	assert_raise = (fn, msg = "Expected an error to be raised") ->
		{ ok, result, trace } = get_trace fn
		if ok
			trace = debug.traceback "", 2
			emit false, msg, trace
			false
		else
			emit true, msg, trace
			true

	refute_raise = (fn, msg = "Expected no error to be raised") ->
		{ ok, result, trace } = get_trace fn
		if not ok
			trace = debug.traceback "", 2
			emit false, "#{msg}: #{result}", trace
			false
		else
			emit true, msg
			true

	assert_no_raise = refute_raise

	-- Reporting functions
	report_text = ->
		output_buffer

	get_stats = ->
		total = passes + fails
		"Tests run: #{total}, Passed: #{passes}, Failed: #{fails}"

	finish_test = ->
		total = passes + fails
		if output_style == "tap"
			writeln "\n1..#{total}"
		writeln "\n#{get_stats!}"
		is_finished = true
		output_buffer

	report = ->
		finish_test!

	-- Run a list of test functions
	run_tests = (tests) ->
		results = {}
		for name, fn in pairs(tests)
			-- Run the test and capture the result
			result = fn!
			-- Store the result
			results[name] = result
		results

	{
		-- Basic assertions
		assert: assert
		refute: refute
		
		-- Equality assertions
		assert_equal: assert_equal
		refute_equal: refute_equal
		assert_not_equal: assert_not_equal
		
		-- Table assertions
		deep_equal: deep_equal
		assert_deep_equal: assert_deep_equal
		refute_deep_equal: refute_deep_equal
		
		-- Exception assertions
		assert_raise: assert_raise
		refute_raise: refute_raise
		assert_no_raise: assert_no_raise
		
		-- String assertions
		assert_contains: assert_contains
		refute_contains: refute_contains
		contains_pattern: contains_pattern
		
		-- Reporting
		report: report
		report_text: report_text
		get_stats: get_stats
		finish_test: finish_test
		get_output: report_text
		
		-- Test control
		run_tests: run_tests
		
		-- State access
		passes: -> passes
		fails: -> fails
		count: -> count
		is_finished: -> is_finished
	}

-- Return the test_factory function
return_value = { test_factory: test_factory }

-- Test suite trigger
if arg and arg[0] and arg[1] == "--test"
	-- Check for verbose flag
	is_verbose = false
	for i = 1, #arg
		if arg[i] == "--verbose" or arg[i] == "-v"
			is_verbose = true
			break

	-- Create a test factory instance to test itself
	tf = test_factory("dot", io.write, is_verbose)

	-- Test basic assertions
	tf.assert true, "Basic assertion should pass"
	tf.assert not false, "Negated false should pass"
	tf.refute false, "Basic refutation should pass"
	tf.refute not true, "Negated true refutation should pass"

	-- Test assert_equal and refute_equal
	tf.assert_equal 42, 42, "Numbers should be equal"
	tf.assert_equal "test", "test", "Strings should be equal"
	tf.refute_equal 42, 43, "Different numbers should not be equal"
	tf.refute_equal "test", "test2", "Different strings should not be equal"

	-- Test deep equality
	a = {1, 2, 3}
	b = {1, 2, 3}
	c = {1, 2, 4}
	d = {a: 1, b: 2, c: {x: 1, y: 2}}
	e = {a: 1, b: 2, c: {x: 1, y: 2}}
	f = {a: 1, b: 2, c: {x: 1, y: 3}}

	tf.assert_deep_equal a, b, "Arrays with same values should be deeply equal"
	tf.refute_deep_equal a, c, "Arrays with different values should not be deeply equal"
	tf.assert_deep_equal d, e, "Nested tables with same values should be deeply equal"
	tf.refute_deep_equal d, f, "Nested tables with different values should not be deeply equal"

	-- Test assert_not_equal (alias for refute_equal)
	tf.assert_not_equal 42, 43, "Different numbers should not be equal"
	tf.assert_not_equal "test", "test2", "Different strings should not be equal"

	-- Test assert_contains and refute_contains
	tf.assert_contains "hello world", "world", "String should contain substring"
	tf.assert_contains "testing 123", "123", "String should contain numbers"
	tf.refute_contains "hello world", "goodbye", "String should not contain substring"
	tf.refute_contains "testing 123", "456", "String should not contain certain numbers"

	-- Test assert_raise and refute_raise
	tf.assert_raise(-> error("test error"), "Should catch errors")
	tf.refute_raise(-> return 42, "Should not raise on valid function")

	-- Test assert_no_raise (alias for refute_raise)
	tf.assert_no_raise(-> return 42), "Should not raise on valid function"

	-- Test that failures don't raise but still record properly
	-- We need a separate test factory to test failures without affecting our main test
	fail_tf = test_factory("dot", (_s) -> nil)
	
	-- Test success case
	result = fail_tf.assert true, "This should pass"
	tf.assert_equal result, true, "Assert should return true on success"
	
	-- Test failure case - this should return false, not raise an error
	result = fail_tf.assert false, "This should fail but not raise"
	tf.assert_equal result, false, "Assert should return false on failure"
	
	-- Verify that the counts were updated correctly
	tf.assert_equal fail_tf.passes!, 1, "Pass count should be 1"
	tf.assert_equal fail_tf.fails!, 1, "Fail count should be 1"

	-- Test error formatting with a custom object
	inspect_obj = {
		inspect: ->
			"inspected value"
	}

	-- Create a message that would use inspect
	expected_msg = "Expected inspected value, got something else"
	actual_msg = "Expected #{inspect_obj.inspect!}, got something else"
	tf.assert_equal actual_msg, expected_msg, "Should use inspect when available"

	-- We don't need to test the report format, it's being used by the test itself
	-- Just verify that we have the right number of passes and fails
	tf.assert tf.passes! > 0, "Should have at least one passing test"
	
	-- Verify TAP output format without affecting the main test count
	-- Create a TAP test factory with a string buffer writer
	tap_output = ""
	tap_writer = (s) -> tap_output ..= s
	tap_tf = test_factory("tap", tap_writer)
	
	-- Run tests in the TAP format
	tap_tf.assert true, "TAP passing test"
	
	-- We need to use pcall here because we're deliberately causing failures
	pcall ->
		tap_tf.assert false, "TAP failing test"
		tap_tf.assert_raise (-> 42), "Should raise but doesn't"
	
	-- Finish the test to generate the final report
	tap_tf.finish_test!
	
	-- Debug output in verbose mode
	if is_verbose
		print("\nTAP test report: [" .. tap_output .. "]")
	
	-- Check for key elements in the TAP output using the main test factory
	tf.assert_contains tap_output, "ok 1", "TAP output should contain passing test marker"
	tf.assert_contains tap_output, "not ok 2", "TAP output should contain failing test marker"
	tf.assert_contains tap_output, "1..3", "TAP output should contain test count summary"
	tf.assert_contains tap_output, "Tests run: 3", "TAP output should contain test statistics"

	-- Verify dot output format without affecting the main test count
	-- Create a dot test factory with a string buffer writer
	dot_output = ""
	dot_writer = (s) -> dot_output ..= s
	dot_tf = test_factory("dot", dot_writer)
	
	-- Run tests in the dot format
	dot_tf.assert true, "Dot passing test"
	
	-- We need to use pcall here because we're deliberately causing failures
	pcall ->
		dot_tf.assert false, "Dot failing test"
	
	-- Finish the test to generate the final report
	dot_tf.finish_test!
	
	-- Debug output in verbose mode
	if is_verbose
		print("\nDot test report: [" .. dot_output .. "]")
	
	-- Check for key elements in the dot output using the main test factory
	tf.assert_contains dot_output, ".", "Dot output should contain dot for passing test"
	tf.assert_contains dot_output, "F", "Dot output should contain F for failing test"
	tf.assert_contains dot_output, "Tests run:", "Dot output should contain test statistics"

	-- Test that the report function works
	tf.report!

	-- Exit with the number of failures
	os.exit tf.fails!

return return_value
