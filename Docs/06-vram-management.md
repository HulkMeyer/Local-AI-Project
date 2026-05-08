# VRAM Management on 8 GB

The single most important constraint in this stack. Everything in the rest of the docs is downstream of decisions made here.

## The 8 GB Budget

```
┌───────────────────────────────────────────────────────────┐
│  Total VRAM: 8192 MiB on RTX 3070TI Laptop                  │
├───────────────────────────────────────────────────────────┤
│  Windows compositor + browser:    ~1000–1500 MiB (always) │
│  Ollama-loaded LLM (idle):        Q4 7B ≈ 5200 MiB        │
│  Stable Diffusion (idle):         ~2500 MiB               │
│  Stable Diffusion (generating):   +1500–2500 MiB peak     │
│  KV cache (LLM context):          grows with chat length  │
└───────────────────────────────────────────────────────────┘
```

The math doesn't add up — you cannot have a hot 7B+ LLM and run Stable Diffusion at the same time without crashes. The stack is engineered around this fact.

## What Fits at the Same Time

| Workload A | Workload B | Same time? | Notes |
|---|---|---|---|
| qwen3:8b (Q4) | gemma3:4b (Q4) | No (Ollama unloads on switch) | Ollama auto-unloads previous model |
| qwen3:8b (Q4) | nomic-embed-text | Yes | Embedding model is ~270 MB |
| qwen3:8b (Q4) | Stable Diffusion idle | Borderline | Tight; runs but no headroom |
| qwen3:8b (Q4) | Stable Diffusion generating | **No** | OOM during diffusion steps |
| gemma3:4b (Q4) | Stable Diffusion generating | Yes | The combination that works |
| llama3.2-vision:11b (Q4) | anything else | **No** | 11B fills 7.5 GB on its own |

## The Workflow

`scripts/manage-vram.sh` codifies the day-to-day pattern:

```bash
# Before a heavy image generation session
./scripts/manage-vram.sh sd-only

# Generate as many images as you want — SD has the GPU to itself

# When done, bring an LLM back
./scripts/manage-vram.sh preload qwen3:8b
```

For mixed workflows (chat + occasional images), set the LLM context window short and use `gemma3:4b` as the chat brain — it leaves enough headroom that SD can generate without evicting it.

## Why Not Just Use a Bigger Quantization?

The temptation is to think "smarter model = better answers." For coding and reasoning that's true up to a point, but on 8 GB the ceiling drops fast:

- A Q8 7B model (~7.5 GB) leaves no room for context — KV cache pushes you over the edge after a few thousand tokens
- A Q3 14B model fits (~6.8 GB) but the heavy quantization costs more coherence than the extra parameters add. Q4 7B usually wins blind A/B tests against Q3 14B.

**Q4_K_M at the 7–9B parameter range is the sweet spot.** Above that, you're paying VRAM for diminishing returns. The model list in `pull-models.sh` reflects this.

## Tools for Watching VRAM

### `nvidia-smi` — fast and universal

```bash
watch -n 1 nvidia-smi
```

What to look for:
- `Memory-Usage` column — total used / total available
- `GPU-Util %` — should spike during inference, idle near 0
- The processes table at the bottom — shows which container/process owns the memory

### `nvtop` — graphical, in-terminal

```bash
sudo apt install -y nvtop && nvtop
```

Better than `nvidia-smi` for spotting trends — VRAM curves over time make it obvious when context is creeping toward the ceiling.

### `manage-vram.sh status` — stack-aware summary

```bash
./scripts/manage-vram.sh status
```

Shows running Ollama models, SD container status, and current VRAM utilization in one view.

## Failure Modes & Mitigations

| Symptom | Cause | Mitigation |
|---|---|---|
| Tokens/sec drops mid-conversation | KV cache hit ceiling, spilling to system RAM | Restart chat or `/clear`; switch to smaller model |
| SD generation stalls or fails | LLM hot in VRAM | `manage-vram.sh sd-only` before generating |
| Laptop fans go full-blast and tokens slow | GPU thermal throttle (>83°C) | Cooling pad, plug in (battery PL1 limits power) |
| Random crash mid-generation | OOM with `--medvram` disabled | Confirm `--medvram` is in `CLI_ARGS` |
| Generated images all-black | `--no-half-vae` missing on certain checkpoints | Already in compose; verify `docker exec stable-diffusion env` shows it |

## When to Upgrade Hardware

If you find yourself fighting the 8 GB ceiling daily, the cheapest path forward is a 16 GB consumer card (4060 Ti 16 GB, 4070 Super 12 GB at minimum). The same `docker-compose.yml` runs unchanged — just remove `--medvram` from `CLI_ARGS` for ~30% faster image generation, and you can run a 13B Q4 LLM and SD concurrently without juggling.

For serious inference work, a 24 GB card (3090 / 4090) lets you run a 30B Q4 model with full SDXL — the same compose file, no flag changes needed.
