{ pkgs
, homeConfiguration
, userName
, uid ? "1000"
, gid ? "1000"
}:

let
  homeDir = "/home/${userName}";
  loginShell = "${homeDir}/.nix-profile/bin/fish";
  dockerGid = "131";

  imageNameEnv = builtins.getEnv "CONTAINER_IMAGE_NAME";
  imageTagEnv = builtins.getEnv "CONTAINER_IMAGE_TAG";
  imageName = if imageNameEnv == "" then "local/${userName}-main" else imageNameEnv;
  imageTag = if imageTagEnv == "" then "latest" else imageTagEnv;

  homePath = homeConfiguration.config.home.path;
  homeFiles = homeConfiguration.config.home-files;

  runtimeProfile = pkgs.buildEnv {
    name = "${userName}-container-runtime-profile";
    paths = with pkgs; [
      bashInteractive
      cacert
      coreutils
      curl
      docker
      findutils
      fish
      git
      gnugrep
      gnused
      gnutar
      gzip
      home-manager
      less
      mosh
      nix
      openssh
      sudo
      systemd
      tailscale
      xz
      zstd
    ];
    pathsToLink = [
      "/bin"
      "/etc"
      "/lib"
      "/share"
    ];
    ignoreCollisions = true;
  };

  homePathRef = pkgs.writeTextDir "share/${userName}-home-path-reference" ''
    ${homePath}
  '';
  homeFilesRef = pkgs.writeTextDir "share/${userName}-home-files-reference" ''
    ${homeFiles}
  '';
  runtimeProfileRef = pkgs.writeTextDir "share/${userName}-runtime-profile-reference" ''
    ${runtimeProfile}
  '';
  localeRef = pkgs.writeTextDir "share/${userName}-locale-reference" ''
    ${pkgs.glibcLocales}
  '';

  ubuntuImage = pkgs.dockerTools.pullImage {
    imageName = "ubuntu";
    imageDigest = "sha256:786a8b558f7be160c6c8c4a54f9a57274f3b4fb1491cf65146521ae77ff1dc54";
    hash = "sha256-9ZTHu28scdI8sBh5O7bVbMeDOus0IROohizedulGwxE=";
    arch = "arm64";
    finalImageName = "ubuntu";
    finalImageTag = "24.04";
  };

  root = pkgs.buildEnv {
    name = "${userName}-container-nix-closure-root";
    paths = [
      homePathRef
      homeFilesRef
      runtimeProfileRef
      localeRef
    ];
    pathsToLink = [ "/share" ];
    ignoreCollisions = true;
  };

  dockerArchive = pkgs.dockerTools.buildLayeredImageWithNixDb {
    name = imageName;
    tag = imageTag;
    fromImage = ubuntuImage;
    compressor = "none";
    contents = [ root ];

    extraCommands = ''
      set -eu

      mkdir -p \
        ./etc/docker \
        ./etc/machine \
        ./etc/nix \
        ./etc/pam.d \
        ./etc/ssh \
        ./etc/ssl/certs \
        ./etc/sudoers.d \
        ./etc/systemd/system/basic.target.wants \
        ./etc/systemd/system/multi-user.target.wants \
        ./etc/systemd/system/sysinit.target.wants \
        ./home/${userName} \
        ./nix/var/nix/daemon-socket \
        ./nix/var/nix/gcroots/per-user/${userName} \
        ./nix/var/nix/profiles/default \
        ./nix/var/nix/profiles/per-user/root \
        ./nix/var/nix/profiles/per-user/${userName} \
        ./root \
        ./run \
        ./run/docker \
        ./run/sshd \
        ./run/tailscale \
        ./tmp \
        ./usr/bin \
        ./usr/lib/systemd \
        ./usr/local/bin \
        ./usr/sbin \
        ./var/empty \
        ./var/lib/dbus \
        ./var/lib/docker \
        ./var/lib/tailscale \
        ./var/tmp

      chmod 1777 ./tmp ./var/tmp

      cat > ./etc/group <<'EOF'
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
${userName}:x:${gid}:
sudo:x:27:${userName}
audio:x:29:
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
shadow:x:42:
utmp:x:43:
video:x:44:
sasl:x:45:
plugdev:x:46:
staff:x:50:
games:x:60:
sshd:x:74:
users:x:100:
systemd-journal:x:101:
docker:x:${dockerGid}:${userName}
nogroup:x:65534:
EOF

      cat > ./etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/run/ircd:/usr/sbin/nologin
_apt:x:42:65534::/nonexistent:/usr/sbin/nologin
sshd:x:74:74:sshd:/var/empty:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
${userName}:x:${uid}:${gid}:${userName}:${homeDir}:${loginShell}
EOF

      cat > ./etc/shadow <<'EOF'
root:*:19793:0:99999:7:::
daemon:*:19793:0:99999:7:::
bin:*:19793:0:99999:7:::
sys:*:19793:0:99999:7:::
sync:*:19793:0:99999:7:::
games:*:19793:0:99999:7:::
man:*:19793:0:99999:7:::
lp:*:19793:0:99999:7:::
mail:*:19793:0:99999:7:::
news:*:19793:0:99999:7:::
uucp:*:19793:0:99999:7:::
proxy:*:19793:0:99999:7:::
www-data:*:19793:0:99999:7:::
backup:*:19793:0:99999:7:::
list:*:19793:0:99999:7:::
irc:*:19793:0:99999:7:::
_apt:*:19793:0:99999:7:::
sshd:*:19793:0:99999:7:::
nobody:*:19793:0:99999:7:::
${userName}:*:19793:0:99999:7:::
EOF
      chmod 0644 ./etc/passwd ./etc/group
      chmod 0640 ./etc/shadow

      cat > ./etc/shells <<'EOF'
/bin/sh
/bin/bash
${loginShell}
EOF

      cat > ./etc/sudoers <<'EOF'
Defaults env_keep += "LOCALE_ARCHIVE LOCALE_ARCHIVE_* NIX_REMOTE NIX_SSL_CERT_FILE SSL_CERT_FILE"
root ALL=(ALL:ALL) ALL
@includedir /etc/sudoers.d
EOF
      cat > ./etc/sudoers.d/${userName} <<'EOF'
${userName} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
      chmod 0440 ./etc/sudoers ./etc/sudoers.d/${userName}

      cat > ./etc/pam.d/sudo <<'EOF'
auth sufficient pam_permit.so
account sufficient pam_permit.so
session sufficient pam_permit.so
EOF

      cat > ./etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
build-users-group =
sandbox = false
trusted-users = root ${userName}
substituters = https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
require-sigs = false
EOF

      : > ./etc/machine-id
      : > ./var/lib/dbus/machine-id
      ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ./etc/ssl/certs/ca-certificates.crt

      ln -sf ${pkgs.systemd}/lib/systemd/systemd ./usr/lib/systemd/systemd
      ln -sf /usr/lib/systemd/systemd ./usr/sbin/init
      ln -sf /nix/var/nix/profiles/default/bin/systemctl ./usr/bin/systemctl

      cat > ./etc/systemd/system/sysinit.target <<'EOF'
[Unit]
Description=System Initialization
Documentation=man:systemd.special(7)
DefaultDependencies=no
Conflicts=shutdown.target
Before=basic.target shutdown.target
RefuseManualStart=yes
EOF

      cat > ./etc/systemd/system/basic.target <<'EOF'
[Unit]
Description=Basic System
Documentation=man:systemd.special(7)
Requires=sysinit.target
After=sysinit.target
RefuseManualStart=yes
EOF

      cat > ./etc/systemd/system/multi-user.target <<'EOF'
[Unit]
Description=Multi-User System
Documentation=man:systemd.special(7)
Requires=basic.target
After=basic.target
AllowIsolate=yes
EOF

      cat > ./etc/systemd/system/shutdown.target <<'EOF'
[Unit]
Description=System Shutdown
Documentation=man:systemd.special(7)
DefaultDependencies=no
RefuseManualStart=yes
EOF

      ln -sf multi-user.target ./etc/systemd/system/default.target

      for unit in \
        console-getty.service \
        dev-hugepages.mount \
        getty.target \
        getty@.service \
        sys-fs-fuse-connections.mount \
        systemd-logind.service \
        systemd-tmpfiles-setup.service \
        systemd-update-utmp.service; do
        ln -sf /dev/null "./etc/systemd/system/$unit"
      done

      cat > ./etc/systemd/system/container-create-user.service <<'EOF'
[Unit]
Description=Ensure Apple container machine user
Documentation=https://github.com/apple/container/blob/main/docs/container-machine.md
DefaultDependencies=no
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/etc/machine/create-user.sh
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

      cat > ./etc/systemd/system/nix-daemon.service <<'EOF'
[Unit]
Description=Nix Daemon
After=container-create-user.service
Requires=container-create-user.service

[Service]
Type=simple
Environment=NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ExecStartPre=/bin/mkdir -p /nix/var/nix/daemon-socket
ExecStart=/nix/var/nix/profiles/default/bin/nix-daemon --daemon
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

      cat > ./etc/systemd/system/docker.service <<'EOF'
[Unit]
Description=Docker Application Container Engine
After=container-create-user.service
Requires=container-create-user.service

[Service]
Type=simple
Environment=PATH=/usr/local/bin:/nix/var/nix/profiles/default/bin:/bin:/usr/bin:/sbin:/usr/sbin
ExecStart=/etc/machine/start-dockerd.sh
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

      cat > ./etc/systemd/system/sshd.service <<'EOF'
[Unit]
Description=OpenSSH Daemon
After=container-create-user.service
Requires=container-create-user.service

[Service]
Type=simple
Environment=PATH=/usr/local/bin:/nix/var/nix/profiles/default/bin:/bin:/usr/bin:/sbin:/usr/sbin
ExecStart=/etc/machine/start-sshd.sh
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF
      ln -sf sshd.service ./etc/systemd/system/ssh.service

      cat > ./etc/systemd/system/tailscaled.service <<'EOF'
[Unit]
Description=Tailscale Node Agent
After=container-create-user.service
Requires=container-create-user.service

[Service]
Type=simple
Environment=PATH=/usr/local/bin:/nix/var/nix/profiles/default/bin:/bin:/usr/bin:/sbin:/usr/sbin
ExecStart=/etc/machine/start-tailscaled.sh
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

      ln -sf ../container-create-user.service ./etc/systemd/system/sysinit.target.wants/container-create-user.service
      ln -sf ../nix-daemon.service ./etc/systemd/system/multi-user.target.wants/nix-daemon.service
      ln -sf ../docker.service ./etc/systemd/system/multi-user.target.wants/docker.service
      ln -sf ../sshd.service ./etc/systemd/system/multi-user.target.wants/sshd.service
      ln -sf ../tailscaled.service ./etc/systemd/system/multi-user.target.wants/tailscaled.service

      cat > ./etc/machine/start-dockerd.sh <<'EOF'
#!/bin/sh
set -eu

mkdir -p /var/lib/docker /run/docker
rm -f /var/run/docker.pid /var/run/docker.sock /run/docker.pid /run/docker.sock

/nix/var/nix/profiles/default/bin/dockerd \
  --host=unix:///var/run/docker.sock \
  --group=docker \
  --data-root=/var/lib/docker \
  --exec-root=/run/docker \
  --pidfile=/run/docker.pid \
  --exec-opt native.cgroupdriver=cgroupfs &
dockerd_pid="$!"

attempt=0
while [ "$attempt" -lt 20 ]; do
  if [ -S /var/run/docker.sock ]; then
    chown ${userName}:docker /var/run/docker.sock
    chmod 0660 /var/run/docker.sock
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done

trap 'kill "$dockerd_pid" 2>/dev/null || true; wait "$dockerd_pid" 2>/dev/null || true' INT TERM
wait "$dockerd_pid"
EOF

      cat > ./etc/machine/start-tailscaled.sh <<'EOF'
#!/bin/sh
set -eu

mkdir -p /var/lib/tailscale /run/tailscale

exec /nix/var/nix/profiles/default/bin/tailscaled \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/run/tailscale/tailscaled.sock \
  --tun=userspace-networking
EOF

      cat > ./etc/ssh/sshd_config <<'EOF'
Port 22
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
UsePAM no
UseDNS no
AllowUsers ${userName}
PidFile /run/sshd.pid
SetEnv PATH=/usr/local/bin:/nix/var/nix/profiles/default/bin:/bin:/usr/bin
Subsystem sftp ${pkgs.openssh}/libexec/sftp-server
EOF

      cat > ./etc/machine/start-sshd.sh <<'EOF'
#!/bin/sh
set -eu

user_name="${userName}"
user_id="${uid}"
group_id="${gid}"
home_dir="${homeDir}"
host_home="/Users/${userName}"
host_key_dir="''${host_home}/.local/state/apple-container/ssh/$(hostname)"

mkdir -p /etc/ssh /run /run/sshd "''${home_dir}/.ssh"
chown "''${user_id}:''${group_id}" "''${home_dir}/.ssh"
chmod 0700 "''${home_dir}/.ssh"

authorized_keys_tmp="''${home_dir}/.ssh/authorized_keys.tmp"
rm -f "''${authorized_keys_tmp}"

if [ -s "''${host_home}/.ssh/authorized_keys" ]; then
  cat "''${host_home}/.ssh/authorized_keys" >> "''${authorized_keys_tmp}"
fi

for public_key in "''${host_home}"/.ssh/id_*.pub; do
  if [ -s "''${public_key}" ]; then
    cat "''${public_key}" >> "''${authorized_keys_tmp}"
  fi
done

if [ -s "''${authorized_keys_tmp}" ]; then
  awk '!seen[$0]++' "''${authorized_keys_tmp}" > "''${home_dir}/.ssh/authorized_keys"
  rm -f "''${authorized_keys_tmp}"
  chown "''${user_id}:''${group_id}" "''${home_dir}/.ssh/authorized_keys"
  chmod 0600 "''${home_dir}/.ssh/authorized_keys"
else
  rm -f "''${authorized_keys_tmp}"
fi

if [ -d "''${host_home}" ]; then
  mkdir -p "''${host_key_dir}"
  chmod 0700 "''${host_key_dir}"
fi

for key_type in ed25519 rsa; do
  key_path="/etc/ssh/ssh_host_''${key_type}_key"
  persisted_key_path="''${host_key_dir}/ssh_host_''${key_type}_key"

  if [ -s "''${persisted_key_path}" ]; then
    cp "''${persisted_key_path}" "''${key_path}"
    cp "''${persisted_key_path}.pub" "''${key_path}.pub"
  elif [ "''${key_type}" = ed25519 ]; then
    /nix/var/nix/profiles/default/bin/ssh-keygen -t ed25519 -N "" -f "''${key_path}" >/dev/null
  else
    /nix/var/nix/profiles/default/bin/ssh-keygen -t rsa -b 3072 -N "" -f "''${key_path}" >/dev/null
  fi

  if [ -d "''${host_key_dir}" ] && [ ! -s "''${persisted_key_path}" ]; then
    cp "''${key_path}" "''${persisted_key_path}"
    cp "''${key_path}.pub" "''${persisted_key_path}.pub"
    chmod 0600 "''${persisted_key_path}"
    chmod 0644 "''${persisted_key_path}.pub"
  fi

  chown root:root "''${key_path}" "''${key_path}.pub"
  chmod 0600 "''${key_path}"
  chmod 0644 "''${key_path}.pub"
done

exec /nix/var/nix/profiles/default/bin/sshd -D -e -f /etc/ssh/sshd_config
EOF

      cat > ./etc/machine/create-user.sh <<'EOF'
#!/bin/sh
set -eu
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/nix/var/nix/profiles/default/bin

user_name="''${CONTAINER_USER:-${userName}}"
user_id="''${CONTAINER_UID:-${uid}}"
group_id="''${CONTAINER_GID:-${gid}}"
home_dir="''${CONTAINER_HOME:-${homeDir}}"
shell_path="${loginShell}"

ensure_group() {
  name="$1"
  id="$2"
  if ! grep -q "^''${name}:" /etc/group; then
    printf '%s:x:%s:\n' "''${name}" "''${id}" >> /etc/group
  fi
}

ensure_group_member() {
  group="$1"
  member="$2"
  awk -F: -v OFS=: -v group="''${group}" -v member="''${member}" '
    $1 == group {
      found = 0
      count = split($4, members, ",")
      for (i = 1; i <= count; i++) {
        if (members[i] == member) found = 1
      }
      if (!found) $4 = ($4 == "" ? member : $4 "," member)
    }
    { print }
  ' /etc/group > /etc/group.tmp
  mv /etc/group.tmp /etc/group
}

mkdir -p "$(dirname "''${home_dir}")" "''${home_dir}"

ensure_group "''${user_name}" "''${group_id}"
ensure_group docker ${dockerGid}
ensure_group_member docker "''${user_name}"
ensure_group_member sudo "''${user_name}"

if grep -q "^''${user_name}:" /etc/passwd; then
  awk -F: -v OFS=: -v user="''${user_name}" -v uid="''${user_id}" -v gid="''${group_id}" -v home="''${home_dir}" -v shell="''${shell_path}" \
    '{ if ($1 == user) { $3 = uid; $4 = gid; $6 = home; $7 = shell } print }' /etc/passwd > /etc/passwd.tmp
  mv /etc/passwd.tmp /etc/passwd
else
  printf '%s:x:%s:%s:%s:%s:%s\n' "''${user_name}" "''${user_id}" "''${group_id}" "''${user_name}" "''${home_dir}" "''${shell_path}" >> /etc/passwd
fi

if [ -e /etc/shadow ] && ! grep -q "^''${user_name}:" /etc/shadow; then
  printf '%s:*:19793:0:99999:7:::\n' "''${user_name}" >> /etc/shadow
fi

if [ -e /etc/shells ] && ! grep -Fxq "''${shell_path}" /etc/shells; then
  printf '%s\n' "''${shell_path}" >> /etc/shells
fi

chown "''${user_id}:''${group_id}" "''${home_dir}"
find "''${home_dir}" -type d -exec chown "''${user_id}:''${group_id}" {} +
EOF

      find ${homeFiles} -mindepth 1 \( -type f -o -type l \) -print | while IFS= read -r source; do
        rel="''${source#${homeFiles}/}"
        mkdir -p "./home/${userName}/$(dirname "$rel")"
        ln -s "$source" "./home/${userName}/$rel"
      done

      ln -s ${runtimeProfile} ./nix/var/nix/profiles/default/profile
      mkdir -p ./nix/var/nix/profiles/default/bin
      for source in ${runtimeProfile}/bin/*; do
        name="$(basename "$source")"
        ln -s "$source" "./nix/var/nix/profiles/default/bin/$name"
      done
      ln -s ${runtimeProfile} ./nix/var/nix/profiles/per-user/root/profile
      ln -s ${homePath} ./nix/var/nix/profiles/per-user/${userName}/profile
      ln -s /nix/var/nix/profiles/per-user/${userName}/profile ./home/${userName}/.nix-profile

      for profile in ${runtimeProfile} ${homePath}; do
        for source in "$profile"/bin/*; do
          name="$(basename "$source")"
          [ -e "./usr/local/bin/$name" ] || ln -s "$source" "./usr/local/bin/$name"
        done
      done

      rm -f ./usr/local/bin/sudo
      cp ${pkgs.sudo}/bin/sudo ./usr/local/bin/sudo
      chmod 0755 ./usr/local/bin/sudo
      rm -f ./nix/var/nix/profiles/default/bin/sudo
      ln -s /usr/local/bin/sudo ./nix/var/nix/profiles/default/bin/sudo

      chmod 0755 \
        ./etc/machine/create-user.sh \
        ./etc/machine/start-dockerd.sh \
        ./etc/machine/start-sshd.sh \
        ./etc/machine/start-tailscaled.sh \
        ./root \
        ./home/${userName} \
        ./run
    '';

    fakeRootCommands = ''
      chown root:root ./usr/local/bin/sudo ./etc/shadow
      chmod 4755 ./usr/local/bin/sudo
      chmod 0640 ./etc/shadow
      chown -hR ${uid}:${gid} ./home/${userName} ./nix/var/nix/profiles/per-user/${userName} ./nix/var/nix/gcroots/per-user/${userName}
    '';

    config = {
      User = "${uid}:${gid}";
      WorkingDir = homeDir;
      Env = [
        "HOME=${homeDir}"
        "USER=${userName}"
        "LOGNAME=${userName}"
        "SHELL=${loginShell}"
        "SNOWBEAR_CONTAINER=1"
        "container=container"
        "PATH=/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/nix/var/nix/profiles/default/bin:${homeDir}/.nix-profile/bin"
        "SYSTEMD_UNIT_PATH=/etc/systemd/system:/run/systemd/system:/usr/lib/systemd/system:/lib/systemd/system:/nix/var/nix/profiles/default/lib/systemd/system"
        "NIX_REMOTE=daemon"
        "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
        "LANG=en_US.UTF-8"
        "LC_ALL=en_US.UTF-8"
        "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
      ];
      Cmd = [ "/sbin/init" ];
      StopSignal = "SIGRTMIN+3";
    };
  };
in
pkgs.runCommand "${userName}-container-image-oci.tar"
  {
    nativeBuildInputs = [ pkgs.skopeo ];
    passthru = {
      inherit dockerArchive imageName imageTag homePath runtimeProfile;
    };
  }
  ''
    skopeo --insecure-policy copy \
      docker-archive:${dockerArchive}:${imageName}:${imageTag} \
      oci-archive:$out:${imageName}:${imageTag}
  ''
