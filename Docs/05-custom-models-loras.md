# Custom Checkpoints and LoRA Stacking

> Stub. To be expanded — see [SETUP_GUIDE.md](../SETUP_GUIDE.md) for the consolidated walkthrough.

This page will go deeper on the topic referenced in the title. The setup guide covers the core flow; this page will hold the *why*, the alternatives I considered, and the references that informed the decisions.

Topics to cover when expanded:
- Checkpoint architecture overview (UNet + VAE + text encoder)
- SD 1.5 vs SDXL vs Flux — which fits in 8 GB and which doesn't
- LoRA mathematics — how rank, alpha, and weight interact
- LoRA stacking strategy — base-model + style + concept layering
- Trigger word discovery for poorly-documented LoRAs
- Negative embeddings (Textual Inversion) as a complement to negative prompts
- VAE selection for line art vs photoreal — when to override the baked-in VAE