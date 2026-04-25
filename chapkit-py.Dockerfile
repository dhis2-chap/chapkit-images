FROM ghcr.io/astral-sh/uv:0.11-python3.13-trixie-slim

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV PYTHONDONTWRITEBYTECODE=1
ENV PATH="/app/.venv/bin:$PATH"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update && apt install -y --no-install-recommends \
        git curl jq build-essential pkg-config ca-certificates \
    && apt clean && rm -rf /var/lib/apt/lists/*

# Clone chapkit at the requested ref (branch / tag / commit SHA) and
# install its locked dep tree into /app/.venv via uv sync.
ARG CHAPKIT_REPO=https://github.com/dhis2-chap/chapkit.git
ARG CHAPKIT_REF=main

RUN --mount=type=cache,target=/root/.cache/uv \
    git clone --depth 1 --branch "${CHAPKIT_REF}" "${CHAPKIT_REPO}" /src/chapkit \
    && cd /src/chapkit \
    && UV_PROJECT_ENVIRONMENT=/app/.venv uv sync --frozen --no-dev --no-editable \
    && rm -rf /src

# Fail the build if the resolved CHAPKIT_REF installs a chapkit older
# than the minimum version these images target.
ARG CHAPKIT_MIN_VERSION=0.22.0
RUN /app/.venv/bin/python -c "import re, sys; from importlib.metadata import version; v=version('chapkit'); m=re.match(r'^(\d+)\.(\d+)\.(\d+)', v); got=tuple(int(x) for x in m.groups()); mn=tuple(int(x) for x in '${CHAPKIT_MIN_VERSION}'.split('.')); sys.exit(f'chapkit >= ${CHAPKIT_MIN_VERSION} required, got {v}') if got < mn else print(f'chapkit {v} >= ${CHAPKIT_MIN_VERSION}')"

WORKDIR /work

EXPOSE 8000

HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()" || exit 1

CMD ["chapkit", "run", ".", "--host", "0.0.0.0", "--port", "8000"]
