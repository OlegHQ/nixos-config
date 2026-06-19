# Nix And Home Manager Layering

## Layers

The Apple container image has three practical layers:

1. Alpine base and init files from the OCI image.
2. Runtime Nix profile for `nix`, `home-manager`, Docker, Tailscale, fish, and core tools.
3. User Home Manager profile and generated dotfiles for `snowbear`.

Home Manager switches update layer 3 inside an existing machine. They do not update `/etc`, init scripts, or image entrypoint behavior.

The repo's `container-nix-cache` target is a narrow exception: it repairs
`/etc/nix/nix.conf` in old persistent machines so Nix can use binary caches
instead of compiling the toolchain locally.

In persistent machines, build the flake's Home Manager activation package and
run its activation script:

```bash
nix build ".#homeConfigurations.snowbear-full-aarch64.activationPackage" --impure --out-link "$HOME/.cache/snowbear-home-manager/result"
"$HOME/.cache/snowbear-home-manager/result/activate"
```

Do not treat `/usr/local/bin/home-manager` as authoritative for switches in an
existing machine; that path is part of the original image layer.

## Preferred Update Paths

Use Home Manager for:

- shell config and prompt
- user packages
- Neovim/tmux/git config
- XDG config files
- `/home/snowbear/.nix-profile`

Use image rebuild and explicit reset for:

- `/etc/inittab`
- Nix daemon startup
- Docker daemon startup
- Tailscale daemon startup
- `/etc/passwd` and `/etc/group`
- base image environment and entrypoint

Use `apk` inside a long-lived machine for mutable Alpine packages that are not worth modeling in Nix.

## Garbage Collection

After repeated in-machine Home Manager switches:

```bash
nix profile wipe-history --profile "$HOME/.local/state/nix/profiles/home-manager" --older-than "-7 days"
nix-collect-garbage -d
```

Run the GC as root for machine-wide store cleanup.
