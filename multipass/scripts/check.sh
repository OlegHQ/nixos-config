#!/bin/sh
set -eu

if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

printf "arch=%s user=%s home=%s\n" "$(uname -m)" "$USER" "$HOME"
id
groups | grep -qw docker
echo docker-group

command -v fish
command -v nix
nix --version
command -v home-manager
home-manager --version
command -v nvim
command -v tmux
command -v lazygit
command -v docker
command -v screenfetch
command -v sudo
command -v systemctl
command -v ssh
test -x /usr/sbin/sshd
command -v mosh
command -v mosh-server
command -v tailscale
sudo -n true
echo sudo-user

sudo -n systemctl is-active --quiet nix-daemon.service
sudo -n systemctl is-active --quiet docker.service
sudo -n systemctl is-active --quiet ssh.service
sudo -n systemctl is-active --quiet tailscaled.service
echo systemd-services

for attempt in 1 2 3 4 5; do
  if docker version >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker version --format 'docker-server={{.Server.Version}}'
docker compose version

test -f /etc/snowbear-multipass
test -d "${MULTIPASS_VM_REPO:-/home/${MULTIPASS_USER:-snowbear}/src/nixos-config}"
echo repo-synced

host_home="${MULTIPASS_HOST_HOME:-/Users/${MULTIPASS_USER:-snowbear}}"
if [ "${MULTIPASS_MOUNT_HOME:-0}" = "1" ]; then
  findmnt "$host_home" >/dev/null
  echo users-mounted
else
  if findmnt "$host_home" >/dev/null; then
    echo "unexpected host mount at ${host_home}" >&2
    exit 1
  fi
  echo users-not-mounted
fi
