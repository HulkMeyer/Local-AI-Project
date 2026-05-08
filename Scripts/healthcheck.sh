#!/usr/bin/env bash
# scripts/healthcheck.sh
#
# End-to-end verification that the stack is wired up correctly.
# Run this any time something feels off — it's faster than `docker logs` digging.
#
# Checks (in order, fail-fast):
#   1. Host can see GPU
#   2. Docker daemon reachable
#   3. NVIDIA runtime registered with Docker
#   4. CUDA container can see GPU (passthrough working)
#   5. ai-stack network exists with both containers attached
#   6. Ollama responding on host port 11434
#   7. Open WebUI responding on 3000
#   8. Stable Diffusion API responding on 7860 with models loaded
#   9. Container-to-container DNS works (open-webui → stable-diffusion)

set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
PASS="${GREEN}✓${NC}"; FAIL="${RED}✗${NC}"; WARN="${YELLOW}!${NC}"

failures=0
check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo -e " ${PASS} ${label}"
    else
        echo -e " ${FAIL} ${label}"
        ((failures++))
    fi
}

echo "Host environment"
check "nvidia-smi available on host"          command -v nvidia-smi
check "Docker daemon reachable"               docker info
check "NVIDIA runtime registered with Docker" bash -c 'docker info 2>/dev/null | grep -qi "Runtimes:.*nvidia"'

echo
echo "GPU passthrough"
check "GPU visible inside CUDA container" \
    docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi

echo
echo "Network topology"
check "ai-stack network exists" docker network inspect ai-stack
check "open-webui on ai-stack" \
    bash -c "docker network inspect ai-stack --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -q open-webui"
check "stable-diffusion on ai-stack" \
    bash -c "docker network inspect ai-stack --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -q stable-diffusion"

echo
echo "Service health"
check "Ollama responding on :11434"      curl -fsS http://localhost:11434/api/tags
check "Open WebUI responding on :3000"   curl -fsS http://localhost:3000/health
check "Stable Diffusion API on :7860"    curl -fsS http://localhost:7860/sdapi/v1/sd-models

echo
echo "Inter-container DNS (the fix for the host.docker.internal failure)"
check "open-webui → stable-diffusion by name" \
    docker exec open-webui curl -fsS http://stable-diffusion:7860/sdapi/v1/sd-models

echo
if [ "$failures" -eq 0 ]; then
    echo -e "${GREEN}All checks passed.${NC} Stack is healthy."
    exit 0
else
    echo -e "${RED}${failures} check(s) failed.${NC} See docs/07-troubleshooting.md for fixes."
    exit 1
fi