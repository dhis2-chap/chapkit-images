# chapkit-py: Python 3.13 + uv. Two build targets, published as:
#
#   - chapkit-py     (target: runtime) Python 3.13 + uv, no chapkit.
#                    FROM base for scaffolded chapkit services that
#                    pin their own chapkit version and install via
#                    `uv sync`.
#   - chapkit-py-cli (target: bundled) runtime + a pinned chapkit from
#                    PyPI. For invoking the chapkit CLI directly via
#                    `docker run ... chapkit <subcommand>` without
#                    needing a pyproject.toml or `uv sync` step.
#
# Multi-arch (linux/amd64, linux/arm64).

# ---------- Stage: runtime (no chapkit) ----------
FROM ghcr.io/astral-sh/uv:0.11-python3.13-trixie-slim AS runtime

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV PYTHONDONTWRITEBYTECODE=1
ENV PATH="/app/.venv/bin:$PATH"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update && apt install -y --no-install-recommends \
        curl jq ca-certificates \
    && apt clean && rm -rf /var/lib/apt/lists/*

RUN --mount=type=cache,target=/root/.cache/uv \
    uv venv /app/.venv

WORKDIR /work

EXPOSE 8000

# ---------- Stage: bundled (runtime + pinned chapkit) ----------
FROM runtime AS bundled

# Install chapkit from PyPI into /app/.venv. Accepts a PEP 440 version
# with or without a leading 'v' (e.g. 0.23.0 or v0.23.0).
ARG CHAPKIT_VERSION=0.23.0
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --python /app/.venv/bin/python "chapkit==${CHAPKIT_VERSION#v}"

HEALTHCHECK CMD curl -fsS http://localhost:8000/health || exit 1

CMD ["chapkit", "run", ".", "--host", "0.0.0.0", "--port", "8000"]
