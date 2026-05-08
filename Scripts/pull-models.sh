#!/usr/bin/env bash
# scripts/pull-models.sh
#
# Pulls the curated model set tuned for 8 GB VRAM (RTX 3070 Laptop).
# Each model is annotated with its quantized VRAM footprint so you can
# decide what to comment out if disk or VRAM is tight.
#
# Idempotent — Ollama skips models that are already pulled.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[models]${NC} $*"; }
warn() { echo -e "${YELLOW}[models]${NC} $*"; }

# Model list — tag : description : approx VRAM (Q4_K_M unless noted)
MODELS=(
    "qwen3:8b|General-purpose daily driver, strong reasoning|~5.2 GB"
    "gemma3:4b|Fast multimodal — vision + text, low VRAM|~2.6 GB"
    "llama3.2-vision:11b|Vision specialist for OCR/charts|~7.5 GB"
    "qwen2.5-coder:7b|Code generation specialist|~4.4 GB"
    "deepseek-r1:8b|Chain-of-thought reasoning|~4.9 GB"
    "nomic-embed-text|Embeddings for RAG|~270 MB"
)

if ! command -v ollama >/dev/null 2>&1; then
    echo "ollama not installed — run ./scripts/setup-environment.sh first" >&2
    exit 1
fi

if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
    log "Starting Ollama service in background..."
    nohup ollama serve >/tmp/ollama.log 2>&1 &
    sleep 3
fi

log "Pulling ${#MODELS[@]} models (existing models will be skipped):"
printf '  %s\n' "${MODELS[@]}"
echo

for entry in "${MODELS[@]}"; do
    IFS='|' read -r tag desc vram <<< "$entry"
    log "Pulling ${tag}  (${vram} — ${desc})"
    if ! ollama pull "$tag"; then
        warn "Failed to pull ${tag}. The tag may have changed upstream — check 'ollama search ${tag%%:*}'."
        warn "Continuing with remaining models."
    fi
done

echo
log "Installed models:"
ollama list

cat <<EOF

${GREEN}Done.${NC}

Tips for the 8 GB ceiling:
  - Only one 7B+ model fits in VRAM at a time. Switching models in
    Open WebUI auto-unloads the previous one.
  - When you also want to run Stable Diffusion, call:
        ./scripts/manage-vram.sh free
    to evict whatever LLM is hot before generating images.
  - Remove a model:  ollama rm <tag>
  - Reclaim "ghost" disk space after removals:  ollama gc
EOF