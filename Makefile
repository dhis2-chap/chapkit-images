.PHONY: help build \
        build-py build-py-cli \
        build-r build-r-cli \
        build-r-tidyverse build-r-tidyverse-cli \
        build-r-inla build-r-inla-cli \
        clean

# chapkit version to install from PyPI. Override on the CLI:
#   make build-py-cli CHAPKIT_VERSION=0.23.0
# Accepts the bare PEP 440 version with or without a leading 'v'.
# Only used by the -cli targets; the base targets do not install chapkit.
CHAPKIT_VERSION ?= 0.23.0

help:
	@echo "chapkit-images"
	@echo ""
	@echo "Targets (base = no chapkit; FROM base for scaffolded services):"
	@echo "  build                    Build all base and -cli images (in dependency order)"
	@echo "  build-py                 Build chapkit-py:dev (Python + uv only)"
	@echo "  build-r                  Build chapkit-r:dev (R + uv only)"
	@echo "  build-r-tidyverse        Build chapkit-r-tidyverse:dev (chapkit-r + tidyverse + tidyverts)"
	@echo "  build-r-inla             Build chapkit-r-inla:dev (chapkit-r-tidyverse + INLA + spatial)"
	@echo ""
	@echo "Targets (-cli = pinned chapkit pre-installed; for direct docker run):"
	@echo "  build-py-cli             Build chapkit-py-cli:dev"
	@echo "  build-r-cli              Build chapkit-r-cli:dev"
	@echo "  build-r-tidyverse-cli    Build chapkit-r-tidyverse-cli:dev"
	@echo "  build-r-inla-cli         Build chapkit-r-inla-cli:dev"
	@echo ""
	@echo "  clean                    Remove locally-tagged :dev images"
	@echo ""
	@echo "Variables:"
	@echo "  CHAPKIT_VERSION  chapkit PyPI version for -cli targets. Set with:"
	@echo "                     make build-py-cli CHAPKIT_VERSION=0.23.0"
	@echo ""
	@echo "Image hierarchy (each layer FROM the previous):"
	@echo "  chapkit-py        Python + uv"
	@echo "  chapkit-r         R + Python + uv + renv/pak"
	@echo "  chapkit-r-tidyverse  chapkit-r + tidyverse, fable, tsibble, lubridate, feasts"
	@echo "  chapkit-r-inla    chapkit-r-tidyverse + INLA + sf/spdep/sn/dlnm/tsModel/xgboost"

# Build order matters: chapkit-r-tidyverse FROMs chapkit-r:dev,
# chapkit-r-inla FROMs chapkit-r-tidyverse:dev. The Make dependency
# chain enforces the order so a fresh `make build` works from clean.
build: build-py build-py-cli \
       build-r build-r-cli \
       build-r-tidyverse build-r-tidyverse-cli \
       build-r-inla build-r-inla-cli

# ---------- chapkit-py ----------

build-py:
	@echo ">>> Building chapkit-py:dev (no chapkit)"
	@docker build --target runtime \
		-f chapkit-py.Dockerfile -t chapkit-py:dev .

build-py-cli: build-py
	@echo ">>> Building chapkit-py-cli:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build --target bundled \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-py.Dockerfile -t chapkit-py-cli:dev .

# ---------- chapkit-r ----------

build-r:
	@echo ">>> Building chapkit-r:dev (no chapkit)"
	@docker build --target runtime \
		-f chapkit-r.Dockerfile -t chapkit-r:dev .

build-r-cli: build-r
	@echo ">>> Building chapkit-r-cli:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build --target bundled \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-r.Dockerfile -t chapkit-r-cli:dev .

# ---------- chapkit-r-tidyverse ----------

build-r-tidyverse: build-r
	@echo ">>> Building chapkit-r-tidyverse:dev (no chapkit, FROM chapkit-r:dev)"
	@docker build --target runtime \
		--build-arg CHAPKIT_R_IMAGE=chapkit-r:dev \
		-f chapkit-r-tidyverse.Dockerfile -t chapkit-r-tidyverse:dev .

build-r-tidyverse-cli: build-r-tidyverse
	@echo ">>> Building chapkit-r-tidyverse-cli:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build --target bundled \
		--build-arg CHAPKIT_R_IMAGE=chapkit-r:dev \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-r-tidyverse.Dockerfile -t chapkit-r-tidyverse-cli:dev .

# ---------- chapkit-r-inla ----------

build-r-inla: build-r-tidyverse
	@echo ">>> Building chapkit-r-inla:dev (no chapkit, FROM chapkit-r-tidyverse:dev)"
	@docker build --target runtime --platform=linux/amd64 \
		--build-arg CHAPKIT_R_TIDYVERSE_IMAGE=chapkit-r-tidyverse:dev \
		-f chapkit-r-inla.Dockerfile -t chapkit-r-inla:dev .

build-r-inla-cli: build-r-inla
	@echo ">>> Building chapkit-r-inla-cli:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build --target bundled --platform=linux/amd64 \
		--build-arg CHAPKIT_R_TIDYVERSE_IMAGE=chapkit-r-tidyverse:dev \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-r-inla.Dockerfile -t chapkit-r-inla-cli:dev .

# ---------- clean ----------

clean:
	@docker rmi -f \
		chapkit-py:dev chapkit-py-cli:dev \
		chapkit-r:dev chapkit-r-cli:dev \
		chapkit-r-tidyverse:dev chapkit-r-tidyverse-cli:dev \
		chapkit-r-inla:dev chapkit-r-inla-cli:dev \
		2>/dev/null || true
	@echo "cleaned"
