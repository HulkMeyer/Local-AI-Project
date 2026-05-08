# Frontends: Why Open WebUI (and What Else I Looked At)

The frontend is the layer the user actually touches, so the stakes for this decision are different from the inference engine choice. Inference performance is invisible until it isn't; frontend friction shows up every single session.

This doc covers the frontend layer. For the inference engine decision, see [09-inference-engines-comparison.md](./09-inference-engines-comparison.md).

## What a Local LLM Frontend Actually Needs to Do

The minimum useful frontend is just a textbox that streams tokens. Anything beyond that is feature surface, and feature surface is where these tools differentiate. The features that actually matter for a working development environment:

- **Multi-model selection** — pick a model per-conversation, not per-installation
- **Conversation history** — search, organize, export
- **System prompt management** — different prompts for different tasks, savable and reusable
- **RAG (Retrieval-Augmented Generation)** — upload documents, ask questions grounded in them
- **Tool/function calling support** — at minimum, image generation; ideally a plugin system
- **Multi-user / auth** — even for a single user, a login screen prevents drive-by access if the port leaks
- **OpenAI-compatible client** — so the frontend works against Ollama, vLLM, OpenAI, Anthropic, or anything else without code changes
- **Reasonable defaults** — sane temperature, sane max tokens, working out of the box without ten config files

## The Options

### Open WebUI

**What it is:** A self-hosted web UI for local LLMs, originally built around Ollama and now supporting any OpenAI-compatible backend. Active development, large community, ships features at a fast clip.

**Strengths:**
- **RAG built in.** Upload a PDF, ask questions about it. Vector store, embedding model, chunking — all handled.
- **Image generation integration.** The reason this stack works as a unified experience. Connect a Stable Diffusion API and the LLM can call it as a tool.
- **Custom model workspace.** Wrap a base model with a system prompt, a knowledge collection, and tool permissions, save it as a reusable "agent."
- **Plugin / function system.** Python functions that the model can call. Extend it without forking the whole project.
- **Multi-user with role-based access** out of the box. First account becomes admin, others get configurable permissions.
- **Multiple backend providers simultaneously.** Ollama, vLLM, OpenAI, Anthropic, OpenRouter — all can be configured at once and selected per-conversation.
- **Voice input/output.** Built-in STT and TTS via configurable providers.

**Weaknesses:**
- **Heavy for a single user.** Postgres-or-SQLite database, user management, full RBAC, asset pipeline. There's a lot of machinery for "I want to chat with a model alone."
- **Feature churn.** Settings and feature locations move between releases. Tutorials go stale fast (this is visible in the original setup PDF — half the troubleshooting was just "where did this menu go").
- **Opinionated defaults.** RAG embedding chunk sizes, system prompts, sampling parameters all have defaults that work but aren't always optimal. Tuning means digging.
- **The model dropdown can become a mess** when multiple backends are connected — easy to pick the wrong model accidentally.

**Best fit:** Anyone who wants the most features per unit of setup effort and is okay with the weight that comes with that. The right answer for this stack.

---

### LibreChat

**What it is:** An open-source ChatGPT clone, originally aimed at hosting your own multi-provider chat (OpenAI + Anthropic + local) with a polished interface.

**Strengths:**
- **More polished UI** than Open WebUI in most reviewers' opinion. Closer to the actual ChatGPT feel.
- **Strong multi-provider story.** Switching between GPT-4, Claude, and a local model in one conversation is a first-class workflow.
- **Conversation forking and branching.** Take a conversation in two directions from the same midpoint.
- **Plugin support** including a wide range of pre-built ones (web search, image gen, DALL-E, etc.).
- **Active development** with a healthy contributor community.

**Weaknesses:**
- **MongoDB dependency.** Adds a database server to your stack you might not otherwise want.
- **Less local-first.** The UX assumes you're using cloud providers; local models work but feel like a secondary case.
- **RAG is weaker.** Document upload exists but the implementation isn't as featureful as Open WebUI's.
- **No image generation tool integration with local SD.** You can plug in DALL-E or external services more easily than a local Stable Diffusion API.

**Best fit:** People who use multiple cloud providers heavily and treat local models as a complement rather than the main event. A team that wants ChatGPT-like UX over their internal API gateway.

---

### AnythingLLM

**What it is:** A document-centric chat application built around the workspace concept. RAG isn't a feature, it's the entire point.

**Strengths:**
- **RAG-first design.** Workspaces, document collections, chunk visualization, citation tracking — all built around grounded conversation.
- **Multi-modal document support.** PDFs, web pages, GitHub repos, Confluence, Notion — broader ingestion than Open WebUI.
- **Per-workspace embedding configuration.** Different doc collections can use different embedding models and chunk strategies.
- **Lighter than Open WebUI.** Faster to start, fewer moving parts.
- **Citation UI is excellent.** When the model answers, you see exactly which document chunks it pulled from.

**Weaknesses:**
- **Chat-as-an-afterthought.** If you want a free-form coding assistant, the workspace metaphor gets in the way.
- **Fewer power-user features.** No conversation branching, weaker prompt template management, less tool/function support.
- **Smaller plugin ecosystem.**
- **Image generation integration is limited.**

**Best fit:** Knowledge management, internal documentation Q&A, research assistants. If 80% of your usage is "ask questions about these docs," AnythingLLM is purpose-built for that.

---

### Lobe Chat

**What it is:** A polished, plugin-rich chat UI with an emphasis on aesthetics and persona/agent management.

**Strengths:**
- **Best-looking interface** of the options, by most accounts.
- **Strong "agent marketplace"** — community-shared system prompts and personas.
- **Good multi-provider support** including local backends.
- **Lightweight** — runs in a container without a database server.
- **PWA support** — install it like a native app on mobile.

**Weaknesses:**
- **RAG is weaker** than Open WebUI or AnythingLLM.
- **Tool calling support is limited.**
- **Less mature multi-user / auth story.**
- **Some features are paywalled** in the hosted version (the open-source self-hosted version is still useful but feels less complete).

**Best fit:** Personal use where look-and-feel matters. Sharing a chat UI with non-technical family members. Mobile-friendly access.

---

### Hollama

**What it is:** A minimalist, single-binary chat client for Ollama. Runs entirely in the browser, no server.

**Strengths:**
- **Truly minimal.** Just a chat interface. Loads in milliseconds.
- **No backend.** Everything is browser-side, talking directly to Ollama's API.
- **Trivial to deploy.** It's a static site.

**Weaknesses:**
- **Just a chat interface.** No RAG, no tools, no multi-user, no image gen.
- **Ollama-specific.** Doesn't help if you want to also reach OpenAI or Anthropic.

**Best fit:** When you want a fast chat textbox and nothing else. A backup interface when Open WebUI is being upgraded.

---

### Chatbot UI

**What it is:** An open-source ChatGPT-style interface, originally OpenAI-focused, now supports local backends.

**Strengths:**
- **Familiar ChatGPT UX.**
- **Lightweight.**
- **Multi-provider support.**

**Weaknesses:**
- **Development pace has slowed** compared to Open WebUI or LibreChat.
- **Feature surface is small** — basic chat with provider switching, not much else.
- **No RAG.**
- **No image generation tool integration.**

**Best fit:** A simpler alternative when Open WebUI feels like overkill but you still want something with a polished UI.

---

### Raw OpenAI-Compatible API (No Frontend)

**What it is:** Just hit Ollama's `/v1/chat/completions` endpoint from your code or `curl`.

**Strengths:**
- **Zero overhead.** Maximum control.
- **Programmable from anywhere.** Python, JS, shell, curl in a hotkey.
- **No UI to maintain.**

**Weaknesses:**
- **No UI.** No conversation history unless you build it. No model selection unless you build it. No RAG unless you build it.

**Best fit:** Programmatic use cases — agents, batch inference jobs, automation. A complement to a frontend, not a replacement.

---

## The Decision Matrix

| Primary need | Best frontend | Why |
|---|---|---|
| Full-featured local AI workstation | **Open WebUI** | RAG + image gen + tools + multi-backend in one place |
| Multi-provider (cloud + local) chat | **LibreChat** | First-class multi-provider story, polished UI |
| Document Q&A as the main job | **AnythingLLM** | Purpose-built for RAG with great citations |
| Aesthetic personal assistant | **Lobe Chat** | Best-looking UI, agent marketplace |
| Fastest possible chat textbox | **Hollama** | Static site, no server |
| Programmatic / agent use | **Raw API** | No UI overhead |

## Why Open WebUI Specifically Won for This Stack

Three properties tipped it for this specific repo:

1. **Image generation tool integration.** This stack's defining feature is the LLM-to-Stable-Diffusion bridge: ask the chat model for an image and it triggers SD via a tool call. Open WebUI's per-model tool permissions and `/image` slash command make this work. No other frontend on this list does it as cleanly with a local SD endpoint.

2. **RAG out of the box.** Document Q&A is the obvious next portfolio project — a research assistant grounded in user documents. Open WebUI's RAG isn't world-class, but it's good enough to demonstrate the pattern without bolting on a separate vector database service. AnythingLLM does RAG better but lacks the image-gen and tool stories.

3. **Plugin system as an extension path.** When this stack grows — adding web search, calendar integration, code execution — Open WebUI's Python function plugin system is the path forward. LibreChat has plugins too but they're more cloud-provider-oriented. Open WebUI's are local-first.

The honest tradeoff: **Open WebUI is heavy for a single user.** The auth system, the Postgres/SQLite database, the asset pipeline — all overkill for one person on a laptop. If this stack were just "chat with a local model and nothing else," Hollama or even raw API hits would be more rational. The weight is justified by the feature surface this stack actually uses.

## What Would Trigger a Migration

Same exercise as the inference engine doc — documenting the threshold makes the current choice defensible:

- **If RAG quality becomes the bottleneck** in real use, AnythingLLM is the upgrade path. The workspace metaphor and citation UI are genuinely better.
- **If multi-provider workflows dominate** (heavy Claude / GPT-5 use alongside local), LibreChat's UX is a meaningful improvement.
- **If the upgrade churn becomes painful** — Open WebUI moves fast and breaks things between releases — pinning to a stable LibreChat or Lobe Chat version is reasonable.
- **If the stack becomes API-only** (an agent loop, no human chat), Open WebUI becomes overhead and direct API hits make more sense.

Until any of these are true, Open WebUI is the correct choice for the feature density this stack needs.

## Further Reading

- [Open WebUI documentation](https://docs.openwebui.com/) — their own docs, which are decent
- [LibreChat documentation](https://www.librechat.ai/docs) — particularly the multi-provider config
- [AnythingLLM architecture overview](https://docs.anythingllm.com/architecture) — useful for understanding the RAG-first design
- [Awesome local AI list](https://github.com/janhq/awesome-local-ai) — a broader catalog of frontends and inference engines if you want to keep exploring