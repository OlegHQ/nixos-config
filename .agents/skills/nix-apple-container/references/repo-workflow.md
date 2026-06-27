# Repo Workflow

## Persistent VM Flow

Normal flow:

```bash
make multipass-bootstrap
multipass shell
make multipass-shell
make multipass-hm-full
make multipass-check
```

`multipass-bootstrap` must not delete an existing VM. It creates the VM only if missing, makes it the Multipass primary instance, provisions system packages and services, syncs the repo into `/home/snowbear/src/nixos-config`, and runs full Home Manager on first creation.

Plain `multipass shell` and `multipass shell main` must land in the `snowbear` Home Manager account. Multipass starts the session as `ubuntu`, so provisioning installs an interactive shell handoff from `ubuntu` to `snowbear`.

Multipass VMs run their own Tailscale nodes with kernel TUN enabled. Use MagicDNS names such as `main` and `work` for cross-device SSH/mosh. Host subnet routing is not part of the normal flow.

`multipass-nix-cache` may update `/etc/nix/nix.conf` and restart `nix-daemon` in the persistent VM. Keep this behavior explicit because it mutates rootfs state without recreating the VM.

The macOS home directory is not mounted by default. Targets that need repo contents sync a host snapshot into `/home/snowbear/src/nixos-config`. Keep mounting behind the explicit `MULTIPASS_MOUNT_HOME=1` opt-in.

Destructive flow:

```bash
make multipass-reset
```

Use this only when a clean VM is desired.

## Personal And Work VMs

Use `NAME` to create independent VMs from the same provisioning flow:

```bash
make multipass-bootstrap NAME=personal
make multipass-bootstrap NAME=work
make multipass-shell NAME=work
```

Avoid adding duplicate Makefile targets for each VM unless behavior differs.

## Important Outputs

Preserve these flake outputs:

- `darwinConfigurations.mac`
- `darwinConfigurations.mac-full`
- `homeConfigurations.snowbear-aarch64`
- `homeConfigurations.snowbear-full-aarch64`
- `packages.aarch64-linux.homeManager`

Avoid renaming user-facing targets without keeping compatibility aliases.

`multipass-hm-switch` and `multipass-hm-full` should run `multipass-nix-cache`, then build `homeConfigurations.*.activationPackage` from this flake and run the activation script so persistent VMs follow the current lockfile.
