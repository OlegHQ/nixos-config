#!/bin/sh
set -eu

user_name="${MULTIPASS_USER:-snowbear}"
user_id="${MULTIPASS_UID:-501}"
group_id="${MULTIPASS_GID:-501}"
home_dir="/home/${user_name}"
host_home="${MULTIPASS_HOST_HOME:-/Users/${user_name}}"
authorized_keys_file="${MULTIPASS_AUTHORIZED_KEYS_FILE:-}"
machine_name="${MULTIPASS_NAME:-$(hostname)}"
tailscale_auth_key="${MULTIPASS_TAILSCALE_AUTH_KEY:-}"
tailscale_extra_args="${MULTIPASS_TAILSCALE_EXTRA_ARGS:-}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ca-certificates \
  cloud-guest-utils \
  curl \
  docker.io \
  docker-compose-v2 \
  fish \
  git \
  mosh \
  openssh-server \
  sudo \
  xz-utils

touch /etc/snowbear-multipass
mkdir -p /etc/sudoers.d

if ! getent group "$user_name" >/dev/null 2>&1; then
  if getent group "$group_id" >/dev/null 2>&1; then
    user_group="$(getent group "$group_id" | cut -d: -f1)"
  else
    groupadd --gid "$group_id" "$user_name"
    user_group="$user_name"
  fi
else
  user_group="$user_name"
fi

if id "$user_name" >/dev/null 2>&1; then
  usermod --shell /usr/bin/fish "$user_name"
else
  useradd \
    --uid "$user_id" \
    --gid "$user_group" \
    --create-home \
    --home-dir "$home_dir" \
    --shell /usr/bin/fish \
    "$user_name"
fi

usermod --append --groups sudo,docker "$user_name"
install -d -m 0755 -o "$user_name" -g "$user_group" "$home_dir"
install -d -m 0700 -o "$user_name" -g "$user_group" "$home_dir/.ssh"

cat > /usr/local/bin/snowbear-multipass-login <<EOF
#!/bin/sh
set -eu

target_user="${user_name}"
target_home="${home_dir}"
target_shell="\${target_home}/.nix-profile/bin/fish"

if [ ! -x "\$target_shell" ]; then
  target_shell=/usr/bin/fish
fi

cd "\$target_home"

exec sudo -H -u "\$target_user" env \\
  PATH="/nix/var/nix/profiles/default/bin:\${target_home}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \\
  HOME="\$target_home" \\
  SHELL="\$target_shell" \\
  USER="\$target_user" \\
  LOGNAME="\$target_user" \\
  SNOWBEAR_MULTIPASS=1 \\
  "\$target_shell" -l
EOF
chmod 0755 /usr/local/bin/snowbear-multipass-login

if id ubuntu >/dev/null 2>&1; then
  ubuntu_rc=/home/ubuntu/.bashrc
  install -d -m 0755 -o ubuntu -g ubuntu /home/ubuntu
  if [ ! -e "$ubuntu_rc" ]; then
    install -m 0644 -o ubuntu -g ubuntu /dev/null "$ubuntu_rc"
  fi
  if ! grep -Fq "snowbear-multipass-login" "$ubuntu_rc"; then
    tmp_rc="$(mktemp)"
    cat > "$tmp_rc" <<'EOF'
# snowbear multipass interactive login
if [ -z "${SNOWBEAR_MULTIPASS_NO_DELEGATE:-}" ] && [ -t 0 ] && [ -t 1 ]; then
  exec /usr/local/bin/snowbear-multipass-login
fi

EOF
    cat "$ubuntu_rc" >> "$tmp_rc"
    install -m 0644 -o ubuntu -g ubuntu "$tmp_rc" "$ubuntu_rc"
    rm -f "$tmp_rc"
  fi
fi

cat > "/etc/sudoers.d/${user_name}" <<EOF
${user_name} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 0440 "/etc/sudoers.d/${user_name}"

authorized_keys_tmp="$(mktemp)"
if [ -n "$authorized_keys_file" ] && [ -s "$authorized_keys_file" ]; then
  cat "$authorized_keys_file" >> "$authorized_keys_tmp"
fi

if [ -s "${host_home}/.ssh/authorized_keys" ]; then
  cat "${host_home}/.ssh/authorized_keys" >> "$authorized_keys_tmp"
fi

for public_key in "${host_home}"/.ssh/id_*.pub; do
  if [ -s "$public_key" ]; then
    cat "$public_key" >> "$authorized_keys_tmp"
  fi
done

if [ -s "$authorized_keys_tmp" ]; then
  awk '!seen[$0]++' "$authorized_keys_tmp" > "${home_dir}/.ssh/authorized_keys"
  chown "$user_name:$user_group" "${home_dir}/.ssh/authorized_keys"
  chmod 0600 "${home_dir}/.ssh/authorized_keys"
fi
rm -f "$authorized_keys_tmp"

systemctl enable --now docker.service
systemctl enable --now ssh.service

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

modprobe tun >/dev/null 2>&1 || true
systemctl enable --now tailscaled.service

if [ -n "$tailscale_auth_key" ]; then
  if ! tailscale status >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    tailscale up --hostname="$machine_name" --auth-key="$tailscale_auth_key" $tailscale_extra_args
  fi
fi

if ! command -v nix >/dev/null 2>&1 && [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
fi

if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

systemctl enable --now nix-daemon.service

echo "multipass-provisioned=${machine_name}"
