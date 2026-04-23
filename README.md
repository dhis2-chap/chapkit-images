# chapkit-images

Docker image backbone for [`chapkit`](https://github.com/dhis2-chap/chapkit).
Three runtimes — Python, R, and R+INLA — each with `chapkit`, `uv`, and (for
R) `renv` + `pak` pre-installed, ready to `FROM` in your chapkit service's
`Dockerfile`.

Lives in its own repository so the slow multi-arch R + INLA builds do not
block every commit on `chapkit`.

## Images

| Image                                      | Base                                               | Arches                       | ~Size (amd64) |
| ------------------------------------------ | -------------------------------------------------- | ---------------------------- | ------------- |
| `ghcr.io/dhis2-chap/chapkit-py:latest`     | `ghcr.io/astral-sh/uv:0.11-python3.13-trixie-slim` | `linux/amd64`, `linux/arm64` | ~220 MB       |
| `ghcr.io/dhis2-chap/chapkit-r:latest`      | `debian:trixie-slim`                               | `linux/amd64`, `linux/arm64` | ~400 MB       |
| `ghcr.io/dhis2-chap/chapkit-r-inla:latest` | `debian:trixie-slim` (two-stage)                   | `linux/amd64` (INLA x86_64)  | ~570 MB       |

Tag conventions:

- `:latest` / `:main` — tip of `main`
- `:sha-<short>` — per-commit
- `:<semver>` — on tag pushes (e.g. `:0.19.0`, `:0.19`)

## Using chapkit

For how to build and run a chapkit service on top of these images, see the
main chapkit docs:

- [`chapkit` docs](https://dhis2-chap.github.io/chapkit)
- [`chapkit init`](https://dhis2-chap.github.io/chapkit) — scaffold a new chapkit service
- [`chapkit migrate`](https://dhis2-chap.github.io/chapkit) — convert an MLproject into a chapkit service

Both scaffolders generate a `Dockerfile` that `FROM`s the appropriate image
published by this repo.

## CI / publishing

`.github/workflows/docker.yml` builds and publishes all three images to
`ghcr.io/dhis2-chap/...`. Triggers:

- push to `main` — refresh `:latest`
- tag `v*` — publish semver tag
- `schedule` (weekly, Mon 04:17 UTC) — base-image security refresh
- `workflow_dispatch` — manual with `chapkit_ref` input
- `repository_dispatch` (`event_type: chapkit-release`) — fired by chapkit's release workflow

After all three builds succeed, a `smoke` job pulls each `:main` image and
runs `chapkit --help` (plus `library(INLA)` for `chapkit-r-inla`) to catch
broken publishes.

Build cache is pushed to a `:buildcache` tag alongside each image so PR and
main-branch builds share cached layers via the registry.

## Local builds

```bash
make build                           # all three, chapkit @ main
make build-py                        # Python only
make build-r                         # R base, multi-arch
make build-r-inla                    # R + INLA, amd64
make build-py CHAPKIT_REF=v0.19.0    # pin a branch, tag, or SHA
```

## Security posture

All three images currently run as `root`. Non-root hardening needs the
volume-mapping dance used by
[`chap-core/compose.yml`](https://github.com/dhis2-chap/chap-core/blob/main/compose.yml)
(tmpfs `/tmp`, per-user cache volumes) and is a planned follow-up. Intended
to sit in a trusted compose network behind chap-core.

## Adapted from

The R + INLA build patterns are adapted from
[`mortenoh/r-docker-images`](https://github.com/mortenoh/r-docker-images),
which proved out the `debian:trixie-slim` + native R 4.5 + INLA-from-CRAN
approach.
