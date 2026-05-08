# WSL2 + Docker + NVIDIA Container Toolkit

> Stub. To be expanded — see [SETUP_GUIDE.md](../SETUP_GUIDE.md) for the consolidated walkthrough.

This page will go deeper on the topic referenced in the title. The setup guide covers the core flow; this page will hold the *why*, the alternatives I considered, and the references that informed the decisions.

Topics to cover when expanded:
- How GPU passthrough actually works through WSL2 (CUDA driver bridging)
- Why Docker Desktop's WSL2 backend is preferred over the Hyper-V backend
- The `nvidia-container-toolkit` vs `nvidia-docker2` distinction
- Verifying the runtime registration in `/etc/docker/daemon.json`
- WSL2 memory limit tuning via `.wslconfig`