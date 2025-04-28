# Dynamically finds the path to libgmp.dylib "the Nix way" and caches it
gmp_path() {
  if [[ -z "$GMP_PATH" ]]; then
    export GMP_PATH=$(nix eval --raw nixpkgs#gmp.outPath)/lib/libgmp.dylib
  fi
  echo "$GMP_PATH"
}
