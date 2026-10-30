# Nix-store copy guard

The `cp`, `install`, and `rsync` wrappers refuse copy invocations with operands
that name or resolve into `/nix/store`. Refusal exits 77 before the underlying
tool runs. The message explains the failure and the declarative alternative.
Bash functions exported by `.envconfig` retain the guard when an agent prepends
its own executables to PATH. Other shells rely on PATH ordering. Existing Bash
sessions can source `~/dotfiles/bin/src/nix_store_copy_env.bash`; new sessions
load it normally. Use `hash -r` to clear any cached native command locations.

## Why this matters

Copying an undeclared dependency from one machine's store hides where it came
from, which revision produced it, and what built it. A local build can then pass
while clean CI fails or builds different code. Copying an executable can also
leave runtime references to store paths that do not exist on the destination.
Neither a recognizable filename nor a store hash substitutes for a dependency
declaration and a working build closure.

Declare packages or pinned sources in `flake.nix` and commit the lockfile.
Stage declared source inside the derivation, using Nix references such as
`${inputs.engine}` or `${pkgs.foo}`. Build through `nix build`. The shared
`writing-nix` skill's dependency-portability reference covers Rust/Zig staging.

Copying those declared inputs *inside a derivation* is normal Nix packaging.
Nix builders use their declared tools, not the developer's host PATH wrappers
or exported shell functions. The guard does not edit or intercept Nix itself.
If a derivation deliberately includes these wrappers, it must account for them.

## Intentional exports

Exporting a known release output or copying a bounded file for inspection is
different from scavenging dependencies. The wrapper cannot prove that intent,
so even a `result/bin/app` symlink requires a reason:

```sh
nix build .#app
ALLOW_NIX_STORE_COPY='Exporting the declared release output' cp result/bin/app ./release/
```

The override applies to one invocation and prints its reason on stderr. It
requires at least 12 characters, two words, and no control characters. Do not
export it globally or use it to conceal missing flake inputs. It does not make
an exported binary relocatable; packaging must establish that separately.

## Scope and limitations

- Checks literal store paths, local relative paths and symlink ancestors,
  including dangling aliases whose remaining path does not exist yet.
- Conservatively checks every path-like argument, including option values and
  store destinations. This can refuse metadata reads such as a store-backed
  `--files-from` list; use a reasoned exception when appropriate.
- Recognizes explicit remote `host:/nix/store/...` operands. It does not resolve
  remote aliases or inspect remote files.
- Does not walk source directories to find nested symlinks. It does not inspect
  archives, rsync file-list contents, arbitrary programs, redirects, or alternate
  absolute-path executables. Hardlinks and races between checking and copying
  are outside its guarantee. This is an accident guard, not confinement.
- Requires GNU `realpath -m`, supplied by Nix coreutils, to resolve local paths.
  Missing resolution support fails closed rather than silently permitting aliases.
- No blanket Nix-store read prohibition: the separate search guard blocks only
  whole-store traversal; inspection of a known bounded output remains allowed.

`bin/test/nix-store-copy_test` exercises the policy against recording adapters
and a real copy into disposable scratch. The normal `./test` includes it.
