# AGENTS.md

Guidance for agents working in this repository.

## Use The Local Skill

Use the repo-local skill at `.agents/skills/nix-apple-container` for Nix, Home Manager, nix-darwin, Apple `container`, Ubuntu/systemd container machines, Docker-in-container, Tailscale, and persistent container-machine work.

Read the skill before changing container or Nix workflow code. Its references capture the non-obvious Apple `container` behavior this repo depends on.

## Commands

Host configuration:

- `make switch` - Apply the normal host config.
- `make full` - Apply the full host config.
- `make test` - Dry-run the host config.
- `make build` - Build the host config.
- `make check` - Run `nix flake check --impure`.
- `make prune` - Remove old Nix generations and run store GC.

Apple container machines on macOS:

- `make container-image` - Build and load `local/snowbear-main:latest`.
- `make container-bootstrap` - Build image and create `main` only if missing.
- `make container-up` - Alias for non-destructive bootstrap.
- `make container-reset` - Destructively recreate the machine from the image.
- `make container-rebuild` - Alias for destructive rebuild; override `NAME` for machine name.
- `make container-shell` - Open fish in `/home/snowbear`.
- `make container-host-shell` - Open fish in mounted `/Users/snowbear`.
- `make container-root-shell` - Open root shell for `apt`, `systemctl`, and system work.
- `make container-nix-cache` - Normalize in-machine Nix cache config and restart if changed.
- `make container-hm-switch` - Switch non-full Home Manager inside the existing machine.
- `make container-hm-full` - Switch full Home Manager inside the existing machine.
- `make container-gc` - Expire Home Manager generations and run root Nix GC inside the machine.
- `make container-check` - Smoke-test the persistent machine.
- `make container-direct-check` - Smoke-test the loaded image without a machine.

Use separate persistent machines by overriding `NAME`:

```bash
make container-bootstrap NAME=personal
make container-bootstrap NAME=work
make container-shell NAME=work
```

## Architecture

This is a flake-based macOS/Linux user configuration with an Apple `container` machine image.

- `flake.nix` wires public outputs.
- `nix/overlays.nix` defines package overlays.
- `nix/builders.nix` defines nix-darwin, Home Manager, and container-image builders.
- `darwin/` contains nix-darwin host config.
- `home/` contains cross-platform Home Manager modules.
- `container/` builds the Ubuntu/systemd-based Apple container image with Nix, Home Manager, Docker, and Tailscale.
- `mk/container.mk` contains Apple container lifecycle targets.

Public outputs to preserve:

- `darwinConfigurations.mac`
- `darwinConfigurations.mac-full`
- `homeConfigurations.snowbear-x86_64`
- `homeConfigurations.snowbear-aarch64`
- `homeConfigurations.snowbear-full-x86_64`
- `homeConfigurations.snowbear-full-aarch64`
- `packages.aarch64-linux.containerImage`
- `packages.aarch64-linux.homeManager`

## Persistent Container Model

The normal container workflow is persistent:

1. Build/load the base image with `make container-image`.
2. Create the machine once with `make container-create` or `make container-bootstrap`.
3. Apply user config changes with `make container-hm-full`.
4. Use `apt` or `systemctl` inside the machine for mutable Ubuntu packages and services.
5. Use `make container-reset` only when replacing base image boot/runtime plumbing.

Existing machines do not receive rebuilt image layers. Rebuilding the image only affects newly created or reset machines.

Persistent machine state includes `/home/snowbear`, `apt` installs, systemd unit state, `/var/lib/docker`, Tailscale state, and mutable rootfs edits. `container-reset` deletes that state.

The `/Users/snowbear` home mount is still governed by macOS TCC. Guest access to protected folders such as `Desktop` and `Documents`, or a top-level `ls /Users/snowbear`, can hang `virtiofs` until `/usr/local/libexec/container/plugins/container-runtime-linux/bin/container-runtime-linux` is granted Full Disk Access or the specific Files and Folders prompt is approved. Prefer mounted repo paths under `/Users/snowbear/WORK/...` for development.

`make container-nix-cache` is the only target that intentionally updates Nix daemon config under `/etc/nix` in an existing machine. It keeps old persistent machines from source-building when the daemon lacks the current cache settings.

`make container-hm-switch` and `make container-hm-full` depend on `container-nix-cache`, then build this flake's `homeConfigurations.*.activationPackage` inside the existing machine and run its activation script. That updates user packages/config from the current lockfile without depending on the baked `/usr/local/bin/home-manager` launcher.

## Package Management

- macOS system layer: nix-darwin.
- Linux user layer: Home Manager.
- Container base/user layer: Home Manager inside a long-lived Ubuntu/systemd machine.
- Mutable Ubuntu packages and services: `apt` and `systemctl`, usually from `make container-root-shell`.

The repo currently tracks nixpkgs, Home Manager, and nix-darwin `26.05`.

## Editing Rules

- Preserve uncommitted user changes.
- Keep feature outputs stable unless the user explicitly asks to remove them.
- Prefer Home Manager modules for user tools and dotfiles.
- Put Apple container operational behavior in `mk/container.mk` or `container/`.
- Do not make `container-up` destructive.
- Use `container-reset` for destructive rebuilds.

## Validation

Run the narrowest useful checks first:

```bash
git diff --check
nix flake check --impure
make test
make build
```

For container changes on macOS:

```bash
make container-image
make container-direct-check
make container-bootstrap
make container-check
make container-hm-full
make container-gc
```
