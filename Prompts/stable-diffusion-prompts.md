# Stable Diffusion Prompts (Tested)

Working prompt templates with the AnyLoRA checkpoint, validated on the 3070TI Laptop. Generation settings unless otherwise noted: 512×768, 25 steps, DPM++ 2M Karras sampler, CFG 7.

## Coloring Book — Line Art

For high-contrast black-and-white pages suitable for KDP coloring book interiors.

### Prompt template

```
(masterpiece:1.2), (best quality), (line art:1.4), (coloring book:1.4),
[SUBJECT_HERE],
monochrome, white background, black and white outlines, clean lines,
bold edges, no shading, no grayscale, high contrast
```

### Negative prompt (essential)

```
shading, shadow, 3d, render, photo, realistic, grayscale, gradient,
blurry, messy lines, sketch, colored, saturation, solid black areas,
textured background, lowres, bad anatomy, bad hands, extra digits,
cropped, watermark, signature
```

### Stacking LoRAs

Format: `<lora:FILENAME_NO_EXT:WEIGHT>` injected anywhere in the prompt.

Two-LoRA stack for AnyLoRA + dedicated line-art style:

```
masterpiece, [SUBJECT],
<lora:AnyLoRA_bakedVae_blessed_fp16:0.6>
<lora:coloring_book_lineart:0.9>
```

Tuning notes:
- Base model LoRA (AnyLoRA): 0.4–0.7 — too high and it overpowers the style LoRA
- Style LoRA (line art): 0.8–1.0 — this should be the dominant signal
- If output is too clean/sparse, drop style LoRA to 0.7
- If output has too much shading, raise style LoRA to 1.1 max

## Attention Weighting

Parentheses around tags weight them up:

| Syntax | Weight |
|---|---|
| `tag` | 1.0 |
| `(tag)` | 1.1 |
| `((tag))` | 1.21 |
| `(tag:1.4)` | 1.4 (preferred — explicit) |
| `[tag]` | 0.9 |

For anatomy-specific weighting that the conversation kept circling, prefer the explicit `(thing:1.3)` form over piling on parentheses — it's easier to tune and read later.

## Settings Pinned in `compose.yml`

The CLI flags in the SD container baseline these knobs once so you don't have to set them per-prompt:

- `--xformers` → memory-efficient attention
- `--medvram` → progressive model offload (essential for 8 GB)
- `--no-half-vae` → prevents black-image bug at higher resolutions
- `--opt-channelslast` → ~20% throughput on Ampere GPUs

If you upgrade to a 16 GB+ card, drop `--medvram` for ~30% faster generation.