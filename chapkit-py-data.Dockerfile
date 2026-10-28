# chapkit-py-data: chapkit-py + the PyData stack that most Python
# chap-models use. Multi-arch (linux/amd64, linux/arm64).
#
# Two build targets, published as:
#
#   - chapkit-py-data     (target: runtime) chapkit-py + the PyData
#                         stack, no chapkit. FROM base for scaffolded
#                         chapkit services that want the stack and pin
#                         their own chapkit via `uv sync`.
#   - chapkit-py-data-cli (target: bundled) runtime + a pinned chapkit
#                         from PyPI. Serves an MLproject directly via
#                         `docker run ... chapkit mlproject run .`, with
#                         no image of its own to build.
#
# Pre-installed Python packages (in /app/.venv, on top of chapkit-py):
#   numpy, pandas, scipy, scikit-learn, statsmodels, joblib, pyyaml,
#   xarray
#
# These are the packages that three or more of the Python chap-models
# import. Model-specific frameworks (torch, tensorflow, pymc, ...) are
# large and used by one or two models each, so they stay out.
#
# A chapkit service that runs `uv sync` into /app/.venv replaces these
# with the versions in its own lock, and removes the ones it does not
# list, so the stack mainly saves time for the -cli image.

# Image to inherit from. Default is the published ghcr release; the
# Makefile overrides this to chapkit-py:dev when building locally.
ARG CHAPKIT_PY_IMAGE=ghcr.io/dhis2-chap/chapkit-py:latest

# ---------- Stage: runtime (no chapkit) ----------
FROM ${CHAPKIT_PY_IMAGE} AS runtime

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --python /app/.venv/bin/python \
        numpy \
        pandas \
        scipy \
        scikit-learn \
        statsmodels \
        joblib \
        pyyaml \
        xarray

# ---------- Stage: bundled (runtime + pinned chapkit) ----------
FROM runtime AS bundled

# Install chapkit into /app/.venv. Two install paths:
#   - default: PyPI release. Set CHAPKIT_VERSION to a PEP 440 version
#     with or without a leading 'v' (e.g. 1.1.0 or v1.1.0).
#   - override: git ref. Set CHAPKIT_GIT_REF to a branch / tag / SHA
#     (e.g. main) to install from
#     git+https://github.com/dhis2-chap/chapkit.git@<ref>. Used by the
#     nightly :dev build to track chapkit's main branch.
ARG CHAPKIT_VERSION=2.5.0
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
