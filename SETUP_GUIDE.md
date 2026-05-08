# Setup Guide

End-to-end walkthrough for building the stack on a Windows 11 host with an RTX 3070 Laptop (8 GB VRAM). Estimated time: 60–90 minutes, most of which is downloads.

If you've used this repo before, the `Quick Start` in [README.md](./README.md) is what you want. This guide exists for the first time through and as the reference when something breaks.

---

## 0. Prerequisites

| Requirement | Check command | Notes |
|---|---|---|
| Windows 11 (or 10 build 19041+) | `winver` in Run dialog | Older builds won't have `wsl --install` |
| Hardware virtualization enabled | Task Manager → Performance → CPU → Virtualization | Enable in BIOS/UEFI if disabled |
| NVIDIA driver ≥ 535 | `nvidia-smi` in PowerShell | Installer from nvidia.com if missing |
| Docker Desktop | `docker --version` | Install from docker.com |
| ~50 GB free disk | `Get-PSDrive C` | Models + containers add up fast |

> **Heads up.** If `nvidia-smi` doesn't run in PowerShell, none of this will work. Fix the driver first.

---

## 1. Install WSL2 + Ubuntu

In an **elevated PowerShell** (Run as Administrator):

```powershell
wsl --install
```

This enables WSL2, installs Ubuntu, and sets WSL2 as the default. Reboot when prompted, then launch **Ubuntu** from the Start menu and create your Linux username/password.

Verify you're on WSL2 (not WSL1):

```powershell
wsl --list --verbose
```

If the version column shows `1`, upgrade it:

```powershell
wsl --set-version Ubuntu 2
```

---

## 2. Configure Docker Desktop for WSL2

Open Docker Desktop → **Settings**:

1. **General** → check **Use the WSL 2 based engine**
2. **Resources → WSL integration** → toggle **Ubuntu** ON
3. **Apply & Restart**

Verify from inside Ubuntu:

```bash
docker ps
```

If this returns a (likely empty) container list instead of an error, Docker is wired up correctly.

---

## 3. Install NVIDIA Container Toolkit

This is what lets Docker containers see your GPU. **Run this inside Ubuntu** (not PowerShell — `sudo apt-get` doesn't exist on Windows):

```bash
./scripts/setup-environment.sh
```

The script handles everything from the [NVIDIA Container Toolkit install](./scripts/setup-environment.sh):

- Adds the NVIDIA repo with proper GPG keys
- Installs `nvidia-container-toolkit`
- Configures Docker to use the NVIDIA runtime
- Installs `zstd` (required for Ollama install)
- Installs Ollama itself
- Restarts the Docker daemon

After it finishes, **right-click the Docker whale in the Windows system tray → Restart** so Docker picks up the new runtime config.

### Verify GPU passthrough

```bash
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

Success looks like a table with **NVIDIA GeForce RTX 3070 Laptop GPU** and 8192 MiB of memory. If you see the table, every later step will work. If you see "could not select device driver" or similar, the toolkit didn't install — check the script output and the [troubleshooting doc](./docs/07-troubleshooting.md).

---

## 4. Pull the Model Set

```bash
./scripts/pull-models.sh
```

This pulls the curated model set for 8 GB VRAM. Defaults:

| Model | Role | VRAM (Q4) |
|---|---|---|
| `qwen3:8b` | General-purpose daily driver | ~5.2 GB |
| `gemma3:4b` | Fast multimodal | ~2.6 GB |
| `llama3.2-vision:11b` | Document/image OCR | ~7.5 GB |
| `qwen2.5-coder:7b` | Code generation | ~4.4 GB |
| `nomic-embed-text` | Embeddings for RAG | ~270 MB |

Edit the script to add or remove models. The full rationale is in [docs/03-ollama-models.md](./docs/03-ollama-models.md).

> **Don't pull all of these at once if you're tight on disk.** Each is 2–8 GB. Comment out the ones you don't need.

---

## 5. Bring Up the Stack

From the repo root:

```bash
docker compose up -d
```

This starts both Open WebUI and Stable Diffusion (SD.Next variant) on a shared `ai-stack` Docker network. They can resolve each other by container name — this is the fix for the `host.docker.internal` DNS failure that ate hours of debugging time the first time around.

First boot of Stable Diffusion downloads ~5 GB of base weights. Watch progress:

```bash
docker logs -f stable-diffusion
```

Wait for `Starting uvicorn server on http://0.0.0.0:7860` before moving on.

### Verify

```bash
./scripts/healthcheck.sh
```

This script checks: GPU visible to host, GPU visible to containers, Ollama responding on 11434, Open WebUI responding on 3000, Stable Diffusion responding on 7860.

---

## 6. Configure Open WebUI

Open `http://localhost:3000` in your browser. **The first account you create becomes the admin** — there's no password recovery, so don't lose it.

### Connect Ollama

Open WebUI auto-detects Ollama via `host.docker.internal:11434`. Verify:

- Bottom-left profile → **Settings → Connections**
- **Ollama API** should show as connected
- Top of any chat window — your pulled models appear in the dropdown

### Connect Stable Diffusion

- **Admin Panel → Settings → Images**
- **Image Generation** → toggle ON
- **Image Generation Engine**: `Automatic1111`
- **AUTOMATIC1111 Base URL**: `http://stable-diffusion:7860/`
- **Image Size**: `512x512` (fits in VRAM cleanly with an LLM also loaded)
- **Steps**: `25`
- Click **Save**

The save button is the test — if it errors with "connection refused," the SD container hasn't finished loading its weights yet, or it's not on the `ai-stack` network. Run `docker network inspect ai-stack` to verify both containers are listed.

### Enable image generation per model

Open WebUI requires you to explicitly enable the image-gen tool on each model you want to use it from:

1. **Workspace → Models → + New Model**
2. **Base Model**: pick e.g. `qwen3:8b`
3. **Name**: `Qwen 3 (with images)`
4. Scroll to **Tools** → enable **Image Generation**
5. Save

Now in the main chat dropdown, select your custom model and either click the image icon in the chat bar or prefix your prompt with `/image`.

---

## 7. Add a Custom SD Checkpoint or LoRA

The default SD download is the generic v1.5 model — fine for testing, mediocre for anything specific. To install a checkpoint (e.g., `AnyLoRA` for anime line art):

1. Download the `.safetensors` file from Civitai or HuggingFace into your Windows `Downloads` folder
2. Run:

```bash
./scripts/install-checkpoint.sh ~/Downloads/AnyLoRA_bakedVae_blessed_fp16.safetensors
```

The script handles the three things that bit me the first time:
- Creates the **lowercase** `stable-diffusion/` subfolder (the backend won't see capitalized `Stable-diffusion/`)
- Sets read permissions so the container user can access the file
- Triggers an SD model rescan so it appears in the dropdown without a container restart

For LoRAs, the same script with `--type lora`:

```bash
./scripts/install-checkpoint.sh ~/Downloads/coloring_book_lineart.safetensors --type lora
```

After install, refresh the model list in Open WebUI's image settings and select the new checkpoint.

---

## 8. Daily Operation

### Start the stack
```bash
docker compose up -d
```

### Stop the stack
```bash
docker compose down
```

Volumes (`open-webui`, `sd-models`, `sd-outputs`) persist — your chats, settings, and downloaded checkpoints survive a `down/up` cycle.

### Free VRAM before image generation

The 8 GB ceiling means you usually can't have a 7B+ LLM hot and run SD at the same time without crashes. Before a heavy image generation:

```bash
./scripts/manage-vram.sh free
```

This calls `ollama stop` on every running model. To preload a specific LLM after image work:

```bash
./scripts/manage-vram.sh preload qwen3:8b
```

### Watch the GPU

```bash
watch -n 1 nvidia-smi
```

Or install `nvtop` for a graphical view: `sudo apt install -y nvtop && nvtop`.

---

## 9. What to Read Next

- [docs/06-vram-management.md](./docs/06-vram-management.md) — what fits with what, when to quantize harder
- [docs/07-troubleshooting.md](./docs/07-troubleshooting.md) — every failure mode I hit, with the actual fix
- [docs/05-custom-models-loras.md](./docs/05-custom-models-loras.md) — stacking LoRAs, weight tuning, prompt structure for line art