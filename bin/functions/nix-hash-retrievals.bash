latest-nix-unstable-hash() {
	curl -s https://api.github.com/repos/nixos/nixpkgs/branches/nixpkgs-unstable | jq -r '.commit.sha'
}

latest-nix-stable-hash() {
	curl -s https://api.github.com/repos/nixos/nixpkgs/branches/nixos-24.11 | jq -r '.commit.sha'
}

latest-nix-master-hash() {
	curl -s https://api.github.com/repos/nixos/nixpkgs/branches/master | jq -r '.commit.sha'
}
