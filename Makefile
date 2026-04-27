.PHONY: help build build-py build-r build-r-inla clean

# chapkit version to install from PyPI. Override on the CLI:
#   make build-py CHAPKIT_VERSION=0.23.0
# Accepts the bare PEP 440 version with or without a leading 'v'.
CHAPKIT_VERSION ?= 0.23.0

help:
	@echo "chapkit-images"
	@echo ""
	@echo "Targets:"
	@echo "  build        Build all three chapkit run base images"
	@echo "  build-py     Build chapkit-py:dev (Python runtime, multi-arch)"
	@echo "  build-r      Build chapkit-r:dev (R base runtime, multi-arch, no INLA)"
	@echo "  build-r-inla Build chapkit-r-inla:dev (R+INLA runtime, amd64)"
	@echo "  clean        Remove locally-tagged :dev images"
	@echo ""
	@echo "Variables:"
	@echo "  CHAPKIT_VERSION  chapkit PyPI version to install. Set with:"
	@echo "                     make build-py CHAPKIT_VERSION=0.23.0"

build: build-py build-r build-r-inla

build-py:
	@echo ">>> Building chapkit-py:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-py.Dockerfile -t chapkit-py:dev .

build-r:
	@echo ">>> Building chapkit-r:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-r.Dockerfile -t chapkit-r:dev .

build-r-inla:
	@echo ">>> Building chapkit-r-inla:dev (chapkit==$(CHAPKIT_VERSION))"
	@docker build --platform=linux/amd64 \
		--build-arg CHAPKIT_VERSION=$(CHAPKIT_VERSION) \
		-f chapkit-r-inla.Dockerfile -t chapkit-r-inla:dev .

clean:
	@docker rmi -f chapkit-py:dev chapkit-r:dev chapkit-r-inla:dev 2>/dev/null || true
	@echo "cleaned"
