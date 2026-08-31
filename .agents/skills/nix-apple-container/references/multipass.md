# Multipass Notes

## Local CLI Is Authoritative

Prefer local command help before assuming behavior:

```bash
multipass version
multipass help launch
multipass help mount
multipass help set
multipass networks
```

Use official docs as the source for behavior that may change:

- https://documentation.ubuntu.com/multipass/latest/how-to-guides/manage-instances/create-an-instance/
- https://documentation.ubuntu.com/multipass/latest/how-to-guides/manage-instances/modify-an-instance/
- https://documentation.ubuntu.com/multipass/latest/how-to-guides/manage-instances/add-a-network-to-an-existing-instance/
- https://documentation.ubuntu.com/multipass/latest/explanation/mount/

## VMs Are Persistent

`multipass launch` creates a persistent VM. After creation, it has mutable state. Provisioning script changes do not apply until `make multipass-provision`, `make multipass-hm-switch`, or a reset runs.

State kept until VM deletion:

- `/home/snowbear`
- `/home/snowbear/src/nixos-config`
- `/var/lib/docker`
- `/var/lib/tailscale`
- `apt` installs and systemd unit state
- mutable root filesystem edits

State lost by VM deletion:

- everything not stored inside the VM or re-synced from the host repo

## Shell Entry

`make multipass-bootstrap` sets the bootstrapped VM as `client.primary-name`, so plain `multipass shell` enters it.

Multipass opens shells as the image default user, `ubuntu`. Provisioning keeps that account for Multipass compatibility but prepends an interactive `.bashrc` handoff that execs the `snowbear` Home Manager shell in `/home/snowbear`. Keep non-interactive `multipass exec main -- command` working.

## Mounts

The macOS home directory is not mounted by default. The workflow syncs repo contents into `/home/snowbear/src/nixos-config` before Home Manager switches and checks.

Mounting `/Users/snowbear` is an explicit opt-in:

```bash
make multipass-bootstrap MULTIPASS_MOUNT_HOME=1
```

The default mount type is `classic` for compatibility. Native QEMU mounts can be enabled with `MULTIPASS_MOUNT_TYPE=native`, but they must be configured while the VM is stopped.

Use `/home/snowbear` for Linux VM-local state.

macOS privacy controls still apply to paths reached through an opt-in host mount. Accessing protected folders such as `/Users/snowbear/Desktop` or `/Users/snowbear/Documents` can trigger Files and Folders prompts for Multipass.

## Networking

The workflow launches with an extra bridged interface by default. `MULTIPASS_BRIDGE` can override the detected bridge, and `MULTIPASS_BRIDGED=0` disables the extra interface.

Use Tailscale inside each VM for cross-device SSH/mosh. Authenticate interactively with `make multipass-tailscale-up`, or pass `MULTIPASS_TAILSCALE_AUTH_KEY` during provisioning.

## Storage

Multipass disks have a configured maximum size. The supported dynamic path is increasing the disk later:

```bash
make multipass-disk-grow MULTIPASS_DISK=120G
```

Multipass supports increasing disk size, not decreasing it. If partition growth does not happen automatically, the target runs `growpart` and `resize2fs`.
