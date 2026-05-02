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
    4 | step-3.5-flash                   |    8 |    7 |    8 |      8 |  7.75 |   5m 29s  |
    5 | kimi-k2-thinking                 |    7 |    7 |    7 |      7 |  7.00 |   3m 14s  |
    6 | qwen3.5-397b-a17b                |    7 |    7 |    7 |      6 |  6.75² |   5m 59s  |
    7 | qwen3-next-80b-a3b-thinking      |    6 |    6 |    7 |      7 |  6.50 |   3m 57s  |
    8 | gemini-3-flash-preview           |    5 |    4 |    5 |      6 |  5.00 |      51s  |
    9 | gemini-3.1-flash-lite-preview    |    4 |    3 |    4 |      3 |  3.50 |      37s  |
   10 | nemotron-3-super-120b-a12b       |    2 |    2 |    2 |      5 |  2.75 |   7m 30s  |
   11 | kimi-k2-0905                     |    1 |    1 |    1 |      1 |  1.00 |     29s¹  |
   12 | qwen3-next-80b-a3b-instruct      |    0 |    0 |    0 |      0 |  0.00 |  4m 38s¹  |

¹ 首次运行失败后重跑，详见逐模型观察。
² 首次超时/重跑空输出，用户手动第三次运行成功。

### 逐模型观察

**minimax-m2.7** — 明显胜出。产出最大（31KB），6 个章节全部详尽覆盖，5 个子系统深度剖析。`PermissionState` 枚举描述完全正确（6 个变体全部命中）。启动追踪极其细致。以 582s 的最长时间换来了最高质量。

**deepseek-v4-flash** — 强力亚军，中文输出。各项均衡，5 个子系统深度良好。路径如 `cli/main.rs:4`、`runtime/worker.rs:342`、`libs/ops/lib.rs` 均验证正确。依赖图部分以 ASCII 图组织，结构特别清晰。仅用 3m57s 达到 8.75 分，性价比最优。

**LongCat-2.0-Preview** — 扎实第三，英文报告。6 个子系统，依赖图的分层架构（Layer 0-3）组织尤为出色。关键类型如 `RawDenoResolver`、`NodeResolverRc` 准确。扣分项：部分行号不精确（声称 `main.rs` 第 38 行，实际第 8 行）。

**step-3.5-flash** — 良好中档。所有章节完整，路径具体且基本准确。设计决策部分（快照、ops 快速路径、权限审计）富有洞察力。中文输出清晰。

**kimi-k2-thinking** — 合格报告。三个子系统有合理深度，权限容器机制描述准确。启动追踪大体正确但缺乏顶级模型的精度。思考过程可见于输出，增加了噪声。

**qwen3-next-80b-a3b-thinking** — 可接受的报告。所有章节均有呈现但部分较薄（第 2、5 节尤甚）。三个子系统有中等细节，路径和类型名基本合理。

**gemini-3-flash-preview** — 极快（51s）但相应肤浅。名义上覆盖六章，但子系统深度分析缺乏具体细节——大多为一句话描述，无真正架构洞察。可作为快速概览，不构成探索报告。

**gemini-3.1-flash-lite-preview** — 最快（37s），完成者中质量最低。多处不准确：引用 `runtime/main_worker.rs`（文件不存在，正确为 `runtime/worker.rs`），声称 `runtime/permissions/mod.rs`（实际为 `runtime/permissions/lib.rs`）。子系统仅表面描述。

**nemotron-3-super-120b-a12b** — 运行 7.5 分钟但未产出结构化报告。输出为原始探索笔记（第 1 节目录列表、第 2 节开头）夹杂工具调用。似乎遇到输出限制或陷入探索循环。描述的内容技术上正确，但不足以作为交付物。

**kimi-k2-0905** — 首次运行产出 171 字节的原始工具调用 JSON。重跑（29s）结果相同——仅产出 `[{'type': 'text', 'text': '.'}]`，无法生成任何有意义的报告。该模型在此任务上持续失败。

**qwen3-next-80b-a3b-instruct** — 首次运行 10 分钟超时零输出。重跑（4m38s）产出一条 `[blocked]` 消息，错误声称 `./deno/` 目录不存在而拒绝执行任务。实际上 `./deno/` 就在工作目录中。该模型似乎未正确感知工作目录的文件系统状态。

**qwen3.5-397b-a17b** — 首次运行 10 分钟超时，重跑（1m41s）空输出。用户手动重跑（5m59s）终于产出完整报告。覆盖 6 个章节和 5 个子系统，结构清晰。主要扣分项：`PermissionState` 只描述了 3 个变体（实际 6 个），`PermissionsContainer` 结构体为猜测而非实际代码，启动 JS 文件名不准确（称 `00_infra.js` 实际为 `99_main.js`）。中档水平，与 qwen3-next-80b-a3b-thinking 接近。

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