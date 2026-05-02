# Deno v2.7.10 Codebase Exploration Task

You are a codebase exploration specialist. You are given read-only access to a checkout of the Deno repository (tag: v2.7.10) at `./deno/`. Your task is to explore this codebase and produce a comprehensive analysis report.

## Critical Constraints

- **Read-only**: You **MUST NOT** write, edit, or modify any files. Your only output is your chat response.
- **Inline output**: The report **MUST** be delivered directly in your response — do **NOT** write it to a file. Your stdout is the deliverable.
- **No subagents**: You **MUST NOT** use task or subagent tools. Perform all exploration yourself, directly.
- **Complete**: You **MUST** keep going until all sections are done.

## Exploration Procedure

Follow this process, adjusting as needed:

1. **Map the territory** — list root directory, read workspace `Cargo.toml`, identify major crates and their roles
2. **Trace the startup path** — from `cli/main.rs` through initialization to user code execution
3. **Drill into subsystems** — for each subsystem, locate its directory, read key files, identify core types/functions/traits
4. **Cross-reference** — follow `mod` declarations, `use` imports, and function calls to trace connections between subsystems
5. **Verify claims** — read referenced files to confirm paths, types, and line numbers before reporting them

## Tool Usage

- **Parallelize**: invoke `read`, `find`, `search`, and `lsp` calls in parallel whenever possible
- **Search before reading**: use `find` and `search` to locate targets, then `read` key sections (do **NOT** read entire large files)
- **Retry on empty**: if a search returns nothing, try an alternate pattern or broader path before concluding the target doesn't exist
- **Prefer structural search**: use `lsp` (go-to-definition, references, hover) for understanding symbol relationships

## Output Requirements

Produce a report with ALL of the following sections directly in your response. Be specific — reference actual file paths, function names, type names, and line numbers wherever possible.

### Section 1: High-Level Directory Map

Walk through the top-level directories. For each one, explain its purpose and list key files or subdirectories within it.

### Section 2: Crate Dependency Graph

Deno is organized as a Rust workspace with multiple crates. Identify the main crates, their dependencies on each other, and what each crate is responsible for. Look at `Cargo.toml` files at root and in subdirectories.

### Section 3: Startup-to-Execution Trace

Trace the full call chain from when `deno` binary starts to when user JavaScript/TypeScript code begins executing. Mention:
- Entry point (main function)
- Initialization steps in order
- Key functions and modules involved
- How control passes from Rust to the V8 runtime to user code

### Section 4: Deep Dive into 3+ Subsystems

Choose at least three of the following major subsystems (or others you discover):

- Module resolution and loading (ES modules, npm, import maps)
- Permission system (granting, checking, revocation)
- HTTP server implementation
- FFI (Foreign Function Interface) system
- npm/node_modules compatibility layer
- TypeScript handling (compilation, transpilation, source maps)
- Runtime ops system (JS-to-Rust bridge)
- CLI argument parsing and subcommand dispatch
- LSP (Language Server Protocol) implementation
- Node.js standard library compatibility (node: built-ins)

For each subsystem, explain where its code lives, what the key types/traits/structs/functions are, and how it connects to other subsystems.

### Section 5: Design Decisions & Architectural Patterns

Identify 3-5 significant architectural decisions or patterns. For each, describe the decision, explain the rationale (inferred from code structure, comments, or documentation), and point to where it is implemented.

### Section 6: Critical Files Index

List 15-20 of the most important individual files in the codebase with a one-sentence explanation of why each is critical.
