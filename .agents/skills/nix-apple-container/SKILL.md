---
name: nix-apple-container
description: Maintain this repo's Nix, Home Manager, nix-darwin, and Apple container machine workflow. Use when changing container image code, Makefile container targets, persistent Apple container machines, Alpine apk usage, Docker/Tailscale/Nix daemon behavior inside the container, or docs for this repo's containerized Linux dev environment.
---

# Nix Apple Container

Use this skill when working on the Apple `container` Linux machine support in this repo. Preserve the split between immutable base-image plumbing and mutable persistent machine state.

## Workflow

1. Read `AGENTS.md` first for current commands and repo layout.
2. Read the relevant reference:
   - `references/repo-workflow.md` for Makefile targets and expected flows.
   - `references/apple-container.md` for Apple `container` gotchas.
   - `references/nix-home-manager.md` for Nix/Home Manager layering.
3. Check local truth before changing behavior:
   - `container machine create --help`
   - `container run --help`
   - `nix flake show --impure`
   - `make help`
4. Preserve persistent-machine semantics unless explicitly asked otherwise.

## Guardrails

- Do not make `container-up` destructive.
- Use `container-reset` for delete/recreate behavior.
- Do not assume rebuilt images update existing machines.
- Keep `container-nix-cache` as the explicit place for `/etc/nix` cache repair
  in old persistent machines.
- Run in-machine Home Manager switches by building
  `homeConfigurations.*.activationPackage` from this flake and executing its
  activation script.
- Do not depend on a persistent machine's baked `/usr/local/bin/home-manager`
  for switches.
- Do not put macOS-only paths into generated Linux home files unless they are under the mounted `/Users` home.
- Prefer Home Manager for user tools and dotfiles.
- Use `apk` only for mutable Alpine packages inside a long-lived machine.
- Keep Docker socket access working for both `--user snowbear` and `--user 501:20`.
- Keep `SNOWBEAR_CONTAINER=1`; do not reintroduce a fixed prompt label.

## Validation

Run checks appropriate to the changed layer:

```bash
git diff --check
nix flake check --impure
make test
make build
```

For Apple container changes:

```bash
make container-image
make container-direct-check
make container-bootstrap
make container-check
```

For Home Manager changes inside an existing machine:

```bash
make container-hm-full
make container-gc
```
