# snowbear Nix Config

Personal Nix configuration for macOS, Linux Home Manager, and persistent Multipass Ubuntu VMs.

## Main Commands

```bash
make switch
make test
make build
make check
```

On macOS these target nix-darwin. On Linux they target Home Manager.

By default Home Manager installs Neovim and its third-party plugins without
managing `~/.config/nvim`, so that directory can be a user-owned clone of
`nvim-config` with `autoconf.nvim` and `themekit.nvim` as submodules. To have
Home Manager manage the config and both custom plugins immutably, enable it for
the switch:

```bash
make switch WITH_NVIM=1
```

## Multipass Workflow

The VM workflow is persistent by default:

```bash
make multipass-bootstrap
multipass shell
make multipass-shell
make multipass-hm-switch
make multipass-check
```

`multipass-bootstrap` creates the `main` VM only if it does not already exist, makes it the Multipass primary instance, provisions Ubuntu packages, installs Nix, Docker, SSH, mosh, and Tailscale, and runs Home Manager on first creation. It does not delete `/home/snowbear`, `apt` installs, systemd unit state, Docker state, Tailscale state, or other VM-local state.

Plain `multipass shell` and `multipass shell main` start through Multipass' default `ubuntu` account, then delegate interactive shells into the `snowbear` Home Manager account in `/home/snowbear`. For raw `ubuntu` debugging, use `multipass exec main -- env SNOWBEAR_MULTIPASS_NO_DELEGATE=1 bash -li`.

The macOS home directory is not mounted by default. Home Manager switches sync a host repo snapshot into `/home/snowbear/src/nixos-config` and build from that VM-local path. Use `MULTIPASS_MOUNT_HOME=1` only when you explicitly want to mount `/Users/snowbear`.

`multipass-hm-switch` first repairs the in-VM Nix cache config if needed, then builds this flake's Home Manager activation package inside the existing VM. Pass `WITH_NVIM=1` to manage the Neovim config in the VM. User config updates can apply without resetting the VM.

Multipass launches with an additional bridged interface by default. Override the bridge with:

```bash
make multipass-bootstrap MULTIPASS_BRIDGE=en1
```

Tailscale runs inside each VM with kernel TUN. Authenticate interactively:

```bash
make multipass-tailscale-up
```

Or provision with an auth key:

```bash
make multipass-bootstrap MULTIPASS_TAILSCALE_AUTH_KEY=tskey-auth-...
```

After authentication, use the VM's MagicDNS name or Tailscale IP for SSH and mosh:

```bash
ssh snowbear@main
ssh snowbear@work
```

Multipass disk size can be increased later, but not decreased:

```bash
make multipass-disk-grow MULTIPASS_DISK=120G
```

Use explicit reset only when a clean VM is desired:

```bash
make multipass-reset
```

Use separate VMs by overriding `NAME`:

```bash
make multipass-bootstrap NAME=personal
make multipass-bootstrap NAME=work
```

If you opt into `MULTIPASS_MOUNT_HOME=1`, the `/Users/snowbear` mount is subject to macOS privacy prompts. The default no-mount workflow avoids those prompts.

Compatibility `container-*` make targets still exist, but they call Multipass targets and do not use the old CLI.

## Layout

```text
flake.nix          public flake outputs
nix/               overlays and output builders
darwin/            nix-darwin host modules
home/              Home Manager modules and app config
multipass/         Ubuntu VM provisioning and in-VM scripts
mk/multipass.mk    Multipass VM lifecycle targets
.agents/skills/    repo-local agent skills
```

See `AGENTS.md` and `.agents/skills/nix-apple-container` before changing Multipass or Nix workflow code.
