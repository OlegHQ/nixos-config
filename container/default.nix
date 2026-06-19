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
      nix
      openssh
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
        ./var/lib/docker \
        ./var/lib/tailscale \
        ./var/run/docker \
        ./var/run/tailscale \
        ./var/tmp

      chmod 1777 ./tmp ./var/tmp

      cat > ./etc/group <<'EOF'
root:x:0:
${userName}:x:${gid}:
docker:x:${dockerGid}:${userName}
nobody:x:65534:
EOF

      cat > ./etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/sh
${userName}:x:${uid}:${gid}:${userName}:${homeDir}:${loginShell}
nobody:x:65534:65534:nobody:/:/sbin/nologin
EOF

      cat > ./etc/shells <<'EOF'
/bin/sh
${loginShell}
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
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWkM8wLaM/CDG7M0mVjZ5VkgS8rGs=
require-sigs = false
EOF

      ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ./etc/ssl/certs/ca-certificates.crt

      cat > ./etc/inittab <<'EOF'
::sysinit:/bin/mkdir -p /run /run/tailscale /tmp /var/lib/docker /var/lib/tailscale /var/run/docker /var/run/tailscale /var/tmp /nix/var/nix/daemon-socket
::sysinit:/bin/chmod 1777 /tmp /var/tmp
::respawn:/nix/var/nix/profiles/default/bin/nix-daemon --daemon
::respawn:/etc/machine/start-dockerd.sh
::respawn:/etc/machine/start-tailscaled.sh
::respawn:/bin/sh -c 'while :; do /bin/sleep 86400; done'
::shutdown:/bin/true
EOF

      cat > ./etc/machine/start-dockerd.sh <<'EOF'
#!/bin/sh
set -eu

mkdir -p /var/lib/docker /var/run/docker
rm -f /var/run/docker.pid

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
      ln -s ${runtimeProfile}/bin ./nix/var/nix/profiles/default/bin
      ln -s ${runtimeProfile} ./nix/var/nix/profiles/per-user/root/profile
      ln -s ${homePath} ./nix/var/nix/profiles/per-user/${userName}/profile
      ln -s /nix/var/nix/profiles/per-user/${userName}/profile ./home/${userName}/.nix-profile

      for profile in ${runtimeProfile} ${homePath}; do
        for source in "$profile"/bin/*; do
          name="$(basename "$source")"
          [ -e "./usr/local/bin/$name" ] || ln -s "$source" "./usr/local/bin/$name"
        done
      done

      chmod 0755 ./etc/machine/create-user.sh ./etc/machine/start-dockerd.sh ./etc/machine/start-tailscaled.sh ./root ./home/${userName} ./run
    '';

    fakeRootCommands = ''
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
