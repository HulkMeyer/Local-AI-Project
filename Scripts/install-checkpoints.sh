#!/usr/bin/env bash
# scripts/install-checkpoint.sh
#
# Install a Stable Diffusion checkpoint or LoRA into the sd-models Docker volume.
# This script encodes three things that broke the first time around:
#
#   1. The target subfolder must be lowercase `stable-diffusion/` or `Lora/`.
#      The vladmandic/SD.Next backend silently ignores files in the wrong case.
#   2. The container user needs read access — set 0644 on the file, 0755 on dirs.
#   3. After copying, the SD API needs an explicit /sdapi/v1/refresh-checkpoints
#      ping (or rescan via the UI) or the new file won't appear in the dropdown.
#
# Usage:
#   ./scripts/install-checkpoint.sh <path-to-file>
#   ./scripts/install-checkpoint.sh <path-to-file> --type lora
#   ./scripts/install-checkpoint.sh <path-to-file> --type vae

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[install]${NC} $*"; }
warn() { echo -e "${YELLOW}[install]${NC} $*"; }
fail() { echo -e "${RED}[install]${NC} $*" >&2; exit 1; }

# ---- arg parsing ------------------------------------------------------------

if [ $# -lt 1 ]; then
    cat <<EOF
Usage: $0 <path-to-file> [--type checkpoint|lora|vae]

Examples:
  $0 ~/Downloads/AnyLoRA_bakedVae_blessed_fp16.safetensors
  $0 ~/Downloads/coloring_book_lineart.safetensors --type lora
EOF
    exit 1
fi

SRC="$1"
TYPE="checkpoint"

shift
while [ $# -gt 0 ]; do
    case "$1" in
        --type) TYPE="$2"; shift 2 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done

[ -f "$SRC" ] || fail "Source file not found: $SRC"

case "$TYPE" in
    checkpoint) SUBDIR="stable-diffusion" ;;
    lora)       SUBDIR="Lora" ;;
    vae)        SUBDIR="VAE" ;;
    *)          fail "Invalid --type. Must be: checkpoint, lora, or vae" ;;
esac

# ---- locate the docker volume ----------------------------------------------

if ! docker volume inspect sd-models >/dev/null 2>&1; then
    fail "sd-models Docker volume not found. Run 'docker compose up -d' first."
fi

VOLUME_PATH=$(docker volume inspect sd-models --format '{{ .Mountpoint }}')
TARGET_DIR="${VOLUME_PATH}/${SUBDIR}"
FILENAME=$(basename "$SRC")

log "Source:      ${SRC}"
log "Type:        ${TYPE}"
log "Target dir:  ${TARGET_DIR}"
log "Filename:    ${FILENAME}"

# ---- copy with correct permissions -----------------------------------------

sudo mkdir -p "$TARGET_DIR"
sudo chmod 755 "$TARGET_DIR"

log "Copying file (this may take a minute for large checkpoints)..."
sudo cp "$SRC" "$TARGET_DIR/$FILENAME"
sudo chmod 644 "$TARGET_DIR/$FILENAME"

# ---- trigger SD model rescan -----------------------------------------------

if docker ps --format '{{.Names}}' | grep -q '^stable-diffusion$'; then
    log "Triggering SD checkpoint rescan via API..."
    if curl -fsS -X POST http://localhost:7860/sdapi/v1/refresh-checkpoints >/dev/null 2>&1; then
        log "Rescan complete — the file should now be visible in Open WebUI's image settings dropdown."
    else
        warn "Rescan API call failed. Try one of:"
        warn "  - Open http://localhost:7860 and click the refresh icon next to the model dropdown"
        warn "  - Restart the container:  docker restart stable-diffusion"
    fi
else
    warn "stable-diffusion container not running. Start it with 'docker compose up -d',"
    warn "then trigger a rescan from Open WebUI Admin Panel → Settings → Images."
fi

cat <<EOF

${GREEN}Installed.${NC}

Next:
  1. Open WebUI → Admin Panel → Settings → Images
  2. Click the refresh icon next to the AUTOMATIC1111 Base URL
  3. Select your new ${TYPE} from the Model dropdown
  4. Click Save

For LoRAs: reference them in your prompts as <lora:${FILENAME%.*}:0.8>
EOF