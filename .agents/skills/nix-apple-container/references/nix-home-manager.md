# Nix And Home Manager Layering

## Layers

The Multipass workflow has three practical layers:

1. Ubuntu base image and systemd services managed by Multipass and `apt`.
2. Nix daemon, Docker, SSH, mosh, Tailscale, and user bootstrap managed by `multipass/scripts/provision.sh`.
3. User Home Manager profile and generated dotfiles for `snowbear`.

Home Manager switches update layer 3 inside an existing VM. They do not replace the Ubuntu image, apt packages, or persistent service state.

The repo's `multipass-nix-cache` target is a narrow exception: it repairs `/etc/nix/nix.conf` in old persistent VMs so Nix can use binary caches instead of compiling the toolchain locally.

In persistent VMs, build the flake's Home Manager activation package and run its activation script:

```bash
nix build ".#homeConfigurations.snowbear-full-aarch64.activationPackage" --impure --out-link "$HOME/.cache/snowbear-home-manager/result"
"$HOME/.cache/snowbear-home-manager/result/activate"
```

## Preferred Update Paths

Use Home Manager for:

- shell config and prompt
- user packages
- Neovim/tmux/git config
- XDG config files
- `/home/snowbear/.nix-profile`

Use `multipass-provision` for:

- Ubuntu packages
- Nix daemon installation
- Docker, SSH, mosh, and Tailscale services
- `/etc/passwd`, `/etc/group`, and sudoers setup

Use `apt` and `systemctl` inside a long-lived VM for mutable Ubuntu packages and services that are not worth modeling in Nix.

## Garbage Collection

After repeated in-VM Home Manager switches:

```bash
nix profile wipe-history --profile "$HOME/.local/state/nix/profiles/home-manager" --older-than "7d"
nix-collect-garbage -d
```

Run the GC as root for machine-wide store cleanup.
