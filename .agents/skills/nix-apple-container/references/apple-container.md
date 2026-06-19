# Apple Container Notes

## Local CLI Is Authoritative

Apple `container` behavior is still moving. Prefer local command help before assuming Docker-compatible behavior:

```bash
container --help
container machine --help
container machine create --help
container run --help
container volume --help
```

Use official docs only as a secondary source:

- https://github.com/apple/container
- https://github.com/apple/container/blob/main/docs/command-reference.md

## Machines Are Not Docker Containers

`container machine create` creates a VM-like machine from an image. After creation, it has mutable persistent state. Rebuilding or reloading an image tag does not patch existing machines.

State kept until machine deletion:

- `/home/snowbear`
- `/var/lib/docker`
- `apk` installs
- Tailscale state
- mutable root filesystem edits

State lost by machine deletion:

- everything not stored under host-mounted `/Users/...`

## Mounts

`container machine create` exposes `--home-mount ro|rw|none`. It does not expose the arbitrary `--mount` and named-volume interface available on `container run`.

Use mounted `/Users/snowbear/...` for host-backed repo and project files. Use `/home/snowbear` for Linux VM-local state.

## User And Docker Socket Gotcha

`container machine run --user snowbear` includes supplementary groups. `--user 501:20` does not. The Docker socket must be accessible by ownership as well as group:

```text
/var/run/docker.sock -> snowbear:docker 0660
```

Keep the startup wrapper logic that fixes socket ownership after `dockerd` creates the socket.
