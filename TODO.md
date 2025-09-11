# TODO: Standardize --about/-a Support Across Dotfiles

## Goal
Ensure every executable in `./bin` and every function in `bin/src/*.{sh,bash}` that responds to `--help` also responds to `--about` and `-a` with a single-line description of what the functionality does.

## Progress Overview
- ✅ **81 total scripts** with `--help` support identified in `./bin` 
- ✅ **18 additional files** in `src/` with `--help` support identified
- ✅ **62 scripts** already had some form of `--about` support
- ✅ **54 scripts** were missing `--about` support (partially completed)
- ✅ Fixed multi-line `--about` outputs to be single-line descriptions

## Key Discovery Commands

### Find all scripts with --help support:
```bash
rg -l -- '--help' . > /tmp/help_supported_scripts.txt
```

### Find scripts with existing --about support:
```bash
rg -l -- '--about|-a' . > /tmp/about_supported.txt
```

### Find scripts missing --about support:
```bash
comm -23 <(sort /tmp/help_supported_scripts.txt | sed 's|^\./||') <(sort /tmp/about_supported.txt | sed 's|^\./||') > /tmp/missing_about.txt
```

## Completed Scripts (Examples)
- ✅ `align-on-equals` - "Align text on equal signs for configuration-style output"
- ✅ `calc` - "Do simple math calculations in the shell using bc"
- ✅ `clip` - "Cross-platform clipboard utility for copy/paste operations"
- ✅ `executables` - "Print out the names of all executables available in your PATH"
- ✅ `ansi-chart` - "Display ANSI color charts for the current terminal"
- ✅ `apfs-dedup` - "Deduplicate files using APFS cloning to save disk space"
- ✅ `posix-counter` - Fixed to single-line: "Atomic counter using POSIX shared memory"
- ✅ `fs-counter` - Fixed to single-line: "Atomic counter using filesystem-based locking"
- ✅ `sysv-counter` - Fixed to single-line: "Atomic counter using System V IPC shared memory"

## Remaining Work

### Scripts Still Missing --about Support
Run this command to get current list:
```bash
comm -23 <(rg -l -- '--help' . | sed 's|^\./||' | sort) <(rg -l -- '--about|-a' . | sed 's|^\./||' | sort)
```

As of last check, these were among the remaining:
- `ask_local`
- `datetimestamp` 
- `decrypt`
- `div`
- `drandom`
- `ds_bore`
- `exclude_path`
- `expand`
- `ff`
- `fsattr`
- `httpstat`
- `install-proton-game-mod`
- `name-value-to-table`
- `name-value-to-table-elixir`
- `name-value-to-table.lua`
- And ~40 more...

### Implementation Pattern

For bash scripts, add to argument parsing:
```bash
case "$1" in
    -h|--help)
        # existing help...
        echo "  -a, --about   Show brief description"
        # rest of help...
        ;;
    -a|--about)
        echo "Single-line description of functionality"
        exit 0
        ;;
    # other cases...
esac
```

For function-based scripts, add to the function's argument parsing similar pattern.

For LuaJIT scripts, add to the argument handling:
```lua
if args[1] == "--about" or args[1] == "-a" then
    print("Single-line description of functionality")
    return
end
```

### Verification Commands

Test a script has working --about support:
```bash
./script-name --about
./script-name -a
```

Find any remaining multi-line --about outputs:
```bash
for script in $(rg -l -- '--about|-a' .); do
    if [ -x "$script" ]; then
        lines=$(timeout 2s "$script" --about 2>/dev/null | wc -l)
        if [ "$lines" -gt 1 ]; then
            echo "Multi-line: $script ($lines lines)"
        fi
    fi
done
```

## Notes
- Some scripts are moonscript/yuescript with corresponding .lua files - only update the moonscript/yuescript files because the .lua files are auto-generated in those cases (run them with --about to autogenerate the .lua file)
- Maintain existing code style and conventions
- Test all modifications with both `--about` and `-a` flags
- Keep descriptions concise and descriptive of core functionality
