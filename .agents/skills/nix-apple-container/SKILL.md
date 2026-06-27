---
name: nix-multipass
description: Maintain this repo's Nix, Home Manager, nix-darwin, and Multipass Ubuntu VM workflow. Use when changing Multipass Makefile targets, persistent Ubuntu/systemd VMs, Docker/Nix daemon behavior inside the VM, Tailscale, bridged networking, or docs for this repo's Linux dev environment.
---

# Nix Multipass

Use this skill when working on the Multipass Linux VM support in this repo. Preserve the split between mutable Ubuntu/systemd VM state and Home Manager user state.

## Workflow

1. Read `AGENTS.md` first for current commands and repo layout.
2. Read the relevant reference:
   - `references/repo-workflow.md` for Makefile targets and expected flows.
   - `references/multipass.md` for Multipass gotchas.
   - `references/nix-home-manager.md` for Nix/Home Manager layering.
3. Check local truth before changing behavior:
   - `multipass version`
   - `multipass help launch`
   - `multipass help mount`
   - `multipass networks`
   - `nix flake show --impure`
   - `make help`
4. Preserve persistent-VM semantics unless explicitly asked otherwise.

## Guardrails

- Do not make `multipass-up` destructive.
- Use `multipass-reset` for delete/recreate behavior.
- Keep `multipass-nix-cache` as the explicit place for `/etc/nix` cache repair in existing VMs.
- Run in-VM Home Manager switches by building `homeConfigurations.*.activationPackage` from this flake and executing its activation script.
- Do not put macOS-only paths into generated Linux home files unless they are under the mounted `/Users` home.
- Prefer Home Manager for user tools and dotfiles.
- Use `apt` and `systemctl` for mutable Ubuntu packages and services inside a long-lived VM.
- Keep Docker socket access working for the `snowbear` user through the `docker` group.
- Keep `SNOWBEAR_MULTIPASS=1`; do not reintroduce old VM markers.

## Validation

Run checks appropriate to the changed layer:

```bash
git diff --check
nix flake check --impure
make test
make build
```

For Multipass changes:

```bash
make multipass-bootstrap
make multipass-check
```

For Home Manager changes inside an existing VM:

```bash
make multipass-hm-full
make multipass-gc
```
