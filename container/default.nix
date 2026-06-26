{ pkgs
, homeConfiguration
, userName
, uid ? "1000"
, gid ? "1000"
}:

let
  lib = pkgs.lib;
  homeDir = "/home/${userName}";
  loginShell = "${homeDir}/.nix-profile/bin/fish";
  dockerGid = "131";

  imageNameEnv = builtins.getEnv "CONTAINER_IMAGE_NAME";
  imageTagEnv = builtins.getEnv "CONTAINER_IMAGE_TAG";
  imageName = if imageNameEnv == "" then "local/${userName}-dev" else imageNameEnv;
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

  alpineImage = pkgs.dockerTools.pullImage {
    imageName = "alpine";
    imageDigest = "sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4";
    hash = "sha256-NLcY5J9bzq0y+y+mNZOiuWpdoNUUBMJvhkqJFdQIwOE=";
    arch = "arm64";
    finalImageName = "alpine";
    finalImageTag = "latest";
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
    fromImage = alpineImage;
    compressor = "none";
    contents = [ root ];

    extraCommands = ''
      set -eu

      mkdir -p \
        ./etc/machine \
        ./etc/docker \
        ./etc/nix \
        ./etc/pam.d \
        ./etc/ssh \
        ./etc/ssl/certs \
        ./home/${userName} \
        ./nix/var/nix/daemon-socket \
        ./nix/var/nix/gcroots/per-user/${userName} \
        ./nix/var/nix/profiles/default \
        ./nix/var/nix/profiles/per-user/root \
        ./nix/var/nix/profiles/per-user/${userName} \
        ./root \
        ./run \
        ./run/tailscale \
        ./tmp \
        ./usr/local/bin \
        ./var/empty \
        ./var/lib/docker \
        ./var/lib/tailscale \
        ./var/run/docker \
        ./var/run/sshd \
        ./var/run/tailscale \
        ./var/tmp

      chmod 1777 ./tmp ./var/tmp

      cat > ./etc/group <<'EOF'
root:x:0:
${userName}:x:${gid}:
docker:x:${dockerGid}:${userName}
sshd:x:74:
nobody:x:65534:
EOF

      cat > ./etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/sh
${userName}:x:${uid}:${gid}:${userName}:${homeDir}:${loginShell}
sshd:x:74:74:sshd:/var/empty:/sbin/nologin
nobody:x:65534:65534:nobody:/:/sbin/nologin
EOF

      cat > ./etc/shells <<'EOF'
/bin/sh
${loginShell}
EOF

      mkdir -p ./etc/sudoers.d
      cat > ./etc/sudoers <<'EOF'
Defaults env_keep += "LOCALE_ARCHIVE LOCALE_ARCHIVE_* NIX_SSL_CERT_FILE SSL_CERT_FILE"
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

      cat > ./etc/nsswitch.conf <<'EOF'
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
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

      ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ./etc/ssl/certs/ca-certificates.crt

      cat > ./etc/inittab <<'EOF'
::sysinit:/bin/mkdir -p /run /run/tailscale /tmp /var/lib/docker /var/lib/tailscale /var/run/docker /var/run/sshd /var/run/tailscale /var/tmp /nix/var/nix/daemon-socket
::sysinit:/bin/chmod 1777 /tmp /var/tmp
::respawn:/nix/var/nix/profiles/default/bin/nix-daemon --daemon
::respawn:/etc/machine/start-dockerd.sh
::respawn:/etc/machine/start-sshd.sh
::respawn:/etc/machine/start-tailscaled.sh
::respawn:/bin/sh -c 'while :; do /bin/sleep 86400; done'
::shutdown:/bin/true
EOF

      cat > ./etc/machine/start-dockerd.sh <<'EOF'
#!/bin/sh
set -eu

mkdir -p /var/lib/docker /var/run/docker
rm -f /var/run/docker.pid /var/run/docker.sock

/nix/var/nix/profiles/default/bin/dockerd \
  --host=unix:///var/run/docker.sock \
  --group=docker \
  --data-root=/var/lib/docker \
  --exec-root=/var/run/docker \
  --pidfile=/var/run/docker.pid &
dockerd_pid="$!"

attempt=0
while [ "$attempt" -lt 10 ]; do
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

mkdir -p /var/lib/tailscale /var/run/tailscale

exec /nix/var/nix/profiles/default/bin/tailscaled \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock \
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

mkdir -p /etc/ssh /run /var/run/sshd "''${home_dir}/.ssh"
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
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

user_name="''${CONTAINER_USER:-${userName}}"
user_id="''${CONTAINER_UID:-${uid}}"
group_id="''${CONTAINER_GID:-${gid}}"
home_dir="''${CONTAINER_HOME:-${homeDir}}"
shell_path="${loginShell}"

mkdir -p "$(dirname "''${home_dir}")" "''${home_dir}"

if ! grep -q "^''${user_name}:" /etc/group; then
  printf '%s:x:%s:\n' "''${user_name}" "''${group_id}" >> /etc/group
fi

if grep -q '^docker:' /etc/group; then
  awk -F: -v OFS=: -v user="''${user_name}" '
    $1 == "docker" {
      found = 0
      count = split($4, members, ",")
      for (i = 1; i <= count; i++) {
        if (members[i] == user) found = 1
      }
      if (!found) $4 = ($4 == "" ? user : $4 "," user)
    }
    { print }
  ' /etc/group > /etc/group.tmp
  mv /etc/group.tmp /etc/group
fi

if grep -q "^''${user_name}:" /etc/passwd; then
  awk -F: -v OFS=: -v user="''${user_name}" -v uid="''${user_id}" -v gid="''${group_id}" -v home="''${home_dir}" -v shell="''${shell_path}" \
    '{ if ($1 == user) { $3 = uid; $4 = gid; $6 = home; $7 = shell } print }' /etc/passwd > /etc/passwd.tmp
  mv /etc/passwd.tmp /etc/passwd
else
  printf '%s:x:%s:%s:%s:%s:%s\n' "''${user_name}" "''${user_id}" "''${group_id}" "''${user_name}" "''${home_dir}" "''${shell_path}" >> /etc/passwd
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

      chmod 0755 ./etc/machine/create-user.sh ./etc/machine/start-dockerd.sh ./etc/machine/start-sshd.sh ./etc/machine/start-tailscaled.sh ./root ./home/${userName} ./run
    '';

    fakeRootCommands = ''
      chown root:root ./usr/local/bin/sudo
      chmod 4755 ./usr/local/bin/sudo
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
        "PATH=/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/nix/var/nix/profiles/default/bin:${homeDir}/.nix-profile/bin"
        "NIX_REMOTE=daemon"
        "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
        "LANG=en_US.UTF-8"
        "LC_ALL=en_US.UTF-8"
        "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
      ];
      Entrypoint = [ "/sbin/init" ];
      Cmd = [ ];
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
