#!/bin/sh
set -eu

expire="${CONTAINER_HM_EXPIRE:-7d}"

nix profile wipe-history \
  --profile "$HOME/.local/state/nix/profiles/home-manager" \
  --older-than "$expire" || true

nix profile wipe-history \
  --profile "$HOME/.local/state/nix/profiles/profile" \
  --older-than "$expire" || true
