# Agent Guidelines for ~/dotfiles Development

This document provides guidelines for AI agents (like Claude) working on this dotfiles repository.

## Test-Driven Development (TDD)

I strongly prefer **Test-Driven Development**:

1. **Write a test first** with the expected API
2. **Watch it fail** (red)
3. **Implement the API** to make the test pass
4. **Watch it pass** (green)
5. **Refactor** if needed (refactor)

### Test Standards

#### Test Execution Patterns

Most executables in `bin/` support a `--test` flag:

- **`script --test`**: Runs associated test with **stdout muted**, **stderr preserved**
- **`bin/test/script_test`** (direct): Shows **progress on stdout**, **errors on stderr**
- **Exit codes**: Should return the **number of failed tests** (0 = all passed)

#### Test File Structure

- Test files live in `bin/test/` and are named `{script}_test`
- Tests should be written in **Bash**
- **Never source** the script under test - call it directly via PATH
- **Don't re-implement logic** - test the actual executable behavior
- Use `((tests++))` to increment test counters, not `test_count=$((test_count + 1))`
- For failure counting, use one of these patterns:
  - With `assert`: `assert condition; ((fails+=$?))`
  - With explicit checks: `if condition; then success_msg; else error_details >&2; ((fails++)); fi`
- See `bin/test/expand_test` for assert pattern, `bin/test/hook_test` for if/then pattern

#### Output Standards

**When run directly (`bin/test/script_test`):**

- Progress messages → **stdout** (e.g., "Testing feature X...", "✓ Test passed")
- Success summaries → **stdout** (e.g., "All 5 tests passed")
- Error details → **stderr** (e.g., "✗ Test failed:", diagnostic info)
- Failure summaries → **stderr** (e.g., "3 of 5 tests failed")

**When run via `--test` flag:**

- Stdout is muted (`>/dev/null`)
- Only stderr (errors) are visible
- Should run quickly and silently when all tests pass

### Test Frequency

- **Run tests frequently** while editing code
- **ALWAYS run tests** before declaring task completion
- Fix any test failures immediately

### When Tests Won't Pass

If you cannot make a test pass after a few attempts:

- **Ask for input** - show me the relevant code and explain your dilemma
- **NEVER comment out tests** that you can't make pass
- **NEVER modify the code under test** just to make the test pass
- **Your humility is paramount** - it's better to admit confusion than to hack around it

Remember: failing tests often reveal important insights about the problem domain.

## Script Standards

All scripts in `bin/` should support at minimum:

- **`-h`** or **`--help`**: Show usage information
- **`--test`**: Run associated tests (if available)

### Language Restrictions

- **No Python**: Do not create, modify, or depend on Python scripts or tooling. Prefer Bash or POSIX shell, Lua-family (LuaJIT/MoonScript/Yuescript), or other approved runtimes instead.
- **No Perl**: Do not create, modify, or depend on Perl scripts or tooling either. I know it's fast, but it's also a mess.

Shebangs should be `#!/usr/bin/env <language executable>`.

Optionally:

- **`-a`** or **`--about`**: Show a one-line summary of the command's functionality
- **`-v`** or **`--version`**: Show version information

## Formatting

- Use tabs for indentation in every language that supports it (MoonScript, Yuescript, Lua/LuaJIT, Bash, etc.)
- Use 2 spaces for indentation in every language that does not support tabs

## Development Environment

### Path Structure

- `$HOME/bin` is symlinked to `$HOME/dotfiles/bin`
- `$HOME/bin` is what's actually on PATH
- All executable scripts in `bin/` are available system-wide

### Useful Utilities Available

Since all `bin/` scripts are on PATH, these utilities are available:

#### Language Runners

- **`moonrun`**: Execute MoonScript files, recompiling to Lua on change if necessary (shortcuts to corresponding `.lua` via luajit if available)
- **`yuerun`**: Execute Yuescript files, recompiling to Lua on change if necessary (shortcuts to corresponding `.lua` via luajit if available)

#### Testing & Development

- **`repeat`**: Repeat a command N times (e.g., `repeat 5 echo "hello"`)
- **`assert`**: Assert conditions in scripts
- **Various counters**: Global counter implementations for testing/debugging

#### Command Inspection

- **`show`**: Shows ALL reachable definitions of any command, function, or alias
  - Also available as **`what`** or **`what is`** wrapper
  - Also available as **`d`** alias (short for "display" or "define")
  - Essential for debugging command shadowing issues (e.g., builtin vs executable conflicts)
  - Example: `show echo` reveals both the builtin and executable versions

#### Shell Utilities

- **`expand`**: Enable globbing for its arguments (globbing is disabled globally)
  ```bash
  # Example: list all .md files
  ls -al $(expand *.md)
  # or just:
  expand *.md
  # or:
  expand -i "**/*.{png,gif,jpg,jpeg,webp,svg}"
  # You can also do this to pass commands to it which will then get pre-expanded arguments:
  expand ls *.md
  ```

- **`trim_leading_heredoc_whitespace`**: Intelligently removes leading whitespace from heredocs
  ```bash
  # Instead of using <<-'EOF' which strips ALL leading tabs:
  cat <<'EOF' | trim_leading_heredoc_whitespace
  	This is indented with tabs
  		This is indented more
  	Back to base indentation
  EOF
  # This preserves relative indentation while removing the common leading whitespace
  # Perfect for maintaining proper indentation in help text and multi-line strings
  ```

#### Random Number Generation

- **`nrandom`**: Normal distribution random numbers
- **`drandom`**: Deterministic random numbers (for reproducible testing)
- **`random`**: High-quality uniform random numbers using system entropy

### Advanced Development Utilities

#### Testing Framework (`bin/src/test_factory.moon`)

Also available in YueScript: `bin/src/test_factory.yue`

A sophisticated MoonScript testing framework available as an alternative to bash tests:

**Features:**

- **Multiple output formats**: TAP and dot-style output
- **Rich assertion library**: `assert_equal`, `assert_contains`, `assert_deep_equal`, `assert_raise`, etc.
- **Colored output** with ANSI coloring for better readability
- **Colored output** with ANSI coloring for better readability
- **Stack traces** for debugging test failures
- **Statistical testing support** for building custom assertions
- **Error handling** with `refute` (negative assertions)

**Usage Example:**

```moonscript
test_factory = require("src/test_factory").test_factory
t = test_factory("dot")
t.assert_equal(42, 42, "Numbers should be equal")
t.assert_contains("hello world", "world", "String should contain substring")
t.report()
```

**When to consider:**

- Complex statistical testing (like our `random` tests)
- Projects that need structured test suites
- Integration with TAP-compatible test runners
- When bash tests become too unwieldy

#### CLI Utilities (`bin/src/cli_utils.moon`)

Also available in YueScript: `bin/src/cli_utils.yue`

Provides standardized CLI argument parsing and better RNG seeding:

**Features:**

- **`parse_args(config, argv)`**: Sophisticated argument parser with:
  - Flag validation and type checking
  - Automatic help generation
  - Support for both flags and positional arguments
  - Custom validators per argument
- **`seed_rng()`**: High-precision seeding using `gettimeofday` with microsecond precision
- **Structured configuration** for consistent CLI interfaces

**Usage Example:**

```moonscript
cli_utils = require("src/cli_utils")
config = {
  { name: "verbose", flags: {"-v", "--verbose"}, has_arg: false, description: "Enable verbose mode" }
  { name: "file", flags: {"-f", "--file"}, has_arg: true, description: "Path to input file" }
}
options, positionals = cli_utils.parse_args(config)
```

**When to consider:**

- Scripts with complex argument parsing needs
- When you want consistent help formatting across tools
- Projects that need argument validation
- Alternative to manual argument parsing in current scripts

### Test Coverage

- Test coverage is a **work in progress** - not everything has tests yet
- When working on existing code, add tests if missing
- When creating new code, follow TDD principles
- **Consider `test_factory.moon`** for complex test scenarios

### Test Pattern

- Test scripts should be directly executable with information about passing tests going to stdout and errors/fails to stderr; tests should exit with a code equal to the number of fails
- Executable scripts that are not tests should accept a --test argument, which executes their associated test but with stdout directed to /dev/null (which will cause only errors/fails to appear on stderr)
  - The idea is that directly running the test shows everything, but `commandname --test` is just a quick check that is normally silent (except for exit code and any errors)
- Tests should be written in such a way that they can be run concurrently without interference or race conditions

## Cleanup

- Clean up any **extraneous files** created only to produce core code or test out ideas
- Files in `/tmp/` don't need manual cleanup (system handles this)
- Remove any other temporary test files, build artifacts, etc.

## Code Quality

- Follow existing patterns and conventions in the codebase
- Use available utilities rather than reimplementing functionality
- Keep scripts focused and single-purpose
- Document complex logic with comments
- Clean up after yourself by documenting all newly-created files!
- Do not randomly use Python. In fact, just avoid Python altogether. It is overrated.

## Collaboration & Decision Making

**We are pair-programmers.** For any architectural decisions that are: left incompletely specified, have ambiguous solutions, present significant tradeoffs, or could be implemented multiple ways: **Always rope me into the conversation.** Don't make assumptions - ask for clarification and discuss the options.

**Constructive critique is always welcome:**

- Suggest improvements to existing code
- Point out potential issues or better approaches
- Question design decisions when appropriate
- Propose refactoring opportunities

The goal is collaborative problem-solving, not just task execution.

- Avoid beginning responses with "You're absolutely right!" Instead, use something like "Damn, it feels good to be a gangsta!" or an exuberant famous quote from a song or movie.
