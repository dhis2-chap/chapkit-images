.PHONY: help build \
        build-py build-py-runtime \
        build-r build-r-runtime \
        build-r-inla build-r-inla-runtime \
        clean

# chapkit version to install from PyPI. Override on the CLI:
#   make build-py CHAPKIT_VERSION=0.23.0
# Accepts the bare PEP 440 version with or without a leading 'v'.
# Only used by the bundled targets; runtime targets do not install chapkit.
CHAPKIT_VERSION ?= 0.23.0

help:
	@echo "chapkit-images"
	@echo ""
	@echo "Targets (bundled = pinned chapkit pre-installed):"
	@echo "  build               Build all bundled and runtime images"
	@echo "  build-py            Build chapkit-py:dev (Python + chapkit, multi-arch)"
	@echo "  build-r             Build chapkit-r:dev (R + chapkit, multi-arch, no INLA)"
	@echo "  build-r-inla        Build chapkit-r-inla:dev (R + INLA + chapkit, amd64)"
	@echo ""
	@echo "Targets (runtime = no chapkit; FROM base for scaffolded services):"
	@echo "  build-py-runtime    Build chapkit-py-runtime:dev (Python + uv only)"
	@echo "  build-r-runtime     Build chapkit-r-runtime:dev (R + uv only)"
	@echo "  build-r-inla-runtime Build chapkit-r-inla-runtime:dev (R + INLA + uv only)"
	@echo ""
	@echo "  clean               Remove locally-tagged :dev images"
	@echo ""
	@echo "Variables:"
	@echo "  CHAPKIT_VERSION  chapkit PyPI version for bundled targets. Set with:"
	@echo "                     make build-py CHAPKIT_VERSION=0.23.0"

build: build-py-runtime build-py build-r-runtime build-r build-r-inla-runtime build-r-inla

build-py:
	@echo ">>> Building chapkit-py:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build --target bundled \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-py.Dockerfile -t chapkit-py:dev .

build-py-runtime:
	@echo ">>> Building chapkit-py-runtime:dev (no chapkit)"
	@docker build --target runtime \
		-f chapkit-py.Dockerfile -t chapkit-py-runtime:dev .

build-r:
	@echo ">>> Building chapkit-r:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build --target bundled \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-r.Dockerfile -t chapkit-r:dev .

build-r-runtime:
	@echo ">>> Building chapkit-r-runtime:dev (no chapkit)"
	@docker build --target runtime \
		-f chapkit-r.Dockerfile -t chapkit-r-runtime:dev .

build-r-inla:
	@echo ">>> Building chapkit-r-inla:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build --target bundled --platform=linux/amd64 \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-r-inla.Dockerfile -t chapkit-r-inla:dev .

build-r-inla-runtime:
	@echo ">>> Building chapkit-r-inla-runtime:dev (no chapkit)"
	@docker build --target runtime --platform=linux/amd64 \
		-f chapkit-r-inla.Dockerfile -t chapkit-r-inla-runtime:dev .

clean:
	@docker rmi -f \
		chapkit-py:dev chapkit-py-runtime:dev \
		chapkit-r:dev chapkit-r-runtime:dev \
		chapkit-r-inla:dev chapkit-r-inla-runtime:dev \
		2>/dev/null || true
	@echo "cleaned"
