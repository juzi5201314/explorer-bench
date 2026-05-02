# Deno v2.7.10 Codebase Exploration Task

You are given access to a checkout of the Deno repository (tag: v2.7.10) at `./deno/`. Your task is to explore this codebase and produce a comprehensive analysis report.

**Critical constraint: You MUST NOT use task or subagent tools. You must perform all exploration yourself, directly.**

## Output Requirements

Produce a report with ALL of the following sections. Be specific — reference actual file paths, function names, type names, and line numbers wherever possible.

### Section 1: High-Level Directory Map
Walk through the top-level directories. For each one, explain:
- Its purpose in the project
- Key files or subdirectories within it

Strategy: Start by listing the root directory, then drill into each major directory.

### Section 2: Crate Dependency Graph
Deno is organized as a Rust workspace with multiple crates. Identify the main crates, their dependencies on each other, and what each crate is responsible for. Look at `Cargo.toml` files at root and in subdirectories.

### Section 3: Startup-to-Execution Trace
Trace the full call chain from when `deno` binary starts to when user JavaScript/TypeScript code begins executing. Mention specific:
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

For each subsystem:
- Where does its code live? (directories, key files)
- What are the key types, traits, structs, and functions?
- How does it connect to other subsystems?

### Section 5: Design Decisions & Architectural Patterns
Identify 3-5 significant architectural decisions or patterns. For each:
- Describe the decision or pattern
- Explain the rationale (inferred from code structure, comments, or documentation)
- Point to where it is implemented in the code

### Section 6: Critical Files Index
List 15-20 of the most important individual files in the codebase with a one-sentence explanation of why each is critical.

## Exploration Strategy Guidance
- Start broad (root listing, workspace `Cargo.toml`) then narrow into specific areas
- Read key files rather than guessing
- Follow `mod` declarations, `use` imports, and function calls to trace connections
- Pay attention to module-level doc comments and inline comments
- Prioritize understanding the architecture over exhaustively listing every file
