# chapkit-images

Docker image backbone for [`chapkit`](https://github.com/dhis2-chap/chapkit).
Three runtimes — Python, R, and R+INLA — each published in two variants:

- **base** (no suffix) — Python/R + `uv` (and for R, `renv` + `pak`), no
  `chapkit`. Use as a `FROM` base for scaffolded chapkit services that
  pin their own `chapkit` version and install via `uv sync`. This is
  what `chapkit init` generates from.
- **`-cli`** — the base image plus a pinned `chapkit` from PyPI. Use for
  invoking the `chapkit` CLI directly (e.g.
  `docker run -v $PWD:/work ... chapkit mlproject migrate .`) without
  needing a `pyproject.toml` or a `uv sync` step.

Why two variants: a scaffolded project that pins a different `chapkit`
version than a `chapkit`-bundled base takes the "uninstall + reinstall"
path through `uv sync`, which produces a measurably heavier runtime
memory profile than projects that match the bundled version. Keeping the
canonical base image free of `chapkit` makes the install path uniform
regardless of which `chapkit` release the project pins.

Lives in its own repository so the slow multi-arch R + INLA builds do not
block every commit on `chapkit`.

## Images

| Image                                                | Base                                               | Arches                       | ~Size (amd64) |
| ---------------------------------------------------- | -------------------------------------------------- | ---------------------------- | ------------- |
| `ghcr.io/dhis2-chap/chapkit-py:latest`               | `ghcr.io/astral-sh/uv:0.11-python3.13-trixie-slim` | `linux/amd64`, `linux/arm64` | ~420 MB       |
| `ghcr.io/dhis2-chap/chapkit-py-cli:latest`           | `ghcr.io/astral-sh/uv:0.11-python3.13-trixie-slim` | `linux/amd64`, `linux/arm64` | ~570 MB       |
| `ghcr.io/dhis2-chap/chapkit-r:latest`                | `debian:trixie-slim`                               | `linux/amd64`, `linux/arm64` | ~385 MB       |
| `ghcr.io/dhis2-chap/chapkit-r-cli:latest`            | `debian:trixie-slim`                               | `linux/amd64`, `linux/arm64` | ~415 MB       |
| `ghcr.io/dhis2-chap/chapkit-r-tidyverse:latest`      | `chapkit-r:latest`                                 | `linux/amd64`, `linux/arm64` | ~1.77 GB      |
| `ghcr.io/dhis2-chap/chapkit-r-tidyverse-cli:latest`  | `chapkit-r:latest`                                 | `linux/amd64`, `linux/arm64` | ~1.81 GB      |
| `ghcr.io/dhis2-chap/chapkit-r-inla:latest`           | `chapkit-r-tidyverse:latest` (+ INLA build stage)  | `linux/amd64` (INLA x86_64)  | ~2.02 GB      |
| `ghcr.io/dhis2-chap/chapkit-r-inla-cli:latest`       | `chapkit-r-tidyverse:latest` (+ INLA build stage)  | `linux/amd64` (INLA x86_64)  | ~2.05 GB      |

The size delta between each base / `-cli` pair is just the chapkit wheel
and its Python deps (~30–50 MB); the heavy bits (R, INLA, the Python
toolchain, the tidyverse + ML stack) are identical.

Hierarchy: `chapkit-r-tidyverse` FROMs `chapkit-r` and adds the
tidyverse + tidyverts + forecasting + ML primitives bundle (tidyverse,
fable, tsibble, feasts, lubridate, distributional, forecast, urca,
tseries, zoo, xts, readxl, ranger, randomForest, xgboost, glmnet,
e1071, lme4, janitor, here, patchwork). `chapkit-r-inla` FROMs
`chapkit-r-tidyverse` and adds INLA + the spatial/EWARS R stack
(fmesher, INLA, dlnm, sf, spdep, sn, tsModel, jsonlite). Models that
don't need INLA should pull `chapkit-r-tidyverse` to skip the ~250 MB
INLA layer.

Tag conventions:

- `:latest` / `:main` — tip of `main` (chapkit installed from PyPI for `-cli` images)
- `:sha-<short>` — per-commit
- `:<semver>` — on tag pushes (e.g. `:0.19.0`, `:0.19`)
- `:dev` — `-cli` images only; nightly rebuild with `chapkit` installed
  from the `main` branch of `github.com/dhis2-chap/chapkit` instead of
  PyPI. Use this to test against unpublished `chapkit` changes.

## Using chapkit

For how to build and run a chapkit service on top of these images, see the
main chapkit docs:

- [`chapkit` docs](https://dhis2-chap.github.io/chapkit)
- [`chapkit init`](https://dhis2-chap.github.io/chapkit) — scaffold a new chapkit service
- [`chapkit migrate`](https://dhis2-chap.github.io/chapkit) — convert an MLproject into a chapkit service

Both scaffolders generate a `Dockerfile` that `FROM`s the appropriate image
published by this repo.

## CI / publishing

`.github/workflows/docker.yml` builds and publishes all six images (base
+ `-cli`, for each of py / r / r-inla) to `ghcr.io/dhis2-chap/...` from
a single matrix job. Triggers:

- push to `main` — refresh `:latest`
- tag `v*` — publish semver tag
- `schedule` (weekly, Mon 04:17 UTC) — base-image security refresh
- `workflow_dispatch` — manual with `chapkit_version` input (PyPI version, e.g. `0.24.0`; only affects `-cli` images)
- `repository_dispatch` (`event_type: chapkit-release`) — fired by chapkit's release workflow (rebuilds `-cli` images against the released version)

After all six builds succeed, a `smoke` job pulls each `:main` image and
runs `chapkit --help` against the `-cli` tags (plus `library(INLA)` for
`chapkit-r-inla-cli`) and `uv --version` against the base tags, to catch
broken publishes. On scheduled / `workflow_dispatch` runs, a parallel
`build-dev` job rebuilds the three `-cli` images against `chapkit` main
and tags them `:dev`; a corresponding `smoke-dev` job exercises those.

Build cache is pushed to a `:buildcache` tag alongside each image so PR and
main-branch builds share cached layers via the registry.

## Local builds

```bash
make build                              # all six images, default chapkit version
make build-py                           # base Python image only (no chapkit)
make build-py-cli                       # Python image with chapkit pre-installed
make build-r                            # base R, multi-arch
make build-r-cli                        # R with chapkit pre-installed
make build-r-inla                       # base R + INLA, amd64
make build-r-inla-cli                   # R + INLA with chapkit pre-installed
make build-py-cli CHAPKIT_VERSION=0.24.0   # pin a specific PyPI version
```

## Security posture

All images currently run as `root`. Non-root hardening needs the
volume-mapping dance used by
[`chap-core/compose.yml`](https://github.com/dhis2-chap/chap-core/blob/main/compose.yml)
(tmpfs `/tmp`, per-user cache volumes) and is a planned follow-up. Intended
to sit in a trusted compose network behind chap-core.
