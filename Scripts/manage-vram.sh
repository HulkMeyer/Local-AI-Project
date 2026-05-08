#!/usr/bin/env bash
# scripts/manage-vram.sh
#
# Operational helper for the 8 GB VRAM ceiling.
# Encodes the workflow: free VRAM before SD generation, preload an LLM after.
#
# Subcommands:
#   free                  Stop all running Ollama models (frees ~5 GB)
#   preload <model>       Load a specific model into VRAM (replaces whatever was hot)
#   status                Show what's currently loaded and VRAM usage
#   sd-only               Free VRAM and confirm SD has the GPU to itself

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[vram]${NC} $*"; }
warn() { echo -e "${YELLOW}[vram]${NC} $*"; }

usage() {
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  free                  Stop all running Ollama models
  preload <model>       Load a specific model (e.g. qwen3:8b)
  status                Show running models + GPU usage
  sd-only               Free VRAM for an exclusive Stable Diffusion session

Examples:
  $0 sd-only
  $0 preload qwen3:8b
  $0 status
EOF
    exit 1
}

[ $# -ge 1 ] || usage

cmd="$1"; shift || true

ollama_running_models() {
    # ollama ps prints a header row + running models. Skip header.
    ollama ps 2>/dev/null | tail -n +2 | awk '{print $1}'
}

case "$cmd" in
    free)
        models=$(ollama_running_models)
        if [ -z "$models" ]; then
            log "No Ollama models currently loaded."
        else
            for m in $models; do
                log "Stopping ${m}..."
                ollama stop "$m" || warn "  failed to stop ${m}"
            done
            log "VRAM freed."
        fi
        ;;

    preload)
        [ $# -ge 1 ] || { echo "preload requires a model name" >&2; exit 1; }
        model="$1"
        log "Preloading ${model} (sending an empty prompt to force load)..."
        # Empty prompt with num_predict=1 is the cheapest way to load a model into VRAM
        ollama run "$model" --keepalive 30m "" >/dev/null 2>&1 || warn "preload may have failed — check 'ollama list'"
        log "Done. ${model} should now be hot in VRAM."
        ;;

    status)
        echo -e "${CYAN}=== Running Ollama models ===${NC}"
        ollama ps 2>/dev/null || echo "(ollama not responding)"
        echo
        echo -e "${CYAN}=== GPU status ===${NC}"
        if command -v nvidia-smi >/dev/null 2>&1; then
            nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu \
                       --format=csv,noheader,nounits | \
                awk -F', ' '{ printf "  %s\n  VRAM: %s / %s MiB (%.1f%%)\n  GPU:  %s%% util · %s°C\n", $1, $2, $3, ($2/$3)*100, $4, $5 }'
        else
            echo "  nvidia-smi not available"
        fi
        echo
        echo -e "${CYAN}=== Stable Diffusion container ===${NC}"
        if docker ps --format '{{.Names}}\t{{.Status}}' | grep '^stable-diffusion'; then :; else
            echo "  not running"
        fi
        ;;

    sd-only)
        log "Preparing GPU for exclusive Stable Diffusion use..."
        models=$(ollama_running_models)
        for m in $models; do
            log "  stopping ${m}"
            ollama stop "$m" || true
        done
        sleep 2
        log "VRAM status:"
        nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
        log "Ready. Generate images now — call '$0 preload <model>' afterward to bring an LLM back."
        ;;

    *)
        usage
        ;;
esac