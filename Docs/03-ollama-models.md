# Ollama Model Selection for 8 GB VRAM

> Stub. To be expanded — see [SETUP_GUIDE.md](../SETUP_GUIDE.md) for the consolidated walkthrough.

This page will go deeper on the topic referenced in the title. The setup guide covers the core flow; this page will hold the *why*, the alternatives I considered, and the references that informed the decisions.

Topics to cover when expanded:
- Quantization formats explained: Q2 / Q3 / Q4_K_M / Q5_K_M / Q8 — what's actually different
- Blind A/B benchmark: Q4 7B vs Q3 14B (where the Q4 7B usually wins)
- Coding model comparison: Qwen 2.5 Coder vs DeepSeek Coder vs CodeLlama
- Vision model tradeoffs: Llama 3.2 Vision vs Pixtral vs Gemma 3 multimodal
- Embedding model selection: nomic-embed-text vs mxbai-embed-large vs bge-large
- When a model is worth its VRAM cost (and when it isn't)