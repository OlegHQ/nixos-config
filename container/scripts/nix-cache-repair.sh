#!/bin/sh
set -eu

conf=/etc/nix/nix.conf
tmp="$(mktemp)"
user_name="${CONTAINER_USER:-snowbear}"
substituters="${CONTAINER_NIX_SUBSTITUTERS:-https://cache.nixos.org/}"
trusted_public_keys="${CONTAINER_NIX_TRUSTED_PUBLIC_KEYS:-cache.nixos.org-1:6NCHdD59X431o0gWkM8wLaM/CDG7M0mVjZ5VkgS8rGs=}"
require_sigs="${CONTAINER_NIX_REQUIRE_SIGS:-false}"

mkdir -p /etc/nix
touch "$conf"
cp "$conf" "$tmp"

ensure_setting() {
  key="$1"
  value="$2"
  next="${tmp}.next"

  if grep -Eq "^${key}[[:space:]]*=" "$tmp"; then
    sed "s|^${key}[[:space:]]*=.*|${key} = ${value}|" "$tmp" > "$next"
  else
    cp "$tmp" "$next"
    printf '%s = %s\n' "$key" "$value" >> "$next"
  fi

  mv "$next" "$tmp"
}

ensure_setting experimental-features "nix-command flakes"
ensure_setting build-users-group ""
ensure_setting sandbox "false"
ensure_setting trusted-users "root ${user_name}"
ensure_setting substituters "$substituters"
ensure_setting trusted-public-keys "$trusted_public_keys"
ensure_setting require-sigs "$require_sigs"

if cmp -s "$tmp" "$conf"; then
  rm -f "$tmp"
  exit 0
fi

install -m 0644 "$tmp" "$conf"
rm -f "$tmp"
exit 10
