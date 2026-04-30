# chapkit-r-inla: R 4.5 + tidyverse + INLA + spatial/time-series R
# stack + Python 3.13 + uv. amd64 only (INLA ships x86_64 Linux
# binaries only).
#
# Three build stages:
#   1. inla-builder: full toolchain on debian:trixie-slim, compiles
#      INLA + the spatial/EWARS R packages against CRAN and the INLA
#      binary repo, then strips debug symbols and removes help/docs
#      from the compiled site-library.
#   2. runtime: FROM chapkit-r-tidyverse (so we inherit r-base, uv,
#      Python 3.13 venv, tidyverse, fable, tsibble, lubridate, feasts).
#      Adds spatial dev libs (libgdal/libgeos/libproj/libudunits/libgsl)
#      that the copied INLA site-library links against, then merges the
#      site-library from inla-builder via `cp -rn` (chapkit-r-tidyverse
#      packages win on overlap). No chapkit.
#   3. bundled: runtime + a pinned chapkit from PyPI.
#
# Published as:
#
#   - chapkit-r-inla     (target: runtime) FROM base for scaffolded
#                        chapkit services that pin their own chapkit
#                        version and install via `uv sync`.
#   - chapkit-r-inla-cli (target: bundled) runtime + a pinned chapkit
#                        from PyPI. For invoking the chapkit CLI
#                        directly via `docker run ... chapkit
#                        <subcommand>`.
#
# Pre-installed R packages (in addition to chapkit-r-tidyverse's
# tidyverse + tidyverts + ML stack):
#   fmesher, INLA, dlnm, sf, spdep, sn, tsModel, jsonlite
#   (yaml, dplyr, readr, xgboost already covered by chapkit-r-tidyverse)
#
# Security: runs as root. Non-root hardening needs the volume-mapping
# dance from chap-core/compose.yml and is a deferred follow-up.

ARG BASE_PLATFORM=linux/amd64
# Image to inherit runtime from. Default is the published ghcr
# release; the Makefile overrides this to chapkit-r-tidyverse:dev when
# building locally.
ARG CHAPKIT_R_TIDYVERSE_IMAGE=ghcr.io/dhis2-chap/chapkit-r-tidyverse:latest

#############################
# Stage 1: build INLA + R packages
#############################
FROM --platform=${BASE_PLATFORM} debian:trixie-slim AS inla-builder

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        r-base r-base-dev \
        build-essential gfortran cmake \
        libcurl4-openssl-dev libssl-dev libxml2-dev \
        libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
        libgsl-dev libfontconfig1-dev \
    && rm -rf /var/lib/apt/lists/*

# fmesher first (dependency for modern INLA), then INLA itself with
# dep=FALSE (avoid the huge Suggests chain), then the chap-core parity
# R package set. Final inla.prune() drops INLA examples/documentation.
#
# tidyverse + tidyverts come from the chapkit-r-tidyverse base layer in
# the runtime stage — no need to re-install them here.
RUN R -q -e "install.packages('fmesher', \
        repos = c('https://cloud.r-project.org', INLA = 'https://inla.r-inla-download.org/R/stable'))" \
    && R -q -e "install.packages('INLA', \
        repos = c('https://cloud.r-project.org', INLA = 'https://inla.r-inla-download.org/R/stable'), \
        dep = FALSE)" \
    && R -q -e "install.packages(c('dlnm','jsonlite','sf','spdep','sn','tsModel'), \
        repos='https://cloud.r-project.org')" \
    && R -q -e "library(INLA); INLA::inla.prune()"

# Strip debug symbols + drop help/docs to shrink the site-library.
RUN find /usr/local/lib/R/site-library -name "*.so" -exec strip --strip-debug {} \; 2>/dev/null || true \
    && find /usr/local/lib/R/site-library -type d \( -name help -o -name doc -o -name html \) -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/local/lib/R/site-library -name "*.pdf" -delete 2>/dev/null || true

#############################
# Stage 2: runtime (no chapkit)
#############################
FROM --platform=${BASE_PLATFORM} ${CHAPKIT_R_TIDYVERSE_IMAGE} AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Spatial / GSL / fontconfig dev libs that the INLA site-library links
# against. Dev headers are kept (not just runtime libs) so users can
# install.packages() additional spatial packages at runtime against
# matching versions.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
        libgsl-dev libfontconfig1-dev \
    && rm -rf /var/lib/apt/lists/*

# Merge INLA site-library on top of the inherited tidyverse one.
# `cp -rn` is no-clobber: chapkit-r-tidyverse's packages win on
# overlap (e.g. dplyr, readr) so we don't accidentally downgrade.
COPY --from=inla-builder /usr/local/lib/R/site-library /tmp/inla-site-library
RUN cp -rn /tmp/inla-site-library/. /usr/local/lib/R/site-library/ \
    && rm -rf /tmp/inla-site-library

WORKDIR /work

EXPOSE 8000

#############################
# Stage 3: bundled (runtime + pinned chapkit)
#############################
FROM runtime AS bundled

# Install chapkit into /app/.venv. Two install paths:
#   - default: PyPI release. Set CHAPKIT_VERSION to a PEP 440 version
#     with or without a leading 'v' (e.g. 0.23.0 or v0.23.0).
#   - override: git ref. Set CHAPKIT_GIT_REF to a branch / tag / SHA
#     (e.g. main) to install from
#     git+https://github.com/dhis2-chap/chapkit.git@<ref>. Used by the
#     nightly :dev build to track chapkit's main branch.
ARG CHAPKIT_VERSION=0.23.0
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
