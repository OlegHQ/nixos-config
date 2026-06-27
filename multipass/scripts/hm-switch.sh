#!/bin/sh
set -eu

profile="${1:?usage: hm-switch.sh <home-profile>}"
repo="${MULTIPASS_REPO:-$(pwd)}"
out_link="${MULTIPASS_HM_OUT_LINK:-$HOME/.cache/snowbear-home-manager/result}"
substituters="${MULTIPASS_NIX_SUBSTITUTERS:-https://cache.nixos.org/}"
trusted_public_keys="${MULTIPASS_NIX_TRUSTED_PUBLIC_KEYS:-cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=}"

if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
export NIX_REMOTE="${NIX_REMOTE:-daemon}"
export NIXPKGS_ALLOW_UNFREE="${NIXPKGS_ALLOW_UNFREE:-1}"
export SNOWBEAR_HOME_MULTIPASS="${SNOWBEAR_HOME_MULTIPASS:-1}"

cd "$repo"
mkdir -p "$(dirname "$out_link")"

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
nix_args="$nix_args --option require-sigs ${MULTIPASS_NIX_REQUIRE_SIGS:-false}"

attempt=0
while ! nix store info --store daemon >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    nix store info --store daemon
    exit 1
  fi
  sleep 1
done

for skel_name in .profile .bashrc; do
  target="${HOME}/${skel_name}"
  skel="/etc/skel/${skel_name}"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    if [ -f "$skel" ] && cmp -s "$target" "$skel"; then
      backup="${target}.before-home-manager"
      backup_index=0
      while [ -e "$backup" ]; do
        backup_index=$((backup_index + 1))
        backup="${target}.before-home-manager.${backup_index}"
      done
      mv "$target" "$backup"
      echo "Moved stock ${target} to ${backup}"
    else
      echo "Refusing to clobber non-stock ${target}; move it aside before running Home Manager." >&2
      exit 1
    fi
  fi
done

# Build the flake activation package directly so persistent VMs follow the
# current repo lockfile instead of an older in-VM launcher.
# shellcheck disable=SC2086
nix build ".#homeConfigurations.${profile}.activationPackage" \
  --impure \
  --out-link "$out_link" \
  $nix_args

"$out_link/activate"
