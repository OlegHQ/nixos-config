#!/bin/sh
set -eu

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/nix/var/nix/profiles/default/bin

if command -v tailscale >/dev/null 2>&1; then
  tailscale logout >/dev/null 2>&1 || tailscale down >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl stop tailscaled.service >/dev/null 2>&1 || true
  systemctl disable tailscaled.service >/dev/null 2>&1 || true
fi

echo tailscale-disabled
