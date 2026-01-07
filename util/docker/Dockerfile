# HEEPsilon Docker Environment
#
# Provides a fully configured development environment with:
#   - RISC-V GCC & LLVM toolchains (CORE-V with PULP extensions)
#   - Verilator 5.040 for RTL simulation
#   - Python environment with all dependencies
#
# This image is recommended for macOS (Apple Silicon) users, where native
# Verilator simulation has known compatibility issues.
#
# Build:  make -C util/docker docker-build
# Run:    make -C util/docker docker-run

FROM ghcr.io/x-heep/x-heep/x-heep-toolchain:latest

LABEL org.opencontainers.image.title="HEEPsilon Development Environment"
LABEL org.opencontainers.image.description="HEEPsilon with CGRA support, RISC-V toolchains, and Verilator"
LABEL org.opencontainers.image.source="https://github.com/UMALabRISCV/HEEPsilon"
LABEL org.opencontainers.image.vendor="UMALabRISCV"

# Use bash for RUN commands
SHELL ["/bin/bash", "-c"]

# =============================================================================
# Verilator Installation
# =============================================================================
# The apt package (v5.006) is too old for this project's waiver files.
# We build from source to get v5.040+ which supports required lint codes:
# GENUNNAMED, WIDTHEXPAND, PROCASSINIT, WIDTHTRUNC

ARG VERILATOR_VERSION=5.040

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    bison \
    flex \
    g++ \
    git \
    help2man \
    libelf-dev \
    libfl2 \
    libfl-dev \
    make \
    perl \
    python3 \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build and install Verilator
RUN cd /tmp && \
    git clone --depth 1 --branch v${VERILATOR_VERSION} \
    https://github.com/verilator/verilator.git && \
    cd verilator && \
    autoconf && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/verilator

# Verify installation
RUN verilator --version

# =============================================================================
# Verible Installation
# =============================================================================
# Required by mcu-gen for formatting generated SystemVerilog files

ARG VERIBLE_VERSION=0.0-3644-g6882622d

RUN cd /tmp && \
    curl -Ls -o verible.tar.gz \
    "https://github.com/chipsalliance/verible/releases/download/v${VERIBLE_VERSION}/verible-v${VERIBLE_VERSION}-linux-static-x86_64.tar.gz" && \
    mkdir -p /opt/verible && \
    tar -C /opt/verible -xf verible.tar.gz --strip-components=1 && \
    rm verible.tar.gz

ENV PATH="/opt/verible/bin:${PATH}"

# Verify installation
RUN verible-verilog-format --version

# =============================================================================
# HEEPsilon Environment Setup
# =============================================================================

WORKDIR /workspace/heepsilon

# Configure welcome message and environment
COPY util/docker/motd.sh /etc/profile.d/motd.sh
COPY util/docker/heepsilon-env.sh /etc/profile.d/heepsilon-env.sh
RUN chmod +x /etc/profile.d/*.sh

# Entrypoint for initialization tasks
COPY util/docker/heepsilon-entrypoint.sh /usr/local/bin/heepsilon-entrypoint.sh
RUN chmod +x /usr/local/bin/heepsilon-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/heepsilon-entrypoint.sh"]
CMD ["/bin/bash", "-l"]
