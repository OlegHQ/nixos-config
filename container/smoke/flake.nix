{
  description = "Minimal Home Manager image for Apple container machine smoke tests";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      systems = [ "aarch64-linux" ];

      mkImage = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          userName = "hm";
          uid = "1000";
          gid = "1000";
          homeDir = "/home/${userName}";
          loginShell = "${homeDir}/.nix-profile/bin/fish";

          imageNameEnv = builtins.getEnv "SMOKE_CONTAINER_IMAGE_NAME";
          imageTagEnv = builtins.getEnv "SMOKE_CONTAINER_IMAGE_TAG";
          imageName = if imageNameEnv == "" then "local/hm-smoke" else imageNameEnv;
          imageTag = if imageTagEnv == "" then "latest" else imageTagEnv;

          homeConfiguration = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              {
                home.username = userName;
                home.homeDirectory = homeDir;
                home.stateVersion = "25.11";

                programs.home-manager.enable = true;
                programs.fish = {
                  enable = true;
                  shellAliases.ll = "ls -la";
                  interactiveShellInit = ''
                    set -g fish_greeting "hm smoke ready"
                  '';
                };

                home.packages = with pkgs; [
                  coreutils
                  fish
                  hello
                ];

                home.file.".hm-smoke".text = ''
                  home-manager smoke image
                '';
              }
            ];
          };

          homePath = homeConfiguration.config.home.path;
          homeFiles = homeConfiguration.config.home-files;
          homePathRef = pkgs.writeTextDir "share/hm-smoke-home-path-reference" ''
            ${homePath}
          '';
          homeFilesRef = pkgs.writeTextDir "share/hm-smoke-home-files-reference" ''
            ${homeFiles}
          '';
          localeRef = pkgs.writeTextDir "share/hm-smoke-locale-reference" ''
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
            name = "hm-smoke-nix-closure-root";
            paths = [
              homePathRef
              homeFilesRef
              localeRef
            ];
            pathsToLink = [
              "/share"
            ];
            ignoreCollisions = true;
          };

          dockerArchive = pkgs.dockerTools.buildImageWithNixDb {
            name = imageName;
            tag = imageTag;
            fromImage = alpineImage;
            fromImageName = "alpine";
            fromImageTag = "latest";
            compressor = "none";
            copyToRoot = root;

            extraCommands = ''
              set -eu

              mkdir -p \
                ./etc/machine \
                ./home/${userName} \
                ./nix/var/nix/profiles/per-user/${userName} \
                ./root \
                ./run \
                ./tmp \
                ./var/tmp

              chmod 1777 ./tmp ./var/tmp

              rm -f ./etc/machine/create-user.sh

              cat > ./etc/group <<'EOF'
root:x:0:
${userName}:x:${gid}:
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

              cat > ./etc/inittab <<'EOF'
::sysinit:/bin/mkdir -p /run /tmp /var/tmp
::sysinit:/bin/chmod 1777 /tmp /var/tmp
::respawn:/bin/sh -c 'while :; do /bin/sleep 86400; done'
::shutdown:/bin/true
EOF

              cat > ./etc/machine/create-user.sh <<'EOF'
#!/bin/sh
set -eux
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

user_name="''${CONTAINER_USER:-snowbear}"
user_id="''${CONTAINER_UID:-1000}"
group_id="''${CONTAINER_GID:-1000}"
home_dir="''${CONTAINER_HOME:-/home/''${user_name}}"

mkdir -p "$(dirname "''${home_dir}")" "''${home_dir}"

if ! grep -q "^''${user_name}:" /etc/group; then
  printf '%s:x:%s:\n' "''${user_name}" "''${group_id}" >> /etc/group
fi

if ! grep -q "^''${user_name}:" /etc/passwd; then
  printf '%s:x:%s:%s:%s:%s:/bin/sh\n' "''${user_name}" "''${user_id}" "''${group_id}" "''${user_name}" "''${home_dir}" >> /etc/passwd
fi
EOF

              find ${homeFiles} -mindepth 1 \( -type f -o -type l \) -print | while IFS= read -r source; do
                rel="''${source#${homeFiles}/}"
                mkdir -p "./home/${userName}/$(dirname "$rel")"
                ln -s "$source" "./home/${userName}/$rel"
              done

              ln -s ${homePath} ./nix/var/nix/profiles/per-user/${userName}/profile
              ln -s /nix/var/nix/profiles/per-user/${userName}/profile ./home/${userName}/.nix-profile
              mkdir -p ./usr/local/bin
              for source in ${homePath}/bin/*; do
                name="$(basename "$source")"
                [ -e "./usr/local/bin/$name" ] || ln -s "$source" "./usr/local/bin/$name"
              done

              chmod 0755 ./etc/machine/create-user.sh
              chmod 0755 ./root ./home/${userName} ./run
            '';

            config = {
              User = "0:0";
              WorkingDir = "/";
              Env = [
                "HOME=${homeDir}"
                "USER=${userName}"
                "LOGNAME=${userName}"
                "LANG=en_US.UTF-8"
                "LC_ALL=en_US.UTF-8"
                "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
              ];
              Entrypoint = [ "/sbin/init" ];
              Cmd = [ ];
            };
          };
        in
        pkgs.runCommand "hm-smoke-container-image-oci.tar"
          {
            nativeBuildInputs = [ pkgs.skopeo ];
            passthru = {
              inherit dockerArchive imageName imageTag;
            };
          }
          ''
            skopeo --insecure-policy copy \
              docker-archive:${dockerArchive}:${imageName}:${imageTag} \
              oci-archive:$out:${imageName}:${imageTag}
          '';
    in
    {
      packages = nixpkgs.lib.genAttrs systems (system:
        let image = mkImage system;
        in {
          containerImage = image;
          default = image;
        });
    };
}
