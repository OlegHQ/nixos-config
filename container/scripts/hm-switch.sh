#!/bin/sh
set -eu

profile="${1:?usage: hm-switch.sh <home-profile>}"
repo="${CONTAINER_REPO:-$(pwd)}"
out_link="${CONTAINER_HM_OUT_LINK:-$HOME/.cache/snowbear-home-manager/result}"
substituters="${CONTAINER_NIX_SUBSTITUTERS:-https://cache.nixos.org/}"
trusted_public_keys="${CONTAINER_NIX_TRUSTED_PUBLIC_KEYS:-cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=}"

cd "$repo"
mkdir -p "$(dirname "$out_link")"
export NIXPKGS_ALLOW_UNFREE="${NIXPKGS_ALLOW_UNFREE:-1}"

if git_bin="$(command -v git 2>/dev/null)"; then
  "$git_bin" config --global --add safe.directory "$repo" 2>/dev/null || true
  if command -v sudo >/dev/null 2>&1; then
    sudo -n HOME=/root "$git_bin" config --global --add safe.directory "$repo" 2>/dev/null || true
    sudo -n "$git_bin" config --system --add safe.directory "$repo" 2>/dev/null || true
  fi
fi

nix_args=""
if [ -n "$substituters" ]; then
  nix_args="$nix_args --option substituters ${substituters}"
fi
if [ -n "$trusted_public_keys" ]; then
  nix_args="$nix_args --option trusted-public-keys ${trusted_public_keys}"
fi
nix_args="$nix_args --option require-sigs ${CONTAINER_NIX_REQUIRE_SIGS:-false}"

attempt=0
while ! nix store info --store daemon >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    nix store info --store daemon
    exit 1
  fi
  sleep 1
done

# Build the flake's activation package directly so the switch follows the
# repo lockfile even if the machine was created from an older image.
# shellcheck disable=SC2086
nix build ".#homeConfigurations.${profile}.activationPackage" \
  --impure \
  --out-link "$out_link" \
  $nix_args

"$out_link/activate"
