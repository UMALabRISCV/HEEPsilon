# HEEPsilon Docker Environment
#
# Based on x-heep toolchain image, adds HEEPsilon-specific setup
#
# Usage (from HEEPsilon root):
#   make -C util/docker docker-build   # Build the image (first time only)
#   make -C util/docker docker-run     # Run interactive shell with HEEPsilon mounted

FROM ghcr.io/x-heep/x-heep/x-heep-toolchain:latest

LABEL org.opencontainers.image.description="HEEPsilon development environment with CGRA support"
LABEL org.opencontainers.image.source="https://github.com/UMALabRISCV/HEEPsilon"

# Set the build-time shell to bash
SHELL ["/bin/bash", "-c"]

# Update PATH for HEEPsilon workspace
WORKDIR /workspace/heepsilon

# Overwrite x-heep motd.sh with empty one (HEEPsilon has its own welcome message)
COPY util/docker/motd.sh /etc/profile.d/motd.sh
RUN chmod +x /etc/profile.d/motd.sh

# Copy HEEPsilon-specific environment setup
COPY util/docker/heepsilon-env.sh /etc/profile.d/heepsilon-env.sh
RUN chmod +x /etc/profile.d/heepsilon-env.sh

# Pre-generate submodules update script (runs at container start if needed)
COPY util/docker/heepsilon-entrypoint.sh /usr/local/bin/heepsilon-entrypoint.sh
RUN chmod +x /usr/local/bin/heepsilon-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/heepsilon-entrypoint.sh"]
CMD ["/bin/bash", "-l"]
