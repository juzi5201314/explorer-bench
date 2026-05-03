# Explorer Benchmark

对多个 LLM 模型进行代码库探索能力的基准测试。每个模型独立探索 Deno v2.7.10 代码库，使用相同的提示词，由编排代理对输出进行评分。

## 使用方法

### 前置条件

- `omp` CLI 可用
- 网络访问（首次运行需克隆 Deno）

### 快速开始

```bash
# 1. 编写探索提示词
cat > input.md << 'EOF'
# Deno v2.7.10 Codebase Exploration Task
...
EOF

# 2. 确保 Deno 代码库存在（首次自动克隆）
# 3. 向编排代理发送模型列表即可启动
```

模型通过以下命令运行（仅开放探索所需的 5 个工具，`write` / `edit` 被禁用以防止报告写入文件而非 stdout）：

```bash
omp --model "<provider/model_id>" \
    -p "$(cat ./input.md)" \
    --thinking high \
    --tools read,bash,find,lsp,search
```

工具白名单：
 `read`, `find`, `search`, `lsp` — 核心探索：读文件、glob 查找、内容搜索、代码智能
 `bash` — 运行 git/cargo 等系统命令

排除的工具：
 `write`, `edit` — 防止模型将报告写入文件
 `task` — 工具层面强制禁止子代理
 `browser`, `web_search`, `ask`, `notebook`, `python` — 探索任务不需要

### 评分维度

| 维度 | 权重 | 说明 |
|------|------|------|
| 广度 | 25% | 覆盖 6 个必选章节，多子系统分析，文件/目录引用广度 |
| 深度 | 25% | 具体文件路径、函数名、类型名、行号，追溯实际调用链 |
| 质量 | 25% | 结构清晰、组织良好、有洞察力，跨子系统连接 |
| 正确性 | 25% | 抽查 3-5 个声明，与代码库逐条验证 |

总分 = 0.25 × (广度 + 深度 + 质量 + 正确性)，归一化至 1-10。

### 输出结构

```
.
├── input.md              # 探索提示词
├── deno/                 # Deno 代码库
└── outputs/
    ├── <model-id>/
    │   ├── YYYY-MM-DD.md           # 模型输出
    │   └── YYYY-MM-DD.meta.json    # 耗时与退出码
    └── ...
```

---

## 基准测试报告 — 2026-05-02

**提示词:** `input.md` | **超时:** 10 分钟/模型 | **代码库:** Deno v2.7.10

### 总览

| 排名 | 模型                             | 广度 | 深度 | 质量 | 正确性 | 总分  | 耗时      |
|------|----------------------------------|------|------|------|--------|-------|-----------|
|    1 | minimax-m2.7                     |   10 |   10 |    9 |      9 |  9.50 |   9m 42s  |
|    2 | deepseek-v4-flash                |    9 |    9 |    9 |      8 |  8.75 |   3m 57s  |
|    3 | LongCat-2.0-Preview              |    9 |    9 |    8 |      7 |  8.25 |   6m 25s  |
|    4 | step-3.5-flash                   |    8 |    7 |    8 |      8 |  7.75 |   5m 29s  |
|    5 | kimi-k2-thinking                 |    7 |    7 |    7 |      7 |  7.00 |   3m 14s  |
|    6 | qwen3.5-397b-a17b                |    7 |    7 |    7 |      6 |  6.75² |   5m 59s  |
|    7 | qwen3-next-80b-a3b-thinking      |    6 |    6 |    7 |      7 |  6.50 |   3m 57s  |
|    8 | gemini-3-flash-preview           |    5 |    4 |    5 |      6 |  5.00 |      51s  |
|    9 | gemini-3.1-flash-lite-preview    |    4 |    3 |    4 |      3 |  3.50 |      37s  |
|   10 | nemotron-3-super-120b-a12b       |    2 |    2 |    2 |      5 |  2.75 |   7m 30s  |
|   11 | kimi-k2-0905                     |    1 |    1 |    1 |      1 |  1.00 |     29s¹  |
|   12 | qwen3-next-80b-a3b-instruct      |    0 |    0 |    0 |      0 |  0.00 |  4m 38s¹  |

¹ 首次运行失败后重跑。
² 首次超时/重跑空输出，用户手动第三次运行成功。

### 综合分析

**最佳表现:** `minimax-m2.7` 以 9.50/10 获得最高总分，深度和正确性均达到顶尖水平。代价是速度——582s 是非超时模型中最慢的。

**最佳性价比:** `deepseek-v4-flash` 仅用 3m57s 达到 8.75 分，比冠军快 2.5 倍而得分达其 92%。

1. **持续失败的模型**: kimi-k2-0905 和 qwen3-next-80b-a3b-instruct 在首次运行和重跑中均无法产出有效报告。kimi-k2-0905 两次产出工具调用碎片；qwen3-instruct 误判文件系统状态而拒绝执行。qwen3.5-397b-a17b 前两次失败（超时、空输出），第三次手动运行成功产出中档质量报告，说明该模型存在不稳定性。
2. **思考过程泄漏**: 多个模型（minimax、kimi-k2-thinking、step-3.5、LongCat）将推理过程混入报告输出，属工具配置噪声而非模型能力问题。
3. **未完成探索**: nemotron 花了 7.5 分钟探索但从未将发现综合成报告。
4. **表面分析**: gemini flash 系列优先速度而非深度，产出的报告更像 README 概览而非代码库探索。

**所有模型正确捕获的架构模式:**
- 基于扩展的架构（`deno_core::extension!`）
- V8 启动快照以加速冷启动
- `#[op2]` 过程宏用于 JS-Rust 桥接
- 执行前构建模块图
- Op 级别的权限检查

**多数模型感到困难的领域:**
- 精确行号（多数仅大致范围）
- npm 解析子系统（复杂的多层解析流程）
- `deno compile` / eszip 独立二进制路径
- TS 编译器集成细节（tsserver vs tsgo 桥接）

### 原始输出

| 模型 | 输出路径 |
|------|---------|
| minimax-m2.7 | `./outputs/minimax-m2.7/2026-05-03.md` |
| deepseek-v4-flash | `./outputs/deepseek-v4-flash/2026-05-03.md` |
| LongCat-2.0-Preview | `./outputs/LongCat-2.0-Preview/2026-05-03.md` |
| step-3.5-flash | `./outputs/step-3.5-flash/2026-05-03.md` |
| kimi-k2-thinking | `./outputs/kimi-k2-thinking/2026-05-03.md` |
| qwen3-next-80b-a3b-thinking | `./outputs/qwen3-next-80b-a3b-thinking/2026-05-03.md` |
| gemini-3-flash-preview | `./outputs/gemini-3-flash-preview/2026-05-03.md` |
| gemini-3.1-flash-lite-preview | `./outputs/gemini-3.1-flash-lite-preview/2026-05-03.md` |
| nemotron-3-super-120b-a12b | `./outputs/nemotron-3-super-120b-a12b/2026-05-03.md` |
| kimi-k2-0905 | `./outputs/kimi-k2-0905/2026-05-03.md` |
| qwen3-next-80b-a3b-instruct | `./outputs/qwen3-next-80b-a3b-instruct/2026-05-03.md` |
| qwen3.5-397b-a17b | `./outputs/qwen3.5-397b-a17b/2026-05-03.md` |

元数据（耗时、退出码）位于对应的 `*.meta.json` 文件中。标注 ¹ 的模型为首次运行失败后重跑的结果；标注 ² 为前两次失败后第三次手动运行的结果。重跑耗时和评分基于最终有效运行。

---

## 基准测试报告 — 2026-05-03

**提示词:** `input.md` | **超时:** 10 分钟/模型 | **代码库:** Deno v2.7.10 | **批次:** 2 × 6 模型并行

### 总览

| 排名 | 模型                              | 广度 | 深度 | 质量 | 正确性 | 总分  | 耗时      |
|------|-----------------------------------|------|------|------|--------|-------|-----------|
|    1 | step-3.5-flash                    |   10 |   10 |    9 |      8 |  9.25 |   6m 37s  |
|    2 | kimi-k2-thinking                  |    9 |    9 |    9 |      7 |  8.50 |   6m 03s  |
|    3 | qwen3.5-397b-a17b                 |    9 |    9 |    9 |      7 |  8.50 |   4m 09s  |
|    4 | LongCat-2.0-Preview               |    9 |    9 |    9 |      7 |  8.50 |   8m 50s¹ |
|    5 | qwen3-next-80b-a3b-thinking       |    8 |    7 |    8 |      8 |  7.75 |   2m 09s  |
|    6 | minimax-m2.7                      |    8 |    7 |    7 |      6 |  7.00 |   6m 23s  |
|    7 | gemini-3-flash-preview            |    6 |    5 |    7 |      7 |  6.25 |   1m 21s  |
|    8 | nemotron-3-super-120b-a12b        |    7 |    6 |    7 |      5 |  6.25 |   9m 35s  |
|    9 | gemini-3.1-flash-lite-preview     |    5 |    4 |    5 |      5 |  4.75 |     19s   |
|   10 | kimi-k2-0905                      |    0 |    0 |    0 |      0 |  0.00 |     40s   |
|   11 | qwen3.5-9b                        |    0 |    0 |    0 |      0 |  0.00 |     28s¹  |
|    - | qwen3-next-80b-a3b-instruct       |    — |    — |    — |      — |  DNF   | TIMEOUT   |

¹ 首次运行失败/超时后重跑，评分基于重跑结果。

### 综合分析

**最佳表现:** `step-3.5-flash` 以 9.25/10 夺魁。其 511 行报告包含 `common_extensions()` 中 34 个扩展的完整初始化顺序表、行数精确验证（`cli/lib.rs` 1255 行，实际一致）、以及 LSP 子系统深度剖析（多数模型未涉及）。扩展初始化顺序的逐条枚举是实际代码遍历的有力证据，而非模板套用。

**最佳性价比:** `qwen3-next-80b-a3b-thinking` 仅用 2m09s 取得 7.75 分，正确性（8 分）在中等以上模型中最佳。`gemini-3-flash-preview` 在 1m21s 内产出合理报告（6.25），速度最快。

**Thinking 变体的关键作用:**
- qwen3-next 家族：thinking 变体成功完成（第 5 名），非 thinking 变体超时。差异显著。
- kimi-k2 家族：thinking 变体获第 2 名（8.50），非 thinking 变体空输出（0 分）。同样悬殊。
- 推理能力对于多步骤代码库探索任务似乎是必需的。

**可靠性对比（与 2026-05-02 相比）:**
- `step-3.5-flash`：从 7.75（第 4）跃升至 9.25（第 1）。两次运行均完成，质量大幅提升归因于本轮的 34 扩展枚举和 LSP 深度分析。
- `kimi-k2-thinking`：从 7.00（第 5）提升至 8.50（第 2）。子系统深度从 3 个增至 6 个。
- `qwen3.5-397b-a17b`：从 6.75（第 6，第三次手动运行）提升至 8.50（第 3）。本轮一次完成，未出现前次的不稳定问题。
- `LongCat-2.0-Preview`：从 8.25（第 3）至 8.50（第 4）。两次均完成且质量相近。本轮伪造了 `ext/console` 和 `ext/broadcast_channel` 两个不存在的扩展，但整体质量仍高。
- `minimax-m2.7`：从 9.50（第 1）降至 7.00（第 6）。最大降幅。本轮将 `runtime/permissions/`（目录）误作 `.rs` 文件，多处行号存疑。前次的高分可能部分归因于运气较好的"猜测命中"。
- `gemini-3-flash-preview`：从 5.00（第 8）升至 6.25（第 7）。小幅改善。
- `nemotron-3-super-120b-a12b`：从 2.75（第 10）升至 6.25（第 8）。前次仅产原始笔记，本轮产出完整报告，但伪造了 `ext/fd/` 路径（实为 `ext/fs/`）。

**持续失败的模型:**
- `qwen3.5-9b`：两次运行均空输出（18-28s）。该模型规模不足以完成此任务。
- `kimi-k2-0905`：首次产 `[{'type': 'text', 'text': '.'}]`，本轮相同。输出一个点号即停止，属工具调用层面的失败。
- `qwen3-next-80b-a3b-instruct`：两次均超时。非 thinking 变体在此任务上持续失败。

**共同准确点:**
- 分层 crate 架构：`deno_core` → `deno_runtime` → `ext/*` → `cli`
- `PermissionsContainer` / `PermissionState` 类型识别
- 通过 `99_main.js` 的启动流程
- V8 快照优化

**共同错误模式:**
- 行号不可靠——最优模型亦有偏差
- 目录 vs 文件混淆（`runtime/permissions/` 被多模型当作 `.rs` 单文件）
- 压力下的伪造（`ext/fd/`、`ext/console`、`ext/broadcast_channel` 均不存在）
- 小型模型直接崩溃

### 原始输出

| 模型 | 输出路径 |
|------|---------|
| step-3.5-flash | `./outputs/step-3.5-flash/2026-05-03.md` |
| kimi-k2-thinking | `./outputs/kimi-k2-thinking/2026-05-03.md` |
| qwen3.5-397b-a17b | `./outputs/qwen3.5-397b-a17b/2026-05-03.md` |
| LongCat-2.0-Preview | `./outputs/LongCat-2.0-Preview/2026-05-03.md` |
| qwen3-next-80b-a3b-thinking | `./outputs/qwen3-next-80b-a3b-thinking/2026-05-03.md` |
| minimax-m2.7 | `./outputs/minimax-m2.7/2026-05-03.md` |
| gemini-3-flash-preview | `./outputs/gemini-3-flash-preview/2026-05-03.md` |
| nemotron-3-super-120b-a12b | `./outputs/nemotron-3-super-120b-a12b/2026-05-03.md` |
| gemini-3.1-flash-lite-preview | `./outputs/gemini-3.1-flash-lite-preview/2026-05-03.md` |
| kimi-k2-0905 | `./outputs/kimi-k2-0905/2026-05-03.md` |
| qwen3.5-9b | `./outputs/qwen3.5-9b/2026-05-03.md` |
| qwen3-next-80b-a3b-instruct | `./outputs/qwen3-next-80b-a3b-instruct/2026-05-03.md` |

元数据（耗时、退出码）位于对应的 `*.meta.json` 文件中。标注 ¹ 的模型为首次运行失败后重跑的结果。