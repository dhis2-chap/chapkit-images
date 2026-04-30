# chapkit-r-tidyverse: chapkit-r + tidyverse + tidyverts forecasting
# stack (fable, tsibble, lubridate, feasts). Multi-arch (linux/amd64,
# linux/arm64).
#
# Two build targets, published as:
#
#   - chapkit-r-tidyverse     (target: runtime) chapkit-r + the modern
#                             Posit/tidy R stack, no chapkit. FROM base
#                             for scaffolded chapkit services that
#                             want tidyverse + forecasting tooling and
#                             pin their own chapkit via `uv sync`.
#   - chapkit-r-tidyverse-cli (target: bundled) runtime + a pinned
#                             chapkit from PyPI. For invoking the
#                             chapkit CLI directly via `docker run ...
#                             chapkit <subcommand>`.
#
# Pre-installed R packages (on top of chapkit-r's renv + pak):
#   tidyverse, fable, tsibble, lubridate, feasts, distributional,
#   urca, tseries
#
# tidyverse adds ~400 MB but it is the de facto data-wrangling stack in
# the R ecosystem (see rocker/tidyverse usage on Docker Hub) and the
# common case for forecasting models. fable + tsibble + feasts are the
# tidyverts forecasting trio; lubridate is core tidyverse but listed
# explicitly for clarity. distributional is the probabilistic-forecast
# helper auto_arima/install_packages.R pins. urca + tseries provide
# stationarity / unit-root tests that fable::ARIMA reaches for via
# Suggests and that the older `forecast` package depends on directly,
# so models using either stack don't need to re-install them.
#
# Sits between chapkit-r (lean base) and chapkit-r-inla (R + INLA + the
# spatial/forecasting R stack). Models that need INLA should pull
# chapkit-r-inla — it inherits this image's tidyverse layer.

# Image to inherit from. Default is the published ghcr release; the
# Makefile overrides this to chapkit-r:dev when building locally.
ARG CHAPKIT_R_IMAGE=ghcr.io/dhis2-chap/chapkit-r:latest

# ---------- Stage: runtime (no chapkit) ----------
FROM ${CHAPKIT_R_IMAGE} AS runtime

# pak is already in chapkit-r and gives us binary builds where
# available (much faster than compiling from source). lubridate is a
# core tidyverse member since v2.0; listed explicitly for clarity.
RUN R -q -e "pak::pkg_install(c( \
        'tidyverse', \
        'fable', \
        'tsibble', \
        'lubridate', \
        'feasts', \
        'distributional', \
        'urca', \
        'tseries' \
    ), upgrade = FALSE)"

# Trim help/docs/html — saves a few hundred MB (tidyverse's manuals
# alone are ~50 MB of HTML).
RUN find /usr/local/lib/R/site-library /usr/lib/R/site-library -type d \
        \( -name help -o -name doc -o -name html \) \
        -exec rm -rf {} + 2>/dev/null || true

# ---------- Stage: bundled (runtime + pinned chapkit) ----------
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
