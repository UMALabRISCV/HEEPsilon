# HEEPsilon Docker Makefile
# Run from HEEPsilon root: make -C util/docker <target>

IMAGE_NAME := heepsilon-dev
CONTAINER_NAME := heepsilon-container
WORKSPACE := /workspace/heepsilon

# Use all available CPUs
CPUS := $(shell nproc)

.PHONY: docker-build docker-run docker-shell docker-clean help

help:
	@echo "HEEPsilon Docker Commands (run from HEEPsilon root):"
	@echo ""
	@echo "  make -C util/docker docker-build  # Build the Docker image (first time)"
	@echo "  make -C util/docker docker-run    # Start container with interactive shell"
	@echo "  make -C util/docker docker-shell  # Attach to running container"
	@echo "  make -C util/docker docker-clean  # Remove container and image"
	@echo ""

# Build the Docker image
docker-build:
	@echo "Building HEEPsilon Docker image..."
	cd ../.. && docker build -t $(IMAGE_NAME) -f util/docker/Dockerfile .

# Run container with HEEPsilon mounted (using all CPUs)
docker-run:
	@docker run -it --rm \
		--name $(CONTAINER_NAME) \
		--cpus=$(CPUS) \
		-v $(shell cd ../.. && pwd):$(WORKSPACE) \
		-w $(WORKSPACE) \
		$(IMAGE_NAME)

# Attach to running container
docker-shell:
	@docker exec -it $(CONTAINER_NAME) /bin/bash -l

# Clean up
docker-clean:
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null
	-docker rmi $(IMAGE_NAME) 2>/dev/null
	@echo "Cleaned up Docker resources"
