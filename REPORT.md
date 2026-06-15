# Container Home Manager Image Report

This report documents the container work added to this repository: what the goal was, what was tried, what broke or became confusing, what was removed, what the final design is, and how to rebuild and verify it.

The short version: the repo now builds an ARM Linux OCI image for Apple `container` machines. The image boots a minimal Linux userspace, includes a Nix store database, runs a Nix daemon, and has the full Home Manager profile for `snowbear` baked into `/home/snowbear`. The final image does not bind-mount the macOS Neovim config. Full Neovim config is provided by the `nvimconf` Home Manager flake module and is generated into the baked Home Manager files.

## Final State

The final full container image is:

```text
local/snowbear-dev:latest
```

The default machine name is:

```text
snowbear-dev
```

The image target is ARM Linux:

```text
aarch64-linux / arm64
```

The image archive path is:

```text
container/snowbear-dev.oci.tar
```

The verified archive size at the end of the work was about:

```text
705M
```

The important success checks at the end were:

```text
arch=aarch64 user=snowbear home=/home/snowbear badge=container
/nix/store/...-home-manager-files/.config/nvim/init.lua
2:theme = "catppuccin_latte"
/usr/local/bin/nvim
/home/snowbear/.config/nvim
1
```

And the normal target passed:

```text
make container-check
```

Output included:

```text
arch=aarch64 user=snowbear home=/home/snowbear
/usr/local/bin/fish
/usr/local/bin/nix
nix (Nix) 2.31.4
/usr/local/bin/home-manager
/usr/local/bin/nvim
/usr/local/bin/tmux
/usr/local/bin/lazygit
users-mounted
```

## Layman Summary

The goal was not just "install some packages in a Linux container." The goal was to take the existing Nix/Home Manager setup and bake it into a Linux VM-like environment that can be started quickly through Apple's `container` tool.

Nix does not install software the same way Ubuntu does. It builds packages into `/nix/store` and then points profiles, config files, and symlinks at those store paths. Home Manager also does not create a normal tarball of a home directory by itself. It creates an activation package and a set of generated files. To make that work inside a container image, the image has to include:

- the Nix store paths for the Home Manager profile,
- the generated Home Manager files,
- the Nix database, so `nix` knows what is installed,
- enough Linux userspace to boot,
- a user account,
- a profile symlink at `/home/snowbear/.nix-profile`,
- a PATH that finds the baked binaries,
- and, for normal Nix commands, a Nix daemon.

That is why this was more complicated than a simple `Dockerfile` with `apt install fish neovim`.

The result is still intentionally small in concept: use Nix to build the closure, assemble an image, load it into Apple `container`, and create a machine from it.

## Why ARM Linux Matters

The host is macOS on Apple Silicon. Apple `container` runs Linux containers/machines through Apple's virtualization stack. That means the image we create must be a Linux image, not a Darwin/macOS output.

The important values are:

```make
CONTAINER_ARCH ?= arm64
CONTAINER_SYSTEM ?= aarch64-linux
```

These live in `Makefile`.

This is why the full image is exposed as:

```nix
packages.aarch64-linux.containerImage
```

The architecture question mattered because Nix flakes can produce many systems:

- `aarch64-darwin`: macOS on Apple Silicon,
- `x86_64-linux`: Intel/AMD Linux,
- `aarch64-linux`: ARM Linux.

For this container, the correct one is `aarch64-linux`.

## Why Build Inside a Linux Builder Container

The host Nix installation is Darwin/macOS. The desired output is an ARM Linux OCI image. Rather than trying to make macOS Nix directly build a Linux container image with all the right Linux tools, the `Makefile` uses Apple's `container run` to start an ARM Linux Nix builder:

```make
CONTAINER_BUILDER_IMAGE ?= nixos/nix:2.24.10
```

The full image target runs:

```make
container run --rm \
  --arch $(CONTAINER_ARCH) \
  --cpus $(CONTAINER_BUILD_CPUS) \
  --memory $(CONTAINER_BUILD_MEMORY) \
  --uid 0 \
  --gid 0 \
  --env NIXPKGS_ALLOW_UNFREE=1 \
  --env CONTAINER_IMAGE_NAME=$(CONTAINER_IMAGE_NAME) \
  --env CONTAINER_IMAGE_TAG=$(CONTAINER_IMAGE_TAG) \
  --env CONTAINER_UID=$(CONTAINER_UID) \
  --env CONTAINER_GID=$(CONTAINER_GID) \
  --volume "$$(pwd)":/src \
  --workdir /src \
  --entrypoint /bin/sh \
  $(CONTAINER_BUILDER_IMAGE) \
  -lc '... nix build ".#packages.$(CONTAINER_SYSTEM).containerImage" ...'
```

In plain English: start Linux, mount this repo at `/src`, build the Linux image inside Linux, copy the produced OCI archive back into the repo, then load it into Apple `container`.

That keeps the platform boundary clean.

## Nix Image Tooling Decision

There was confusion around "nix2docker" or "nix to docker" style tools. The concern was valid: if Nix already knows the package graph, why write a pile of scripts?

The final approach uses Nixpkgs' built-in Docker/OCI tooling:

```nix
pkgs.dockerTools.buildLayeredImageWithNixDb
```

This is the important bit. It creates a container image from Nix store paths and includes the Nix database. That gives us the main thing people want from "Nix to Docker" tools:

- image content comes from Nix derivations,
- layers are based on Nix closures,
- the Nix store is available inside the image,
- Nix can understand the store because the database is present,
- the result is reproducible and pinned by the flake lock.

The image is then converted to an OCI archive with:

```nix
pkgs.skopeo
```

Specifically:

```nix
skopeo --insecure-policy copy \
  docker-archive:${dockerArchive}:${imageName}:${imageTag} \
  oci-archive:$out:${imageName}:${imageTag}
```

Why not add another external nix2docker tool?

Because `dockerTools.buildLayeredImageWithNixDb` already did the useful part without introducing another dependency or another moving piece. The user specifically asked not to over-engineer this, so the final version stays with Nixpkgs primitives.

## Base Image Decision

Early on, Ubuntu was considered because it is familiar and gives a normal Linux environment. The final image uses pinned Alpine instead:

```nix
alpineImage = pkgs.dockerTools.pullImage {
  imageName = "alpine";
  imageDigest = "sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4";
  hash = "sha256-NLcY5J9bzq0y+y+mNZOiuWpdoNUUBMJvhkqJFdQIwOE=";
  arch = "arm64";
  finalImageName = "alpine";
  finalImageTag = "latest";
};
```

The reason is simple: most of the actual tools come from Nix, not from the base distro. Ubuntu would mostly add size and another package manager. Alpine gives enough boot structure for `/sbin/init` and keeps the base minimal.

The image is not an Alpine development environment in spirit. It is a Nix/Home Manager environment sitting on top of a tiny Linux base.

## Minimal Smoke Test First

Before building the real image, a minimal smoke flake was created under:

```text
container/smoke/flake.nix
container/smoke/flake.lock
```

That smoke image uses:

- a test user named `hm`,
- a tiny Home Manager config,
- fish,
- coreutils,
- `hello`,
- a marker file at `~/.hm-smoke`.

The point was to prove the basic image mechanics before spending time building the full Home Manager closure.

The relevant targets are:

```text
make container-smoke-image
make container-smoke-machine
make container-smoke-machine-reset
make container-smoke-up
make container-smoke-shell
make container-smoke-host-shell
make container-smoke-check
make container-smoke-direct-check
```

This was useful because it tested the hard container mechanics with a tiny closure:

- Can Nix build an ARM Linux OCI archive?
- Can Apple `container image load` load it?
- Can `container machine create` boot it?
- Does the user exist?
- Does Home Manager's generated home content appear?
- Does a command in the profile work?

Only after that worked did it make sense to wire the real flake.

## Full Image Implementation

The full image is implemented in:

```text
container/default.nix
```

It receives:

```nix
{ pkgs
, homeConfiguration
, userName
, uid ? "1000"
, gid ? "1000"
}:
```

The important input is `homeConfiguration`. This is the Home Manager configuration produced by the main flake:

```nix
homeConfiguration = mkHome {
  inherit system user;
  full = true;
  extraModules = [ ./container/home.nix ];
};
```

That means the image is not separately configured by hand. It consumes the same Home Manager machinery as the regular Linux outputs, with one container-specific module added.

### Runtime Profile

The image creates a runtime profile:

```nix
runtimeProfile = pkgs.buildEnv {
  name = "${userName}-container-runtime-profile";
  paths = with pkgs; [
    bashInteractive
    cacert
    coreutils
    curl
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
```

This profile is for baseline runtime tools and the Nix daemon. The full user tools come from the Home Manager profile.

### Home Manager Profile

The Home Manager output is captured with:

```nix
homePath = homeConfiguration.config.home.path;
homeFiles = homeConfiguration.config.home-files;
```

In simple terms:

- `homePath` is the installed Home Manager user profile, including programs such as fish, nvim, tmux, lazygit, etc.
- `homeFiles` is the generated set of dotfiles and XDG config files that Home Manager would normally link into the user's home.

The image then creates:

```text
/home/snowbear/.nix-profile -> /nix/var/nix/profiles/per-user/snowbear/profile
```

And:

```text
/nix/var/nix/profiles/per-user/snowbear/profile -> ${homePath}
```

This is what makes `/home/snowbear/.nix-profile/bin/...` work.

### Generated Home Files

The generated Home Manager files are linked into `/home/snowbear` at image build time:

```sh
find ${homeFiles} -mindepth 1 \( -type f -o -type l \) -print | while IFS= read -r source; do
  rel="${source#${homeFiles}/}"
  mkdir -p "./home/${userName}/$(dirname "$rel")"
  ln -s "$source" "./home/${userName}/$rel"
done
```

That is why the final check showed:

```text
/home/snowbear/.config/nvim/init.lua -> /nix/store/...-home-manager-files/.config/nvim/init.lua
```

This is the correct model. The config is not copied from macOS at runtime. It is generated by Home Manager and points into the Nix store.

### Nix Daemon

The image includes `/etc/inittab`:

```text
::sysinit:/bin/mkdir -p /run /run/tailscale /tmp /var/lib/docker /var/lib/tailscale /var/run/docker /var/run/tailscale /var/tmp /nix/var/nix/daemon-socket
::sysinit:/bin/chmod 1777 /tmp /var/tmp
::respawn:/nix/var/nix/profiles/default/bin/nix-daemon --daemon
::respawn:/etc/machine/start-dockerd.sh
::respawn:/etc/machine/start-tailscaled.sh
::respawn:/bin/sh -c 'while :; do /bin/sleep 86400; done'
::shutdown:/bin/true
```

This starts `nix-daemon` when the Apple container machine boots. The image environment sets:

```text
NIX_REMOTE=daemon
```

That makes normal `nix` commands talk to the daemon.

### Nix Configuration

The image writes:

```text
/etc/nix/nix.conf
```

With:

```text
experimental-features = nix-command flakes
build-users-group =
sandbox = false
trusted-users = root snowbear
substituters = https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWkM8wLaM/CDG7M0mVjZ5VkgS8rGs=
```

This keeps Nix usable inside the container without requiring a full NixOS setup.

### Docker Runtime

The container image now includes Docker in the runtime profile. This is not only the Docker client. The image also includes `dockerd` and starts it from Alpine init.

The goal is that the normal `snowbear` user can run:

```sh
docker run ...
```

without `sudo`.

The image does this with three pieces:

- `pkgs.docker` is included in the runtime profile.
- `/etc/group` contains a `docker` group.
- `snowbear` is a member of the `docker` group.

The Docker daemon is started by:

```text
/etc/machine/start-dockerd.sh
```

That script runs:

```sh
dockerd \
  --host=unix:///var/run/docker.sock \
  --group=docker \
  --data-root=/var/lib/docker \
  --exec-root=/var/run/docker \
  --pidfile=/var/run/docker.pid
```

The key flag is:

```text
--group=docker
```

That makes the Docker socket group-owned by `docker`, so the `snowbear` user can talk to the daemon through group membership rather than using `sudo`.

The image creates these Docker runtime directories:

```text
/var/lib/docker
/var/run/docker
```

The normal container check now verifies:

- the user has `docker` group membership,
- `docker` exists,
- the Docker daemon answers `docker version`.

### Tailscale Runtime

The container image now includes Tailscale in the runtime profile:

```nix
pkgs.tailscale
```

The image starts `tailscaled` from:

```text
/etc/machine/start-tailscaled.sh
```

The daemon runs with:

```sh
tailscaled \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock \
  --tun=userspace-networking
```

The state directory is:

```text
/var/lib/tailscale
```

The socket is:

```text
/var/run/tailscale/tailscaled.sock
```

The `--tun=userspace-networking` mode is intentional for this container image because it avoids depending on kernel TUN device behavior in Apple's container VM. It keeps Tailscale usable in the image while keeping the setup simple.

### User and UID/GID

The image creates a `snowbear` user. The UID and GID are passed from the host:

```make
CONTAINER_UID ?= $(shell id -u)
CONTAINER_GID ?= $(shell id -g)
```

On this machine that meant:

```text
uid=501
gid=20
```

The reason is practical: matching host IDs reduces permission weirdness when `/Users/snowbear` is mounted into the Linux machine.

### `/usr/local/bin` Symlinks

The image links binaries from both the runtime profile and the Home Manager profile into:

```text
/usr/local/bin
```

That is why checks show:

```text
/usr/local/bin/fish
/usr/local/bin/nix
/usr/local/bin/home-manager
/usr/local/bin/nvim
/usr/local/bin/tmux
/usr/local/bin/lazygit
```

This makes commands easy to find even before shell initialization finishes.

## Makefile Workflow

The full workflow targets are:

```text
make container-image
make container-machine
make container-machine-reset
make container-up
make container-shell
make container-host-shell
make container-check
make container-direct-check
```

### `make container-image`

Builds the full ARM Linux image in a Linux builder container and loads it:

```text
local/snowbear-dev:latest
```

### `make container-machine-reset`

Stops and removes the old Apple container machine, then recreates it from the loaded image:

```text
snowbear-dev
```

It uses:

```make
container machine create \
  --name $(CONTAINER_NAME) \
  --home-mount $(CONTAINER_HOME_MOUNT) \
  $(CONTAINER_IMAGE)
```

The important default is:

```make
CONTAINER_HOME_MOUNT ?= rw
```

That is what gives access to `/Users/snowbear` inside the machine.

### `make container-up`

Runs both:

```text
make container-image
make container-machine-reset
```

### `make container-shell`

Opens fish in the baked Home Manager home:

```text
/home/snowbear
```

This is the shell to use when you want the contained Linux environment.

### `make container-host-shell`

Opens fish with the working directory set to:

```text
/Users/snowbear
```

This is the shell to use when you want to work directly in the mounted macOS home tree from inside Linux.

### `make container-check`

Checks the main expected tools and confirms the `/Users` mount exists.

## `/Users` Mount Confusion

There was a question about why `/Users/*` did not behave like the existing default `dev` machine.

The key distinction is:

- a raw image created by Nix does not automatically include the host's `/Users`,
- `container run` direct image runs are isolated unless mounts are passed,
- `container machine create --home-mount rw` is what gives an Apple container machine access to the host home,
- `container-shell` intentionally starts in `/home/snowbear`,
- `container-host-shell` intentionally starts in `/Users/snowbear`.

The final `container-check` proved the mount exists:

```text
users-mounted
```

So the final behavior is:

- `/home/snowbear`: baked Home Manager Linux home,
- `/Users/snowbear`: mounted macOS home, available for working on host files.

This split is intentional. It avoids mixing the Linux Home Manager home with the macOS home.

## Container Badge in Fish Prompt

A specific request was to make the prompt visibly say that the shell is inside the container, so the Linux VM shell is not confused with the macOS shell.

The container-specific environment is set in two places:

In the image config:

```text
SNOWBEAR_CONTAINER=1
SNOWBEAR_CONTAINER_LABEL=container
```

And as a Home Manager session variable in:

```text
container/home.nix
```

The fish prompt reads those variables in:

```text
home/shell.nix
```

The relevant logic is:

```fish
if set -q SNOWBEAR_CONTAINER
    set -l container_label container
    set -q SNOWBEAR_CONTAINER_LABEL; and set container_label $SNOWBEAR_CONTAINER_LABEL
    echo -n (set_color -b $ctp_peach black)" $container_label "(set_color normal)" "
end
```

That creates the visible `container` badge.

## Full Neovim Config Problem

At first, the container had Neovim installed, but it did not have the expected full Neovim configuration.

The cause was subtle:

```nix
hmExtras = { full ? false }: [];
```

The flake had a `full` flag, and the full container path set:

```nix
full = true;
```

But `hmExtras` ignored it. So `full = true` did nothing.

Home Manager's basic `programs.neovim.plugins` list in `home/editor.nix` installed plugins, but it did not generate the real full config. That is why Neovim appeared bare or incomplete.

The repo history showed the missing model: `full = true` used to import a separate Neovim config flake called `nvimconf`.

The final fix restored:

```nix
nvimconf = {
  url = "github:OlegHQ/nvim-config?ref=dev";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

And:

```nix
hmExtras = { full ? false }: (if full then [
  inputs.nvimconf.homeManagerModules.default
  {
    programs.nvimconf.enable = true;
    programs.nvimconf.theme = "catppuccin_latte";
    programs.nvimconf.themeMode = "light";
  }
] else []);
```

That means full Home Manager builds now generate:

```text
~/.config/nvim/init.lua
~/.config/nvim/config.toml
~/.config/nvim/languages.toml
~/.config/nvim/themes
~/.config/nvim/pack/plugins/start/autoconf.nvim
~/.config/nvim/pack/plugins/start/themekit.nvim
```

Inside the container these are symlinks into the Home Manager files derivation in `/nix/store`.

## The Host Neovim Config Attempt That Was Removed

There was one wrong turn: trying to make the container point at or bind-mount the host macOS path:

```text
/Users/snowbear/.config/nvim
```

That would have made the container depend on a live macOS dotfile path. It also would have blurred the line between:

- "Home Manager generated this config into the image"
- and "the image reaches out to the host at runtime."

The user correctly called out the issue:

```text
home manager builds its own neovim config we must not point it to mac os .config/nvim right?
```

That was correct. The host-path approach was removed.

The cleanup removed references like:

```text
NVIM_CONFIG_PATH
CONTAINER_BUILDER_NVIM_CONFIG
/nvim-config
/Users/snowbear/.config/nvim
```

The final search confirmed no host Neovim mount or env var remains:

```sh
rg -n "NVIM_CONFIG_PATH|CONTAINER_BUILDER_NVIM|/Users/snowbear/.config/nvim|target=/nvim-config|source=\$\(NVIM_CONFIG_PATH\)" flake.nix Makefile container home
```

It returned no matches.

The only remaining `nvim-config` string is the intended GitHub flake input:

```text
github:OlegHQ/nvim-config?ref=dev
```

That is correct because it is a pinned Nix input, not a runtime host mount.

## Lockfile Changes

The full Neovim config added these flake lock inputs:

```text
nvimconf
nvimconf/autoconf-nvim
nvimconf/themekit-nvim
```

The pinned `nvimconf` revision at the time of this report was:

```text
734e8483018aad4146d77627a7cd2fd486901bee
```

The final image build fetched that pinned input inside the Linux builder. That proves the image is not reading the macOS Neovim folder at build time.

## What Was Complicated

### 1. Home Manager is not a normal home directory copy

Home Manager builds a profile and generated files. It does not simply make a folder that can be copied as-is. The image had to explicitly link `home-files` into `/home/snowbear` and set up the profile symlink.

### 2. Nix needs a database

A container can contain `/nix/store` paths but still have a broken or confused `nix` command if the Nix database is missing. That is why the image uses:

```nix
buildLayeredImageWithNixDb
```

Without the DB, Nix commands inside the image are much less useful.

### 3. Apple `container` machines are not just Docker containers

The workflow has both images and machines:

- `container image load` loads an image,
- `container machine create` creates a VM-like machine from it,
- `container machine run` runs commands in that machine.

Rebuilding the image is not enough. The machine must be recreated to use the new image:

```sh
make container-machine-reset
```

### 4. macOS host vs Linux guest paths

The macOS home is:

```text
/Users/snowbear
```

The Linux user home is:

```text
/home/snowbear
```

The full image intentionally uses `/home/snowbear` for baked Home Manager files. `/Users/snowbear` is a mounted convenience path for host files.

### 5. Fish command parsing through `container machine run`

The user shell is fish. Commands passed through `container machine run --user snowbear -- ...` can be parsed by fish, not POSIX shell, unless forced carefully.

One check initially failed because the command used POSIX syntax:

```sh
${SNOWBEAR_CONTAINER_LABEL:-}
```

Fish rejected that. The check was rerun with fish syntax and passed.

### 6. The `full` flag looked right but did nothing

The container called `mkHome` with:

```nix
full = true;
```

That looked correct. But the actual hook was:

```nix
hmExtras = { full ? false }: [];
```

So full did not add anything. The fix was not in the container image code. The fix was restoring what `full` means in the flake.

### 7. Layered image generation can still be big

Even with a minimal Alpine base, the real Home Manager profile includes development tools, Neovim, language tooling, Nix itself, and their closures. The result was about 705M as an OCI archive.

That is acceptable for the stated goal: quick bootstrap of a clean Linux environment with the shell and app configs baked in.

## Commands That Matter Now

Build and load the full image:

```sh
make container-image
```

Recreate the Apple container machine:

```sh
make container-machine-reset
```

Do both:

```sh
make container-up
```

Open the contained Linux Home Manager shell:

```sh
make container-shell
```

Open a shell in the mounted host home:

```sh
make container-host-shell
```

Run the normal verification:

```sh
make container-check
```

Run direct image verification without a persistent machine:

```sh
make container-direct-check
```

## Exact Verification Performed

### Home Manager full Neovim evaluation

Checked that the full ARM Home Manager config enables `nvimconf`:

```sh
nix eval --impure --extra-experimental-features 'nix-command flakes' \
  .#homeConfigurations.snowbear-full-aarch64.config.programs.nvimconf.enable
```

Result:

```text
true
```

Checked that Home Manager generates the Neovim init target:

```sh
nix eval --impure --raw --extra-experimental-features 'nix-command flakes' \
  '.#homeConfigurations.snowbear-full-aarch64.config.xdg.configFile."nvim/init.lua".target'
```

Result:

```text
.config/nvim/init.lua
```

Checked that generated `config.toml` contains the selected theme:

```sh
nix eval --impure --raw --extra-experimental-features 'nix-command flakes' \
  '.#homeConfigurations.snowbear-full-aarch64.config.xdg.configFile."nvim/config.toml".text' | sed -n '1,25p'
```

Result included:

```text
[editor]
theme = "catppuccin_latte"
```

Checked that the module points at the baked plugin source:

```sh
nix eval --impure --raw --extra-experimental-features 'nix-command flakes' \
  '.#homeConfigurations.snowbear-full-aarch64.config.xdg.configFile."nvim/pack/plugins/start/autoconf.nvim".source'
```

Result was a `/nix/store/...-source` path.

### Full image build

Ran:

```sh
make container-image
```

The build completed and loaded:

```text
local/snowbear-dev:latest
```

### Machine recreation

Ran:

```sh
make container-machine-reset
```

It stopped and removed the old `snowbear-dev` machine, then recreated it from `local/snowbear-dev:latest`.

### Runtime Neovim check

Ran a direct runtime check inside the machine as `snowbear`.

Important output:

```text
arch=aarch64 user=snowbear home=/home/snowbear badge=container
/nix/store/...-home-manager-files/.config/nvim/init.lua
2:theme = "catppuccin_latte"
/usr/local/bin/nvim
/home/snowbear/.config/nvim
1
```

The final `1` means Neovim considered the generated `init.lua` readable.

### Normal container check

Ran:

```sh
make container-check
```

Output included:

```text
arch=aarch64 user=snowbear home=/home/snowbear
/usr/local/bin/fish
/usr/local/bin/nix
nix (Nix) 2.31.4
/usr/local/bin/home-manager
/usr/local/bin/nvim
/usr/local/bin/tmux
/usr/local/bin/lazygit
users-mounted
```

### Flake enumeration

Ran:

```sh
nix flake show --impure --allow-import-from-derivation --extra-experimental-features 'nix-command flakes'
```

It showed:

```text
packages.aarch64-linux.containerImage
packages.aarch64-linux.default
```

### Whitespace and host path checks

Ran:

```sh
git diff --check
```

No output, meaning no whitespace errors.

Ran a host-path cleanup search:

```sh
rg -n "NVIM_CONFIG_PATH|CONTAINER_BUILDER_NVIM|/Users/snowbear/.config/nvim|target=/nvim-config|source=\$\(NVIM_CONFIG_PATH\)" flake.nix Makefile container home
```

No output, meaning the removed host Neovim mount approach is gone.

## Files Added or Changed

### `container/default.nix`

The full container image builder.

It:

- consumes the real Home Manager configuration,
- pulls pinned arm64 Alpine,
- builds a layered image with a Nix DB,
- creates Linux users/groups,
- configures Nix,
- configures init,
- starts `nix-daemon`,
- links Home Manager files into `/home/snowbear`,
- links profiles,
- exposes binaries under `/usr/local/bin`,
- emits an OCI archive via `skopeo`.

### `container/home.nix`

Small container-specific Home Manager module.

It sets:

```nix
SNOWBEAR_CONTAINER = "1";
SNOWBEAR_CONTAINER_LABEL = "container";
```

This is deliberately tiny.

### `container/smoke/flake.nix`

Minimal test image used to prove the mechanism before building the full image.

### `container/smoke/flake.lock`

Lockfile for the smoke image.

### `Makefile`

Adds full and smoke container targets.

Important full targets:

```text
container-image
container-machine
container-machine-reset
container-up
container-shell
container-host-shell
container-check
container-direct-check
```

Important smoke targets:

```text
container-smoke-image
container-smoke-machine
container-smoke-machine-reset
container-smoke-up
container-smoke-shell
container-smoke-host-shell
container-smoke-check
container-smoke-direct-check
```

### `flake.nix`

Adds:

- `nvimconf` input,
- actual `hmExtras` behavior for `full = true`,
- `extraModules` support in `mkHome`,
- `mkContainerImage`,
- `packages.aarch64-linux.containerImage`.

### `flake.lock`

Pins:

- `nvimconf`,
- `autoconf.nvim`,
- `themekit.nvim`.

### `home/shell.nix`

Adds the container badge in the fish prompt when `SNOWBEAR_CONTAINER` is set.

### `home/packages.nix`

Adds build environment variables for the `kp` package:

```sh
export HOME="$TMPDIR"
export XDG_CACHE_HOME="$TMPDIR/.cache"
```

This avoids build-time writes to `/homeless-shelter`.

## Current Git Status at Time of Report

At the end of the work, the relevant status was:

```text
 M .gitignore
 M Makefile
 A container/default.nix
 A container/home.nix
 A container/smoke/flake.lock
 A container/smoke/flake.nix
 M flake.lock
 M flake.nix
 M home/packages.nix
 M home/shell.nix
?? scripts/
```

The untracked `scripts/` directory was not part of this report and was not touched.

## Known Caveats

### The image is not tiny

The image is minimal in architecture, not tiny in bytes. A full Nix/Home Manager development profile with Neovim, Nix, language tooling, and caches has a real closure size.

### Rebuilds can take time

The first full image build fetched hundreds of Nix store paths and built generated wrappers/files. Later builds should be faster if the builder cache can reuse work, but the Apple `container` builder is still separate from the host's normal macOS Nix store.

### Recreating the machine is required

Loading a new image does not mutate an existing machine. Use:

```sh
make container-machine-reset
```

or:

```sh
make container-up
```

### `/home/snowbear` and `/Users/snowbear` are intentionally different

Do not point baked Linux config at `/Users/snowbear` unless the goal is explicitly host-coupled behavior. The clean model is:

- baked Home Manager config in `/home/snowbear`,
- host files mounted at `/Users/snowbear`.

### The full Neovim config is pinned to GitHub

The full config comes from:

```text
github:OlegHQ/nvim-config?ref=dev
```

The lockfile pins the exact revision. Updating that config means updating the flake input:

```sh
nix flake update nvimconf
```

Then rebuild the image.

## Things Not Done on Purpose

### No Dockerfile

A Dockerfile would duplicate package lists and lose the direct Home Manager closure model.

### No Ubuntu base

Ubuntu would be familiar but mostly redundant. The environment is Nix-provided.

### No runtime bind mount for Neovim config

This was attempted briefly and removed. It would make the image depend on macOS dotfiles and would not prove that Home Manager baked the config.

### No extra nix2docker dependency

Nixpkgs `dockerTools.buildLayeredImageWithNixDb` already gives the needed Nix-to-image behavior.

### No broad refactor of the existing Home Manager modules

The container consumes the existing `mkHome` path and adds only one small container module.

## Mental Model Going Forward

Think of the result in three layers:

1. Base Linux boot layer:
   Alpine, `/etc/passwd`, `/etc/group`, `/etc/inittab`, `/tmp`, `/run`, certificates.

2. Nix runtime layer:
   Nix, Nix database, Nix daemon, runtime profile, cache configuration.

3. User Home Manager layer:
   `/home/snowbear/.nix-profile`, generated dotfiles, full Neovim config, fish, tmux, lazygit, shell prompt badge.

When something is missing, ask which layer it belongs to.

Examples:

- `nix` command broken: Nix runtime layer.
- `nvim` missing: Home Manager profile or `/usr/local/bin` link.
- `init.lua` missing: Home Manager generated files, likely `nvimconf` or `full = true`.
- prompt badge missing: container env or `container/home.nix`.
- `/Users/snowbear` missing: Apple machine `--home-mount`.

## Recommended Normal Workflow

After changing Home Manager or container image logic:

```sh
make container-up
make container-check
```

For direct Neovim confidence:

```sh
container machine run -n snowbear-dev --user snowbear -- \
  'cd $HOME; and readlink .config/nvim/init.lua; and nvim --headless +"lua print(vim.fn.stdpath(\"config\")); print(vim.fn.filereadable(vim.fn.stdpath(\"config\") .. \"/init.lua\"))" +qa'
```

Expected important parts:

```text
/nix/store/...-home-manager-files/.config/nvim/init.lua
/home/snowbear/.config/nvim
1
```

For a shell in the clean baked Linux environment:

```sh
make container-shell
```

For a shell that starts in the mounted host home:

```sh
make container-host-shell
```

## Bottom Line

The final implementation is the clean version:

- ARM Linux image,
- built from Nix,
- Home Manager baked in,
- full Neovim config generated by Home Manager,
- no macOS Neovim config bind mount,
- visible fish prompt container badge,
- `/Users/snowbear` mounted for convenience,
- `/home/snowbear` remains the clean Linux Home Manager home.

This should now be a fast bootstrap path for a Linux dev environment that feels like the regular setup without confusing it with the macOS host.
