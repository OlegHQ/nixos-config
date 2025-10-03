# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` – root outputs, overlays, and system targets.
- `darwin/` – macOS config (`system.nix`, `account.nix`).
- `home/` – Home Manager (`default.nix`, `helix.nix`, `nvim.nix`, `configs/`).
- `Makefile` – common build/test/switch targets.

Keep macOS-specific logic in `darwin/` and cross‑platform or user‑level config in `home/`. Add new app/editor modules as `home/<name>.nix` and wire them in via `home/default.nix`.

## Build, Test, and Development Commands
- `make switch` – apply config. On macOS builds `.#darwinConfigurations.${NIXNAME}.system` then switches; on Linux switches Home Manager for `.#${USER}-${ARCH}`.
- `make test` – dry‑run build (no changes applied).
- `make build` – build only, no switch.
- `make check` – run `nix flake check`.
- `make clean` – remove `result` symlink.

Examples:
- macOS: `NIXNAME=mac make switch`
- Linux x86_64: `nix run nixpkgs#home-manager -- switch --flake .#snowbear-x86_64`

## Coding Style & Naming Conventions
- Nix: 2‑space indent, trailing semicolons, lower‑case file names (`default.nix`, `system.nix`).
- Keep modules small and composable; avoid host‑specific logic in `home/`.
- Prefer existing patterns for overlays and inputs in `flake.nix`.
- No repo‑wide formatter is enforced; match existing style.

## Testing Guidelines
- Always run `make test` and `make check` before PRs.
- If touching shared modules, validate both outputs:
  - macOS: `nix build .#darwinConfigurations.mac.system --dry-run`
  - Linux: `nix run nixpkgs#home-manager -- build --flake .#snowbear-${ARCH} --dry-run`
- After merge locally, `make switch` to verify runtime behavior.

## Commit & Pull Request Guidelines
- Use clear, imperative messages; optional scope prefix helps: `home: add tmux plugin`, `darwin: update defaults`.
- Keep changes focused and minimal; avoid unrelated refactors.
- PRs should include: what/why, affected outputs (darwin/home), sample command output (build/test), and any caveats.

## Security & Configuration Tips
- Don’t commit secrets. Store machine‑local overrides outside the repo.
- When adding new systems, mirror the `mac` pattern in `flake.nix` and reference via `NIXNAME`.

## Agent‑Specific Instructions
- Scope: entire repo. Follow file layout above.
- Do not rename files or move modules unless required.
- Match existing style; keep diffs minimal; update docs only when behavior changes.
- Validate with `make test`/`make check`; prefer non‑destructive changes.

