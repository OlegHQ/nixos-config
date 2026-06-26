#!/bin/sh
set -eu

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
command -v ssh
command -v sshd
command -v mosh
command -v mosh-server
sudo -n true
echo sudo-user

for attempt in 1 2 3 4 5; do
  if docker version >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker version --format 'docker-server={{.Server.Version}}'

command -v tailscale
tailscale version | head -1

test -d "/Users/${CONTAINER_USER:-snowbear}"
echo users-mounted
