# chapkit-r: R 4.5 (base) + Python 3.13 + chapkit + uv.
# Multi-arch (linux/amd64, linux/arm64). Debian trixie ships both R 4.5
# and Python 3.13 from distro apt; no CRAN apt dance, no Ubuntu PPA.
#
# Scope: R MLprojects that do NOT require INLA. If you need INLA (or the
# spatial/tsModel/dlnm R stack that chap-core EWARS-style models use),
# pull chapkit-r-inla instead.
#
# Security: runs as root. Non-root hardening needs the volume-mapping
# dance from chap-core/compose.yml (tmpfs /tmp, per-user cache volumes)
# and is a deferred follow-up.

FROM debian:trixie-slim

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
        ca-certificates git curl jq \
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

# Clone chapkit at the requested ref (branch / tag / commit SHA) and
# install its locked dep tree into /app/.venv via uv sync.
ARG CHAPKIT_REPO=https://github.com/dhis2-chap/chapkit.git
ARG CHAPKIT_REF=main

RUN --mount=type=cache,target=/root/.cache/uv \
    git clone --depth 1 --branch "${CHAPKIT_REF}" "${CHAPKIT_REPO}" /src/chapkit \
    && cd /src/chapkit \
    && uv python install 3.13 \
    && UV_PROJECT_ENVIRONMENT=/app/.venv uv sync --frozen --no-dev --no-editable \
    && rm -rf /src

# Fail the build if the resolved CHAPKIT_REF installs a chapkit older
# than the minimum version these images target.
ARG CHAPKIT_MIN_VERSION=0.20.0
RUN /app/.venv/bin/python -c "import re, sys; from importlib.metadata import version; v=version('chapkit'); m=re.match(r'^(\d+)\.(\d+)\.(\d+)', v); got=tuple(int(x) for x in m.groups()); mn=tuple(int(x) for x in '${CHAPKIT_MIN_VERSION}'.split('.')); sys.exit(f'chapkit >= ${CHAPKIT_MIN_VERSION} required, got {v}') if got < mn else print(f'chapkit {v} >= ${CHAPKIT_MIN_VERSION}')"

WORKDIR /work

EXPOSE 8000

HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()" || exit 1

CMD ["chapkit", "run", ".", "--host", "0.0.0.0", "--port", "8000"]
