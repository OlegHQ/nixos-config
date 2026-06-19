# Repo Workflow

## Persistent Machine Flow

Normal flow:

```bash
make container-bootstrap
make container-shell
make container-hm-full
make container-check
```

`container-bootstrap` must not delete an existing machine. It builds/loads the image and creates the machine only if missing.

`container-nix-cache` may update `/etc/nix/nix.conf` and restart the persistent
machine. Keep this behavior explicit because it mutates rootfs state without
recreating the image.

Destructive flow:

```bash
make container-reset
```

Use this only when base image plumbing changed or a clean machine is desired.

## Personal And Work Machines

Use `CONTAINER_NAME` to create independent machines from the same base image:

```bash
make container-bootstrap CONTAINER_NAME=snowbear-personal
make container-bootstrap CONTAINER_NAME=snowbear-work
make container-shell CONTAINER_NAME=snowbear-work
```

Avoid adding duplicate Makefile targets for each machine unless behavior differs.

## Important Outputs

Preserve these flake outputs:

- `darwinConfigurations.mac`
- `darwinConfigurations.mac-full`
- `homeConfigurations.snowbear-aarch64`
- `homeConfigurations.snowbear-full-aarch64`
- `packages.aarch64-linux.containerImage`
- `packages.aarch64-linux.homeManager`

Avoid renaming user-facing targets without keeping compatibility aliases.

`container-hm-switch` and `container-hm-full` should run `container-nix-cache`,
then build
`homeConfigurations.*.activationPackage` from this flake and run the activation
script so persistent machines follow the current lockfile instead of whatever
Home Manager launcher was baked into their original image.
