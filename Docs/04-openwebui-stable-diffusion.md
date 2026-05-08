# Wiring Open WebUI to Stable Diffusion

> Stub. To be expanded — see [SETUP_GUIDE.md](../SETUP_GUIDE.md) for the consolidated walkthrough.

This page will go deeper on the topic referenced in the title. The setup guide covers the core flow; this page will hold the *why*, the alternatives I considered, and the references that informed the decisions.

Topics to cover when expanded:
- The Open WebUI tool/function-calling architecture and how image-gen plugs in
- Per-model tool enablement vs global enablement
- The `/image` slash command vs natural-language triggering
- A1111 API vs ComfyUI API vs Forge — which Open WebUI supports and the tradeoffs
- Custom system prompts to make models reliably trigger image generation
- The vladmandic/SD.Next variant and why it was chosen over vanilla A1111