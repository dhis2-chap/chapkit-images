# chapkit-r: R 4.5 (base) + Python 3.13 + uv + renv/pak. Multi-arch
# (linux/amd64, linux/arm64). Debian trixie ships both R 4.5 and Python
# 3.13 from distro apt; no CRAN apt dance, no Ubuntu PPA.
#
# Two build targets, published as:
#
#   - chapkit-r     (target: runtime) R + uv + renv/pak + an empty
#                   Python 3.13 venv, no chapkit. FROM base for
#                   scaffolded chapkit services that pin their own
#                   chapkit version and install via `uv sync`.
#   - chapkit-r-cli (target: bundled) runtime + a pinned chapkit from
#                   PyPI. For invoking the chapkit CLI directly via
#                   `docker run ... chapkit <subcommand>`.
#
# Scope: R MLprojects that do NOT require INLA. If you need INLA (or
# the spatial/tsModel/dlnm R stack that chap-core EWARS-style models
# use), pull chapkit-r-inla instead.
#
# Security: runs as root. Non-root hardening needs the volume-mapping
# dance from chap-core/compose.yml (tmpfs /tmp, per-user cache volumes)
# and is a deferred follow-up.

# ---------- Stage: runtime (no chapkit) ----------
FROM debian:trixie-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_INSTALL_DIR=/opt/uv-python \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:${PATH}"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl jq git \
        # Full R toolchain so users can install extra CRAN packages / run
        # renv::restore() at container runtime against source tarballs.
        r-base r-base-dev gfortran \
        # Common dev libs for the most frequently-needed R packages (curl,
        # httr, openssl, xml2, jsonlite, ...). Keeps install.packages(...)
        # and renv::restore() working out of the box without extra apt.
        libcurl4-openssl-dev libssl-dev libxml2-dev \
        # Build tools for Python ML wheels that fall through to source.
        build-essential pkg-config \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Pre-install renv + pak so users can restore lockfiles or install extras
# without bootstrapping either from CRAN first.
RUN R -q -e "install.packages(c('renv','pak'), repos='https://cloud.r-project.org')"

COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /uvx /usr/local/bin/

RUN --mount=type=cache,target=/root/.cache/uv \
    uv python install 3.13 \
    && uv venv /app/.venv --python 3.13

WORKDIR /work

EXPOSE 8000

# ---------- Stage: bundled (runtime + pinned chapkit) ----------
FROM runtime AS bundled

# Install chapkit into /app/.venv. Two install paths:
#   - default: PyPI release. Set CHAPKIT_VERSION to a PEP 440 version
#     with or without a leading 'v' (e.g. 0.24.0 or v0.24.0).
#   - override: git ref. Set CHAPKIT_GIT_REF to a branch / tag / SHA
#     (e.g. main) to install from
#     git+https://github.com/dhis2-chap/chapkit.git@<ref>. Used by the
#     nightly :dev build to track chapkit's main branch.
ARG CHAPKIT_VERSION=0.24.0
ARG CHAPKIT_GIT_REF=
RUN --mount=type=cache,target=/root/.cache/uv \
    if [ -n "${CHAPKIT_GIT_REF}" ]; then \
        uv pip install --python /app/.venv/bin/python \
            "git+https://github.com/dhis2-chap/chapkit.git@${CHAPKIT_GIT_REF}"; \
    else \
        uv pip install --python /app/.venv/bin/python \
            "chapkit==${CHAPKIT_VERSION#v}"; \
    fi

HEALTHCHECK CMD curl -fsS http://localhost:8000/health || exit 1

CMD ["chapkit", "run", ".", "--host", "0.0.0.0", "--port", "8000"]
