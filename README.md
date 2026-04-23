# chapkit-images

Docker images for running [`chapkit run`](https://github.com/dhis2-chap/chapkit)
against MLflow-style `MLproject` directories. Lives in a separate repository so
its long docker builds (multi-arch R compilation, INLA from CRAN) don't slow
down every commit on [`chapkit`](https://github.com/dhis2-chap/chapkit) itself.

## Published images

| Image                                          | Base                                               | Arches                         | ~Size (amd64, pushed) | Purpose                                                                 |
| ---------------------------------------------- | -------------------------------------------------- | ------------------------------ | --------------------- | ----------------------------------------------------------------------- |
| `ghcr.io/dhis2-chap/chapkit-py:latest`         | `ghcr.io/astral-sh/uv:0.11-python3.13-trixie-slim` | `linux/amd64`, `linux/arm64`   | ~220 MB               | Python MLproject models. Lean.                                          |
| `ghcr.io/dhis2-chap/chapkit-r:latest`          | `debian:trixie-slim`                               | `linux/amd64`, `linux/arm64`   | ~400 MB               | R MLproject models that do not need INLA. R 4.5 + `renv` + `pak`.       |
| `ghcr.io/dhis2-chap/chapkit-r-inla:latest`     | `debian:trixie-slim` (two-stage)                   | `linux/amd64` (INLA x86_64)    | ~570 MB               | R MLproject models that use INLA. Full spatial + time-series R stack.   |

All three set `WORKDIR /work` and default to
`CMD ["chapkit","run",".","--host","0.0.0.0","--port","8000"]`, so mounting
your MLproject into `/work` is enough:

```bash
docker run --rm -p 8000:8000 -v "$(pwd):/work" ghcr.io/dhis2-chap/chapkit-r:latest
```

See the [MLproject Runner guide](https://dhis2-chap.github.io/chapkit/guides/mlproject-runner/)
for the full story (canonical MLproject parameter mapping, dynamic config,
compose integration with chap-core, etc.).

## Local builds

The Dockerfiles clone [`chapkit`](https://github.com/dhis2-chap/chapkit) at a
git ref (`CHAPKIT_REF`) and install its locked dep tree with `uv sync --frozen`.

```bash
make build                       # build all three, chapkit @ main
make build-py                    # Python image only
make build-r                     # R base image only (multi-arch)
make build-r-inla                # R + INLA image only (amd64)

# Install a specific chapkit ref (branch, tag, or commit SHA):
make build-py CHAPKIT_REF=v0.19.0
make build-py CHAPKIT_REF=my-feature-branch
```

## CI / publishing

`.github/workflows/docker.yml` builds and publishes all three images to
`ghcr.io/dhis2-chap/...`. Triggers:

- **push to `main`**: republishes `:latest` (for Dockerfile / workflow changes here).
- **tag `v*`**: publishes the semver tag.
- **schedule** (weekly, Mon 04:17 UTC): picks up security fixes in the Debian /
  uv base images.
- **workflow_dispatch**: manual trigger; takes a `chapkit_ref` input
  (branch / tag / SHA; defaults to `main`).
- **repository_dispatch** (`event_type: chapkit-release`): the chapkit repo's
  release workflow can fire this to rebuild images against the released version
  by sending `client_payload: { ref: "v0.19.0" }`.

Build cache is pushed to a `:buildcache` tag alongside each image so PR builds
and main-branch builds share cached layers via the registry.

## Security posture

All three images currently run as `root`. Non-root hardening needs the
volume-mapping dance used by [`chap-core/compose.yml`](https://github.com/dhis2-chap/chap-core/blob/main/compose.yml)
(tmpfs `/tmp`, per-user cache volumes for `/data/uv`, `/data/renv`,
`/data/logs`, etc.) and is a planned follow-up. Intended to sit in a trusted
compose network behind chap-core.

## Adapted from

The R + INLA build patterns are adapted from
[`mortenoh/r-docker-images`](https://github.com/mortenoh/r-docker-images),
which proved out the `debian:trixie-slim` + native R 4.5 + INLA-from-CRAN
approach.
