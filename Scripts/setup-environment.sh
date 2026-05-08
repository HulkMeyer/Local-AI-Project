#!/usr/bin/env bash
# scripts/setup-environment.sh
#
# One-shot host bootstrap for the Local AI Stack.
# Run this INSIDE Ubuntu/WSL2 (not PowerShell). Idempotent — safe to re-run.
#
# Steps:
#   1. NVIDIA Container Toolkit repo + install + Docker runtime config
#   2. zstd (required by the Ollama installer)
#   3. Ollama itself
#   4. Validation: nvidia-smi inside a CUDA container

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[setup]${NC} $*"; }
fail() { echo -e "${RED}[setup]${NC} $*" >&2; exit 1; }

# ---- 0. Sanity checks -------------------------------------------------------

if ! grep -qi microsoft /proc/version 2>/dev/null; then
    warn "Not running under WSL2. Continuing anyway — assuming native Ubuntu host."
fi

if ! command -v docker >/dev/null 2>&1; then
    fail "Docker not found. Install Docker Desktop on Windows and enable WSL2 integration first."
fi

if ! docker info >/dev/null 2>&1; then
    fail "Docker daemon not reachable. Start Docker Desktop, ensure WSL2 integration is enabled, then re-run."
fi

# ---- 1. NVIDIA Container Toolkit -------------------------------------------

if ! dpkg -s nvidia-container-toolkit >/dev/null 2>&1; then
    log "Installing NVIDIA Container Toolkit..."

    # Add the NVIDIA repo with proper GPG keyring (replaces deprecated apt-key)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

    sudo apt-get update -qq
    sudo apt-get install -y nvidia-container-toolkit
else
    log "NVIDIA Container Toolkit already installed — skipping."
fi

log "Configuring Docker to use the NVIDIA runtime..."
sudo nvidia-ctk runtime configure --runtime=docker

# ---- 2. zstd (Ollama installer dependency) ---------------------------------

if ! command -v zstd >/dev/null 2>&1; then
    log "Installing zstd..."
    sudo apt-get install -y zstd
else
    log "zstd already installed — skipping."
fi

# ---- 3. Ollama --------------------------------------------------------------

if ! command -v ollama >/dev/null 2>&1; then
    log "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    log "Ollama already installed — skipping. Current version:"
    ollama --version || true
fi

# ---- 4. Validation ----------------------------------------------------------

cat <<EOF

${GREEN}=================================================================
 Host setup complete.
=================================================================${NC}

Required next step:
  → Right-click the Docker Desktop whale in the Windows system tray
    and select "Restart". This is what makes the NVIDIA runtime config
    take effect for the Docker daemon. The CLI commands above wrote
    to /etc/docker/daemon.json but Docker Desktop runs the actual
    daemon on the Windows side.

After Docker restarts, verify GPU passthrough with:

    docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

You should see your GPU listed with full VRAM. If you see
"could not select device driver", the toolkit didn't take —
check 'docker info | grep -i runtime' and re-run this script.

Then continue with:
    ./scripts/pull-models.sh
    docker compose up -d
EOF