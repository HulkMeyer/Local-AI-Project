# Troubleshooting

Every failure mode hit during the build, with the actual fix. Ordered roughly by frequency.

## `docker run` fails with "could not select device driver"

**Symptom:** Right after installing the NVIDIA Container Toolkit, the verification command fails:
```
docker: Error response from daemon: could not select device driver "" with capabilities: [[gpu]]
```

**Root cause:** The toolkit was installed and `nvidia-ctk runtime configure` wrote to `/etc/docker/daemon.json`, but Docker Desktop wasn't restarted, so the daemon never reloaded the runtime config.

**Fix:** Right-click the Docker Desktop whale in the Windows system tray → **Restart**. The Linux `sudo service docker restart` command does **not** work here — Docker Desktop runs the daemon on the Windows side.

---

## SD container starts and immediately exits

**Symptom:** `docker ps` shows the `stable-diffusion` container as `Exited (1)` seconds after `docker compose up -d`.

**Root cause:** Looking at logs (`docker logs stable-diffusion`) shows:
```
SD_WEBUI_VARIANT: unbound variable
```
The `ghcr.io/neggles/sd-webui-docker` image is multi-variant — it requires `SD_WEBUI_VARIANT` to be set or the entrypoint script aborts.

**Fix:** Already encoded in `docker-compose.yml`:
```yaml
environment:
  - SD_WEBUI_VARIANT=vladmandic
```

---

## SD container starts but Open WebUI says "connection refused"

**Symptom:** Saving the Stable Diffusion settings in Open WebUI Admin Panel returns:
```
dial tcp: lookup host.docker.internal on 127.0.0.11:53: no such host
```

**Root cause:** `host.docker.internal` doesn't resolve from inside the Open WebUI container by default on Linux/WSL. Even on Windows where it sometimes works, hairpinning out to the Windows host and back into a sibling container is slow and fragile.

**Fix:** Both containers are on the `ai-stack` Docker network in `docker-compose.yml`, so they can resolve each other by container name. Use:
```
http://stable-diffusion:7860/
```
in the Open WebUI image settings, **not** `host.docker.internal`.

---

## Custom checkpoint doesn't appear in the SD model dropdown

**Symptom:** You copied a `.safetensors` file into the volume, but it's missing from the dropdown in Open WebUI's image settings and at `localhost:7860`.

There are three common causes — `install-checkpoint.sh` handles all of them, but if you're doing it manually:

### Cause 1: Wrong subfolder case

The folder is case-sensitive. The vladmandic backend looks for `stable-diffusion/` (lowercase). If you ran `mkdir Stable-diffusion`, it'll silently miss the file.

```bash
sudo mv /var/lib/docker/volumes/sd-models/_data/Stable-diffusion \
        /var/lib/docker/volumes/sd-models/_data/stable-diffusion
```

### Cause 2: Permissions

The container user can't read root-owned 600 files.

```bash
sudo chmod -R 755 /var/lib/docker/volumes/sd-models/_data/stable-diffusion/
sudo chmod 644 /var/lib/docker/volumes/sd-models/_data/stable-diffusion/*.safetensors
```

### Cause 3: API hasn't rescanned

Even with the file in the right place, the running SD process caches the model list at startup.

```bash
curl -X POST http://localhost:7860/sdapi/v1/refresh-checkpoints
```

Or click the refresh icon in the localhost:7860 UI's checkpoint dropdown, or `docker restart stable-diffusion` as a last resort.

---

## "I'm a text-based AI and cannot generate images"

**Symptom:** You ask the LLM for an image and it apologizes instead of triggering the SD bridge.

**Root cause:** Open WebUI's image-gen tool is opt-in per-model. The base Ollama models that auto-populate the dropdown don't have the tool enabled.

**Fix:**
1. Open WebUI → **Workspace → Models → + New Model**
2. Set **Base Model** to e.g. `qwen3:8b`
3. Scroll to **Tools** → enable **Image Generation**
4. Save and select that custom model in the chat dropdown
5. Either click the image icon in the chat bar, or prefix prompts with `/image`

If it still apologizes, edit the system prompt of the custom model to include:
> "You have access to an image generation tool. When the user asks for an image, use it. Do not claim you cannot generate images."

---

## "CUDA out of memory" during image generation

**Symptom:** Image generation fails partway through, container logs show `torch.cuda.OutOfMemoryError`.

**Root cause:** A 7B+ LLM is hot in VRAM (5+ GB) and SD's model load pushes total usage over 8 GB.

**Fix:** Free VRAM before generating:
```bash
./scripts/manage-vram.sh sd-only
```

Other knobs if you still hit OOM:
- Drop image size to 512×512
- Drop step count to 20
- Confirm `--medvram` is in `CLI_ARGS` (it is, in the compose file)
- Remove `--xformers` if you're on a very old GPU driver

---

## Ollama install fails with "zstd not found"

**Symptom:** The Ollama install script aborts with a missing-tool error.

**Root cause:** The Ollama installer ships its binary as a zstd-compressed tarball.

**Fix:** Already in `setup-environment.sh`. Manually:
```bash
sudo apt-get install -y zstd
curl -fsSL https://ollama.com/install.sh | sh
```

---

## Model pull fails with "manifest: file does not exist"

**Symptom:** `ollama pull qwen3:14b-instruct-q3_K_M` returns a 404-style error.

**Root cause:** Ollama tag conventions vary. The exact suffix string in the docs may not match what's actually published.

**Fix:** Search for the canonical tag:
```bash
ollama search qwen3
```
Then try the simplest form first: `ollama pull qwen3:14b` (Ollama defaults to a sensible Q4 quant). Add quant suffixes only if the default doesn't fit your VRAM.

---

## `nvidia-smi` works on host but fails in container

**Symptom:** `nvidia-smi` works in PowerShell and in a bare WSL shell, but `docker run --gpus all` containers can't see the GPU.

**Possible causes (in order of likelihood):**

1. Docker Desktop wasn't restarted after the toolkit install — restart it from the system tray.
2. `nvidia-ctk runtime configure --runtime=docker` was run, but `/etc/docker/daemon.json` was overwritten by Docker Desktop's own config writer. Re-run the configure and restart.
3. WSL2 kernel is too old. `wsl --update` from PowerShell.
4. NVIDIA driver on Windows is missing CUDA-on-WSL support. Update to a recent Game Ready or Studio driver.

Confirm with:
```bash
docker info | grep -i runtime
```
You should see `nvidia` in the list.

---

## Open WebUI shows no models in the dropdown

**Symptom:** Logged into Open WebUI, but the model picker is empty.

**Root cause:** Open WebUI can't reach Ollama on the host.

**Fix:** Open WebUI → **Settings → Connections** → confirm the Ollama URL is `http://host.docker.internal:11434`. If that fails, check Ollama is actually running on the host:
```bash
curl http://localhost:11434/api/tags
```
If Ollama is down, `nohup ollama serve >/tmp/ollama.log 2>&1 &` to start it. On WSL2 you may need to add it to `~/.bashrc` or use a `systemd` unit so it starts with the shell.