# snowbear Nix Config

Personal Nix configuration for macOS, Linux Home Manager, and persistent Apple `container` machines.

## Main Commands

```bash
make switch
make full
make test
make build
make check
```

On macOS these target nix-darwin. On Linux they target Home Manager.

## Apple Container Workflow

The container workflow is persistent by default:

```bash
make container-bootstrap
make container-shell
make container-hm-full
make container-check
```

`container-bootstrap` builds and loads the base image, then creates the `main` machine only if it does not already exist. It does not delete `/home/snowbear`, `apt` installs, systemd unit state, Docker state, or other machine-local state.

`container-hm-full` and `container-hm-switch` first repair the in-machine Nix cache config if needed, then build this flake's Home Manager activation package inside the existing machine. User config updates can apply without resetting the image layer.

The `/Users/snowbear` home mount is subject to macOS privacy prompts. If commands in the machine hang on `Desktop`, `Documents`, or a top-level `ls /Users/snowbear`, grant Full Disk Access to `/usr/local/libexec/container/plugins/container-runtime-linux/bin/container-runtime-linux` or approve the Files and Folders prompt. Mounted repo paths under `WORK` should remain the normal development location.

Use explicit reset only when the base image plumbing changed:

```bash
make container-reset
```

Use separate machines by overriding `NAME`:

```bash
make container-bootstrap NAME=personal
make container-bootstrap NAME=work
```

## Layout

```text
flake.nix          public flake outputs
nix/               overlays and output builders
darwin/            nix-darwin host modules
home/              Home Manager modules and app config
container/         Ubuntu/systemd Apple container image builder
mk/container.mk    Apple container machine targets
.agents/skills/    repo-local agent skills
```

See `AGENTS.md` and `.agents/skills/nix-apple-container` before changing container or Nix workflow code.
