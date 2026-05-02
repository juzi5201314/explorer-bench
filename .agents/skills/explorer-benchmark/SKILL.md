---
name: explorer-benchmark
description: Benchmark LLM models on codebase exploration capability. Use when user wants to test, compare, or benchmark models as exploration agents — especially against the Deno codebase. Triggers on phrases like "test models on exploration", "benchmark model exploration", "compare models for codebase understanding", "模型探索能力测试", "模型对比", "benchmark 模型探索". Even if the user doesn't explicitly say "benchmark", trigger this when they ask to test multiple models against a codebase exploration task.
---

# Explorer Benchmark

Orchestrates benchmarking of multiple LLM models on codebase exploration. Each model explores the Deno codebase independently using the same prompt, then outputs are judged and scored by the orchestrating agent.

## Prerequisites

- `omp` CLI must be available
- `./input.md` must exist with the exploration prompt
- Internet access for cloning Deno (first run only)

## Workflow

### Phase 1: Setup

**1a. Ensure Deno codebase exists**

If `./deno/` does not exist:
```bash
git clone --depth 1 --branch v2.7.10 https://github.com/denoland/deno.git ./deno
```

If `./deno/` exists but doesn't look like a Deno checkout (no `Cargo.toml` at root), delete and re-clone.

**1b. Read the exploration prompt**

Read `./input.md` — this is the prompt sent to every model. If it doesn't exist, tell the user and stop.

**1c. Parse model list**

Extract models from the user's message. Models use `provider/model_id` format:
- `anthropic/claude-sonnet-4-20250514`
- `openai/gpt-4o`
- `google/gemini-2.5-pro`

Accept any separator: commas, spaces, newlines, Chinese/English punctuation.

### Phase 2: Execute Model Runs

Run all models **in parallel**. Issue one `bash` tool call per model, all in the same response, with `run_in_background: true`.

**Per-model command:**
```bash
./run_benchmark.sh "<provider/model_id>"
```

The script:
- Strips the provider prefix for the output folder (e.g., `91nv/foo` → `outputs/foo/`)
- Runs `omp` with the tools whitelist (`read,bash,find,lsp,search`)
- Enforces a 10-minute timeout per model
- Writes output to `outputs/<model-id>/YYYY-MM-DD.md` and metadata to `*.meta.json`

**Parallel execution:** Issue all `bash` calls in one response. Example for 3 models:
```
bash(run_in_background: true, command: "./run_benchmark.sh \"anthropic/claude-sonnet-4-20250514\"")
bash(run_in_background: true, command: "./run_benchmark.sh \"openai/gpt-4o\"")
bash(run_in_background: true, command: "./run_benchmark.sh \"google/gemini-2.5-pro\"")
```
After all calls return, collect results from `outputs/<model-id>/`. Do NOT run them one at a time.

**Edge cases:**
- If `omp` fails for a model (non-zero exit), the script still saves output and meta — the failure is a data point
- If a model times out (exit 124), treat as TIMEOUT with score 0
- Do NOT retry — one attempt per model

### Phase 3: Judge Outputs

After all models finish, read each output and score them as the judge.

**Scoring dimensions (each 1-10):**

| Dimension | Weight | What to look for |
|-----------|--------|-----------------|
| 广度 (Breadth) | 25% | Covers all 6 required sections. Multiple subsystems analyzed in depth. Wide range of files/directories referenced. |
| 深度 (Depth) | 25% | Specific file paths, function names, type names, line numbers. Not vague generalizations. Traces actual call chains. |
| 质量 (Quality) | 25% | Clear structure, well-organized, insightful. Goes beyond surface-level description. Makes connections between subsystems. |
| 正确性 (Correctness) | 25% | Claims are accurate against the actual code. Spot-check 3-5 concrete claims per output by reading referenced files in `./deno/`. |

**Correctness verification procedure:**
1. From each output, extract 3-5 specific, falsifiable claims (e.g., "the CLI entry point is `cli/main.rs`", "permissions use a `PermissionsContainer` struct")
2. Verify each claim by reading the referenced file in `./deno/`
3. Score 10 = all verified, 7 = minor errors, 5 = mixed accuracy, 3 = mostly wrong, 1 = fabricated

**Scoring approach:** Read each output fully. Score each dimension independently. Compute weighted total = 0.25 × (breadth + depth + quality + correctness). This normalizes to 1-10.

### Phase 4: Present Results

Display results in a structured, readable format. Use ASCII tables where helpful.

**Required elements:**

1. **Overview table:**
```
| Rank | Model              | Breadth | Depth | Quality | Correctness | Total | Time   |
|------|--------------------|---------|-------|---------|-------------|-------|--------|
| 1    | claude-sonnet-4    | 9       | 8     | 9       | 9           | 8.75  | 4m 32s |
| 2    | gpt-4o             | 8       | 7     | 8       | 7           | 7.50  | 5m 11s |
```

2. **Per-model observations:** One paragraph per model, highlighting key strengths and weaknesses. Be specific — reference what the model got right or wrong.

3. **Overall analysis:** Which model performed best and why? Where did models consistently struggle? Any patterns across models?

4. **Raw outputs reference:** Path to each output file so the user can inspect directly.

**Formatting:** Use clear section headers. Right-align numbers in tables. Use consistent column widths. The display should be scannable at a glance.

## Output Directory Structure

```
./
├── input.md              # Exploration prompt (created by user)
├── deno/                 # Deno codebase checkout
└── outputs/
    ├── claude-sonnet-4-20250514/
    │   ├── 2026-05-02.md           # Model output
    │   └── 2026-05-02.meta.json    # Timing and exit code
    ├── gpt-4o/
    │   ├── 2026-05-02.md
    │   └── 2026-05-02.meta.json
    └── ...
```
