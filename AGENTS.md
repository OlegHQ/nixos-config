# AGENTS.md

Guidance for agents working in this repository.

## Use The Local Skill

Use the repo-local skill at `.agents/skills/nix-apple-container` for Nix, Home Manager, nix-darwin, Multipass Ubuntu VMs, Docker-in-VM, Tailscale, bridged networking, and persistent Linux dev-machine work.

Read the skill before changing Multipass or Nix workflow code. Its references capture the non-obvious persistent VM behavior this repo depends on.

## Commands

Host configuration:

- `make switch` - Apply the normal host config.
- `make full` - Apply the full host config.
- `make test` - Dry-run the host config.
- `make build` - Build the host config.
- `make check` - Run `nix flake check --impure`.
- `make prune` - Remove old Nix generations and run store GC.

Multipass VMs on macOS:

- `make multipass-bootstrap` - Create `main` only if missing, set it as the Multipass primary, provision it, sync the repo, and run full Home Manager on first creation.
- `make multipass-up` - Alias for non-destructive bootstrap.
- `make multipass-reset` - Destructively recreate the VM.
- `make multipass-shell` - Open fish in `/home/snowbear`.
- `make multipass-host-shell` - Open fish in the synced repo inside the VM.
- `make multipass-root-shell` - Open root shell for `apt`, `systemctl`, and system work.
- `make multipass-nix-cache` - Normalize in-VM Nix cache config and restart `nix-daemon` if changed.
- `make multipass-hm-switch` - Switch non-full Home Manager inside the existing VM.
- `make multipass-hm-full` - Switch full Home Manager inside the existing VM.
- `make multipass-gc` - Expire Home Manager generations and run root Nix GC inside the VM.
- `make multipass-check` - Smoke-test the persistent VM.
- `make multipass-tailscale-up` - Authenticate or update Tailscale in the VM.
- `make multipass-disk-grow` - Increase the VM disk to `MULTIPASS_DISK`.

Compatibility aliases named `container-*` still point at Multipass targets. They do not call the old CLI or build custom VM images.

Use separate persistent VMs by overriding `NAME`:

```bash
make multipass-bootstrap NAME=personal
make multipass-bootstrap NAME=work
make multipass-shell NAME=work
```

## Architecture

This is a flake-based macOS/Linux user configuration with a persistent Multipass Ubuntu VM workflow.

- `flake.nix` wires public outputs.
- `nix/overlays.nix` defines package overlays.
- `nix/builders.nix` defines nix-darwin and Home Manager builders.
- `darwin/` contains nix-darwin host config.
- `home/` contains cross-platform Home Manager modules.
- `multipass/` contains VM provisioning, Home Manager, check, GC, and Tailscale scripts.
- `mk/multipass.mk` contains Multipass lifecycle targets.

Public outputs to preserve:

- `darwinConfigurations.mac`
- `darwinConfigurations.mac-full`
- `homeConfigurations.snowbear-x86_64`
- `homeConfigurations.snowbear-aarch64`
- `homeConfigurations.snowbear-full-x86_64`
- `homeConfigurations.snowbear-full-aarch64`
- `packages.aarch64-linux.homeManager`

## Persistent Multipass Model

The normal VM workflow is persistent:

1. Create the VM once with `make multipass-bootstrap`.
2. Keep `/home/snowbear`, `/home/snowbear/src/nixos-config`, `/var/lib/docker`, `/var/lib/tailscale`, apt installs, systemd unit state, and mutable rootfs edits inside the VM.
3. Apply user config changes with `make multipass-hm-full`.
4. Use `apt` or `systemctl` inside the VM for mutable Ubuntu packages and services.
5. Use `make multipass-reset` only when a clean VM is desired.

Multipass launches Ubuntu directly; there is no custom OCI image layer to rebuild. Existing VMs do not receive provisioning changes until `make multipass-provision`, `make multipass-hm-full`, or a reset applies them.

Plain `multipass shell` and `multipass shell main` enter through Multipass' default `ubuntu` account, then delegate interactive shells into the `snowbear` Home Manager account in `/home/snowbear`. Keep this handoff working so the raw Multipass CLI feels like the managed VM.

The macOS home directory is not mounted by default. Targets that need repo contents sync a snapshot into `/home/snowbear/src/nixos-config` and run from there. `MULTIPASS_MOUNT_HOME=1` is an explicit opt-in for mounting `/Users/snowbear`.

Multipass is launched with an additional bridged interface by default. Override the bridge with `MULTIPASS_BRIDGE=en1`, or disable it with `MULTIPASS_BRIDGED=0`.

Multipass disks have a configured maximum size. The supported dynamic-storage path is increasing the disk later with `make multipass-disk-grow MULTIPASS_DISK=120G`; disk size cannot be decreased.

Multipass VMs run their own Tailscale nodes with kernel TUN enabled. Use MagicDNS names such as `main` and `work` for cross-device SSH/mosh after `make multipass-tailscale-up`, or pass `MULTIPASS_TAILSCALE_AUTH_KEY=...` during provisioning.

If `MULTIPASS_MOUNT_HOME=1` is enabled, the `/Users/snowbear` mount is still governed by macOS privacy controls. Guest access to protected folders such as `Desktop` and `Documents`, or a top-level `ls /Users/snowbear`, can trigger macOS Files and Folders or Full Disk Access prompts for Multipass.

`make multipass-nix-cache` is the explicit target that updates Nix daemon config under `/etc/nix` in an existing VM.

`make multipass-hm-switch` and `make multipass-hm-full` depend on `multipass-nix-cache`, then build this flake's `homeConfigurations.*.activationPackage` inside the existing VM and run its activation script. That updates user packages/config from the current lockfile.

## Package Management

- macOS system layer: nix-darwin.
- Linux user layer: Home Manager.
- Multipass base/system layer: Ubuntu packages and systemd services.
- Mutable Ubuntu packages and services: `apt` and `systemctl`, usually from `make multipass-root-shell`.

The repo currently tracks nixpkgs, Home Manager, and nix-darwin `26.05`.

## Editing Rules

- Preserve uncommitted user changes.
- Keep feature outputs stable unless the user explicitly asks to remove them.
- Prefer Home Manager modules for user tools and dotfiles.
- Put Multipass operational behavior in `mk/multipass.mk` or `multipass/`.
- Do not make `multipass-up` destructive.
- Use `multipass-reset` for destructive rebuilds.

## Validation

Run the narrowest useful checks first:

```bash
git diff --check
nix flake check --impure
make test
make build
```

For Multipass changes on macOS:

```bash
make multipass-bootstrap
make multipass-check
make multipass-hm-full
make multipass-gc
```
