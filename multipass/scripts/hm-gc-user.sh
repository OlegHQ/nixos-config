#!/bin/sh
set -eu

if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
expire="${MULTIPASS_HM_EXPIRE:-7d}"

nix profile wipe-history \
  --profile "$HOME/.local/state/nix/profiles/home-manager" \
  --older-than "$expire" || true

nix profile wipe-history \
  --profile "$HOME/.local/state/nix/profiles/profile" \
  --older-than "$expire" || true
