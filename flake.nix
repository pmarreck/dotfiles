{
  description = "Peter Marreck's dotfiles — shell configuration and bin/ utilities";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Tools the suite shells out to. This is deliberately explicit rather than
        # inheriting the builder's environment: the point of the check is to prove
        # the dotfiles work against a declared toolset, not against whatever happens
        # to be installed on the machine running it.
        suiteTools = with pkgs; [
          bash coreutils gnused gnugrep gawk findutils diffutils
          jq ripgrep fd tmux expect git openssh
          gzip gnutar zip unzip xz bc file which
          (luajit.withPackages (luaPackages: [ luaPackages.lua-cjson ]))
          perl
          util-linux   # hexdump
          xxd
          imagemagick  # magick
          ffmpeg       # ffmpeg, ffprobe
        ];
      in {
        checks = {
          test = pkgs.stdenv.mkDerivation {
            pname = "dotfiles-test";
            version = "0.1.0";
            src = ./.;
            nativeBuildInputs = suiteTools;
            dontConfigure = true;
            dontBuild = true;

            # The Linux Nix sandbox has no /usr/bin/env, so every
            # `#!/usr/bin/env bash` script in bin/ dies with "bad interpreter".
            # patchShebangs rewrites them to absolute store paths. The failure is
            # semi-silent — the interpreter never runs, so assertions fail with
            # confusing downstream symptoms rather than an obvious shebang error —
            # and Darwin sandboxes DO have /usr/bin/env, so a green macOS check
            # would prove nothing about Linux.
            postPatch = ''
              patchShebangs bin
            '';

            checkPhase = ''
              runHook preCheck

              # Reproduce the real layout: the suite and many bin/ scripts resolve
              # things through $HOME/dotfiles and $HOME/bin. Point HOME at a fixture
              # so we are testing this checkout rather than the builder's account,
              # and so nothing can reach a developer's live configuration.
              export HOME="$NIX_BUILD_TOP/home"
              mkdir -p "$HOME"
              cp -r "$PWD" "$HOME/dotfiles"
              chmod -R u+w "$HOME/dotfiles"
              ln -s "$HOME/dotfiles/bin" "$HOME/bin"

              export XDG_CACHE_HOME="$HOME/.cache"
              export XDG_CONFIG_HOME="$HOME/.config"
              export XDG_DATA_HOME="$HOME/.local/share"
              export XDG_STATE_HOME="$HOME/.local/state"
              mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
              export PATH="$HOME/bin:$PATH"
              export TMPDIR="$NIX_BUILD_TOP/tmp"
              mkdir -p "$TMPDIR"

              cd "$HOME/dotfiles"

              # Remove the tests that cannot run in a sandbox, and say so out loud.
              # A gate that quietly runs fewer tests than it appears to is the exact
              # failure this whole exercise is guarding against, so the excluded set
              # is committed (bin/test/NOT_HERMETIC), printed here in full, and
              # counted. Shrinking coverage is then a visible diff, not a silent one.
              excluded=0
              echo "── excluded from the hermetic check (see bin/test/NOT_HERMETIC) ──"
              while IFS= read -r entry; do
                entry="''${entry%%#*}"
                entry="$(echo "$entry" | tr -d '[:space:]')"
                [ -z "$entry" ] && continue
                if [ -e "bin/test/$entry" ]; then
                  rm -f "bin/test/$entry"
                  excluded=$((excluded + 1))
                  echo "  excluded: $entry"
                else
                  echo "  STALE ENTRY (no such test): $entry" >&2
                fi
              done < bin/test/NOT_HERMETIC
              echo "── $excluded tests excluded; the rest must pass ──"

              bin/run_test_suite

              runHook postCheck
            '';
            doCheck = true;

            installPhase = ''
              mkdir -p "$out"
              echo "dotfiles suite passed" > "$out/result"
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          packages = suiteTools ++ [ pkgs.hyperfine pkgs.shellcheck ];
        };
      });
}
