# Architecture and Design Decisions

> Stub. To be expanded — see [SETUP_GUIDE.md](../SETUP_GUIDE.md) for the consolidated walkthrough.

This page will go deeper on the topic referenced in the title. The setup guide covers the core flow; this page will hold the *why*, the alternatives I considered, and the references that informed the decisions.

Topics to cover when expanded:
- Why Docker Compose instead of bare `docker run` (the consolidation argument)
- Why a custom bridge network (`ai-stack`) instead of `host.docker.internal`
- Why Ollama on the host instead of in a container (model file portability + simpler GPU access)
- Why SD.Next/vladmandic instead of vanilla A1111 (memory efficiency on 8 GB)
- Volume strategy — what persists vs what's regenerable
- The healthcheck design and what it does and doesn't catch
- Upgrade path: how this scales from 8 GB → 16 GB → 24 GB → multi-GPU
- What I'd change if I were running this in production (TLS, auth proxy, observability)