# Inference Engines: Why Ollama (and When You'd Want Something Else)

A common confusion when designing a local LLM stack is collapsing two distinct architectural decisions into one. The "frontend" question (Open WebUI vs. LibreChat vs. AnythingLLM) and the "inference engine" question (Ollama vs. vLLM vs. llama.cpp vs. TGI) live at different layers and should be evaluated independently.

This doc covers the inference engine layer. For the frontend decision, see [10-frontends-comparison.md](./10-frontends-comparison.md).

## What an Inference Engine Actually Does

Before comparing options, it's worth being precise about the job. An inference engine takes model weights (a multi-gigabyte file) and turns them into a callable API that produces tokens from prompts. Doing this well requires solving several non-trivial problems:

- **Memory management** — loading weights into VRAM, evicting them on demand, sharing them across requests
- **KV cache** — the running attention state that grows with context length and dominates memory beyond ~4K tokens
- **Batching** — combining concurrent requests so the GPU does one big matrix multiply instead of many small ones
- **Quantization** — running the model at lower precision (Q4, Q5, Q8) to fit larger models in less VRAM
- **Tokenizer handling** — different model families use different tokenizers; getting this wrong corrupts output silently
- **Sampling** — top-k, top-p, temperature, repetition penalty, mirostat — and exposing these as knobs

How an engine prioritizes these jobs determines whether it's a good fit for single-user local development, multi-tenant production serving, or embedded/edge deployment.

---

## The Options

### Ollama

**What it is:** A friendly wrapper around `llama.cpp` with a model registry, hot-swappable model loading, and an OpenAI-compatible HTTP API.

**Strengths:**
- **Zero-configuration model management.** `ollama pull qwen3:8b` downloads the right quantization, registers it, and makes it available via the API. No `pip install`, no Python environment, no tokenizer config files.
- **Automatic VRAM swapping.** Switch models mid-session and Ollama unloads the previous one. This is huge on an 8 GB card — it's the entire reason `manage-vram.sh` works.
- **Single binary install.** `curl | sh`. No CUDA toolkit setup beyond the NVIDIA Container Toolkit you already need.
- **OpenAI-compatible API for free** at `localhost:11434/v1`. Anything that talks to OpenAI talks to Ollama.
- **Sensible defaults for GGUF quantization.** You usually don't pick a quant — Ollama picks Q4_K_M for you, which is the right choice 90% of the time.

**Weaknesses:**
- **Single-stream, no continuous batching.** If two requests arrive simultaneously, the second one waits. Throughput at concurrency is poor.
- **GGUF-only.** Can't run raw HuggingFace transformers, can't run AWQ/GPTQ quants without conversion, can't run vision models that haven't been ported to GGUF.
- **Limited sampling parameter exposure** vs. raw llama.cpp.
- **The library lags upstream.** A new model on HuggingFace can take days to weeks to appear in Ollama's registry.

**Best fit:** Single-user local development on consumer hardware. The case this entire stack is built around.

---

### vLLM

**What it is:** A production-grade inference server built around two key innovations: **PagedAttention** (treats KV cache like virtual memory, dramatically reducing fragmentation) and **continuous batching** (mixes tokens from different requests in the same forward pass).

**Strengths:**
- **10–20x throughput at concurrency** vs. Ollama. If you have 50 concurrent users, this is not a contest.
- **Supports raw HuggingFace model paths.** Run a model 10 minutes after it's released, no conversion required.
- **Speculative decoding, chunked prefill, prefix caching** — production-grade optimizations Ollama doesn't have.
- **Battle-tested at scale.** Anyscale, Anthropic-adjacent companies, and many others run it in production.
- **OpenAI-compatible API** mode (`vllm serve`).

**Weaknesses:**
- **Heavyweight Python install.** Pulls in PyTorch, CUDA libraries, FlashAttention. Several GB of disk and a finicky environment to maintain.
- **No model registry.** You manage HuggingFace model paths yourself.
- **No automatic VRAM swapping.** vLLM loads one model at startup and that's what you get. Switching models means restarting the server.
- **VRAM-hungry.** PagedAttention's gains assume you *have* concurrent requests to amortize the overhead. On a single-user laptop, the overhead just costs you headroom.
- **Slow cold starts.** A vLLM server with a 7B model takes 30–60 seconds to come up. Ollama loads on first request in ~3 seconds.
- **Doesn't support GGUF quants natively** (though support is improving). For GPU inference at scale you'd typically use AWQ or GPTQ.

**Best fit:** Production serving with concurrent users. A team of 10+ developers hitting the same endpoint, an internal API serving a product, or batch inference jobs.

---

### llama.cpp

**What it is:** The C++ inference engine that Ollama is built on top of. Pure native code, runs anywhere, started life as the canonical CPU-only inference path and has since grown excellent GPU support.

**Strengths:**
- **Runs anywhere.** Pure C++, no Python, no PyTorch. Compiles on a Raspberry Pi, runs on Apple Silicon, runs on AMD, runs on a phone.
- **Most quantization options.** Q2_K_S, IQ3_XXS, exotic K-quants — anything in the GGUF ecosystem.
- **Smallest install footprint.** A single binary, optionally with CUDA libs.
- **Maximum control.** Every sampling parameter, every memory knob, exposed.
- **The fastest path to a brand-new architecture support.** When a new model family drops, llama.cpp usually has it before Ollama wraps it.

**Weaknesses:**
- **You manage everything.** Model file paths, quant selection, prompt templates, tokenizer special tokens. There's a learning curve that Ollama abstracts away.
- **No model registry.** You're downloading GGUF files from HuggingFace by hand.
- **Bare-bones HTTP server.** The included `llama-server` works but is far less polished than Ollama's API.
- **Documentation is mostly source code.**

**Best fit:** Embedded deployments, edge devices, exotic hardware, custom inference pipelines, anyone who needs the absolute latest model support before higher-level tools wrap it.

---

### TGI (HuggingFace Text Generation Inference)

**What it is:** HuggingFace's production inference server. Similar architectural goals to vLLM (continuous batching, optimized kernels) but tighter integration with the HuggingFace ecosystem.

**Strengths:**
- **First-class HuggingFace integration.** Hub authentication, dataset integration, model card metadata.
- **Strong Rust-based core** with Python bindings.
- **Excellent quantization support** (AWQ, GPTQ, EETQ, bitsandbytes).
- **Streaming support is mature.** SSE endpoints work cleanly.

**Weaknesses:**
- **Dockerized by design.** Running it bare-metal is awkward.
- **License gotchas.** Some versions had restrictive licenses (this has improved but check the version you're considering).
- **Smaller community than vLLM.** Fewer Stack Overflow answers, fewer blog posts.

**Best fit:** Production serving inside the HuggingFace ecosystem, especially if your team is already using HF Hub heavily.

---

### LM Studio / GPT4All / Jan

**What they are:** Desktop applications, not servers. They bundle an inference engine (usually llama.cpp under the hood) with a chat UI.

**Strengths:**
- **Zero command line.** Click to download a model, click to chat.
- **Built-in model browser** with quantization selector.
- **Sometimes a built-in OpenAI-compatible local server** mode (LM Studio specifically).

**Weaknesses:**
- **Not a server.** They're built for one person on one machine using the bundled UI.
- **No automation path.** No `docker compose up`, no integration into a broader stack.
- **License caveats** (LM Studio is closed-source freeware).

**Best fit:** Non-developers who want to chat with a local model. Quick experimentation before committing to a stack. Not a fit for the kind of repo this is.

---

## The Decision Matrix

| Need | Best engine | Why |
|---|---|---|
| Single-user local dev on consumer GPU | **Ollama** | Model management + VRAM swapping + zero config |
| Production API with 10+ concurrent users | **vLLM** | Continuous batching makes the throughput delta enormous |
| Inside HuggingFace ecosystem at scale | **TGI** | Hub integration, similar perf to vLLM |
| Embedded / edge / exotic hardware | **llama.cpp** | Pure C++, runs anywhere, smallest footprint |
| Bleeding-edge model support, day-one | **llama.cpp** | New architectures land here first |
| Maximum quantization options | **llama.cpp** | GGUF ecosystem has the most variety |
| Casual chat, no server needed | **LM Studio** | Click-to-run desktop app |

## Why Ollama Specifically Won for This Stack

The 8 GB VRAM ceiling on an RTX 3070 Laptop isn't an arbitrary constraint — it actively determines which engine is rational to use:

1. **Model swapping is more valuable than throughput.** This stack is single-user. There are no concurrent requests to batch. vLLM's central performance argument doesn't apply. Meanwhile, the ability to `ollama stop qwen3:8b` to free 5 GB of VRAM before image generation is the workflow the entire stack depends on. vLLM cannot do this without a process restart.

2. **VRAM headroom matters more than peak throughput.** PagedAttention is brilliant when you have spare VRAM and concurrent requests to amortize its bookkeeping over. On a tight 8 GB budget with one user, that bookkeeping is just overhead.

3. **The OpenAI-compatible API means zero lock-in.** If this stack ever moves to a multi-user context (a team server, a 24 GB rig, etc.), swapping Ollama for vLLM is a change to one URL in `docker-compose.yml`. The frontend, the prompts, the system prompts — none of it changes.

4. **Operational simplicity is a feature.** Ollama install is one command. vLLM install is a Python environment, CUDA version matching, and probably a docker image. For a portfolio repo that other people might actually try to run, simpler wins.

The honest tradeoff: **if this were a production multi-tenant deployment, vLLM would be the right answer.** The choice of Ollama is an explicit acknowledgment that this stack is for development and experimentation, not for serving an external user base.

## What Would Trigger a Migration to vLLM

Documenting the threshold makes the current choice defensible — these are the points at which I'd revisit it:

- **3+ concurrent users** hitting the same model regularly. Ollama's queue becomes a bottleneck somewhere around there.
- **Hardware upgrade to 24 GB+ VRAM.** PagedAttention's gains start to outweigh its overhead when you have headroom.
- **A model that only ships as raw HF transformers** that the team needs day-one. llama.cpp/Ollama eventually catch up but vLLM is there immediately.
- **Production deployment behind a real load balancer** with SLOs to hit. Ollama isn't engineered for that; vLLM is.

Until any of these are true, Ollama is the correct choice and the simpler one.

## Further Reading

- [vLLM PagedAttention paper (Kwon et al., 2023)](https://arxiv.org/abs/2309.06180) — the key technical innovation, worth reading even if you stick with Ollama
- [Ollama architecture overview](https://github.com/ollama/ollama/blob/main/docs/README.md) — what's actually under the hood
- [llama.cpp quantization guide](https://github.com/ggerganov/llama.cpp/blob/master/examples/quantize/README.md) — for understanding the K-quant variants
- [HuggingFace TGI vs vLLM benchmark](https://huggingface.co/docs/text-generation-inference) — their own comparison, take with a grain of salt