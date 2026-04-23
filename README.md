# chapkit-images

Base Docker images for [`chapkit`](https://github.com/dhis2-chap/chapkit)
services — Python / R / R+INLA runtimes with `chapkit`, `uv`, `renv`, and `pak`
pre-installed. Use them two ways:

1. **Run an MLproject directly** with the built-in
   [`chapkit run`](https://dhis2-chap.github.io/chapkit/guides/mlproject-runner/)
   CMD (mount your MLproject at `/work`).
2. **Build a chapkit service** by `FROM`-ing one of these images in your own
   `Dockerfile` and layering in your `main.py`, `pyproject.toml`, `renv.lock`,
   etc. `chapkit init` and `chapkit migrate` scaffold exactly this layout
   and pick the right base image for your project.

Lives in a separate repository so its long docker builds (multi-arch R
compilation, INLA from CRAN) don't slow down every commit on
[`chapkit`](https://github.com/dhis2-chap/chapkit) itself.

## Published images

| Image                                          | Base                                               | Arches                         | ~Size (amd64, pushed) | Purpose                                                                 |
| ---------------------------------------------- | -------------------------------------------------- | ------------------------------ | --------------------- | ----------------------------------------------------------------------- |
| `ghcr.io/dhis2-chap/chapkit-py:latest`         | `ghcr.io/astral-sh/uv:0.11-python3.13-trixie-slim` | `linux/amd64`, `linux/arm64`   | ~220 MB               | Python chapkit services and Python MLproject models. Lean.              |
| `ghcr.io/dhis2-chap/chapkit-r:latest`          | `debian:trixie-slim`                               | `linux/amd64`, `linux/arm64`   | ~400 MB               | R chapkit services that do not need INLA. R 4.5 + `renv` + `pak`.       |
| `ghcr.io/dhis2-chap/chapkit-r-inla:latest`     | `debian:trixie-slim` (two-stage)                   | `linux/amd64` (INLA x86_64)    | ~570 MB               | R chapkit services that use INLA. Full spatial + time-series R stack.   |

All three set `WORKDIR /work` and default to
`CMD ["chapkit","run",".","--host","0.0.0.0","--port","8000"]`. The default
CMD is handy for the MLproject flow (below); downstream `Dockerfile`s built
on top of these images can override it to run their own entrypoint.

### Run an MLproject directly

Mount your MLproject into `/work` and let the built-in `chapkit run` serve it:

```bash
docker run --rm -p 8000:8000 -v "$(pwd):/work" ghcr.io/dhis2-chap/chapkit-r:latest
```

See the [MLproject Runner guide](https://dhis2-chap.github.io/chapkit/guides/mlproject-runner/)
for the full story (canonical MLproject parameter mapping, dynamic config,
compose integration with chap-core, etc.).

### Use as a base image

`chapkit init` / `chapkit migrate` generate a project skeleton including a
`Dockerfile` that `FROM`s one of these images and layers in your code and
dependencies. Minimal hand-written example:

```dockerfile
FROM ghcr.io/dhis2-chap/chapkit-py:latest
COPY pyproject.toml uv.lock main.py ./
RUN uv pip install --system -e .
CMD ["python", "main.py"]
```

`chapkit`, `uv`, and (for R images) `renv` + `pak` are already on `PATH`.

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
