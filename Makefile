.PHONY: help build build-py build-r build-r-inla clean

# Chapkit ref to clone/install inside each image. Override on the CLI:
#   make build-py CHAPKIT_REF=v0.19.0
#   make build-py CHAPKIT_REF=my-feature-branch
CHAPKIT_REF ?= main
CHAPKIT_REPO ?= https://github.com/dhis2-chap/chapkit.git

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
	@echo "  CHAPKIT_REF  Git ref to install (default: main). Set with:"
	@echo "                 make build-py CHAPKIT_REF=v0.19.0"
	@echo "  CHAPKIT_REPO Git URL (default: https://github.com/dhis2-chap/chapkit.git)"

build: build-py build-r build-r-inla

build-py:
	@echo ">>> Building chapkit-py:dev (ref=$(CHAPKIT_REF))"
	@docker build \
		--build-arg CHAPKIT_REPO=$(CHAPKIT_REPO) \
		--build-arg CHAPKIT_REF=$(CHAPKIT_REF) \
		-f chapkit-py.Dockerfile -t chapkit-py:dev .

build-r:
	@echo ">>> Building chapkit-r:dev (ref=$(CHAPKIT_REF))"
	@docker build \
		--build-arg CHAPKIT_REPO=$(CHAPKIT_REPO) \
		--build-arg CHAPKIT_REF=$(CHAPKIT_REF) \
		-f chapkit-r.Dockerfile -t chapkit-r:dev .

build-r-inla:
	@echo ">>> Building chapkit-r-inla:dev (ref=$(CHAPKIT_REF))"
	@docker build --platform=linux/amd64 \
		--build-arg CHAPKIT_REPO=$(CHAPKIT_REPO) \
		--build-arg CHAPKIT_REF=$(CHAPKIT_REF) \
		-f chapkit-r-inla.Dockerfile -t chapkit-r-inla:dev .

clean:
	@docker rmi -f chapkit-py:dev chapkit-r:dev chapkit-r-inla:dev 2>/dev/null || true
	@echo "cleaned"
