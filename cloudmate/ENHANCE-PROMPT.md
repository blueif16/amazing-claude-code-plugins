# Task: Enhance CloudMate with Operational Efficiency Principles

You are enhancing a Claude Code skill called CloudMate. The skill lives at:
- `~/Desktop/amazing-claude-code-plugins/cloudmate/skills/cloudmate/SKILL.md` (main brain)
- `~/Desktop/amazing-claude-code-plugins/cloudmate/commands/cl.md` (command entry point)
- `~/Desktop/amazing-claude-code-plugins/cloudmate/skills/cloudmate/references/` (on-demand reference files)

## The Problem

Current AI coding agents waste massive amounts of tokens through operationally stupid behavior:
- Reading file content into context then writing it elsewhere (acting as a clipboard) instead of using `cp` or `mv`
- Reading files "to understand" before having a plan, polluting context with irrelevant code
- Making 10 sequential tool calls when 1 batched command would do
- Asking the user questions they could answer by spawning a quick Explore subagent
- Not using available MCP tools (like Context7 for docs lookup) before guessing at APIs
- Generating code inline in conversation then writing it to a file (2x tokens for same content)

The fix is a principle: **Think expensive. Execute cheap.** Spend tokens on planning, reasoning, and DAG quality. Minimize tokens on execution by dispatching scoped, self-contained work to subagents with fresh context windows.

## Your Job

1. **First: search for best practices.** Before making any changes, search the web for:
   - "Claude Code best practices token efficiency context management 2025 2026"
   - "Claude Code subagent context hygiene Boris Cherny"
   - "agentic coding operational efficiency tool call optimization"
   Read what you find. Absorb the patterns.

2. **Second: read the current skill files.** Use Context7 to look up Claude Code's current skill authoring docs and agent teams docs to understand what tools/capabilities are available. Then read the actual CloudMate files listed above.

3. **Third: add a new reference file** at `references/operational-efficiency.md` (~60-80 lines max) that codifies the principles. The SKILL.md should reference it with a line like: "Before executing ANY plan, read `references/operational-efficiency.md` for execution discipline."

4. **Fourth: update SKILL.md** with a brief new section (Step 0 or woven into existing steps) that establishes the mindset. Keep it to ~10-15 added lines. Don't bloat the file — it's currently 207 lines and should stay under 250.

5. **Fifth: update cl.md** to reinforce the pattern in the execution flows.

## What the Operational Efficiency Reference Should Cover

These are the core principles to encode. Write them as direct instructions to Claude, not as abstract guidelines:

### Context is Money
- Every token in your context window has a cost. Content that enters your context and gets re-output elsewhere is paid for twice.
- Never read a file into context just to write it somewhere else. Use `cp`, `mv`, or redirect.
- Never generate content in conversation text then also write it to a file. Write directly to the file. If the user needs to see it, tell them where to find it.
- When you need to create multiple files, write each one directly. Don't draft them in your response first.

### Gather Context via Subagents, Not Yourself
- Before planning, spawn a lightweight Explore subagent to scan the codebase. It reads files in its own context window and returns a summary. Your context stays clean.
- If you need library documentation, use Context7 MCP (resolve-library-id → get-library-docs) BEFORE writing any code. Don't guess at APIs.
- If you need to understand current best practices or recent changes, search the web first. Don't assume your training data is current.
- The pattern: gather → summarize → plan → dispatch. Each gather step should use the cheapest tool available (subagent for codebase, MCP for docs, web search for practices).

### Batch Operations
- Prefer one `bash` call with multiple commands over multiple `bash` calls with one command each.
- `mkdir -p a/b/c && cp x y && chmod +x y` is one tool call. Three separate calls waste 3x the overhead.
- When creating a directory structure, do it in one `mkdir -p` call, not N sequential calls.

### Dispatch, Don't Do
- For Level 2-3 tasks: your job is to produce the best possible plan and spawn prompts. The subagents do the work.
- Each subagent gets a fresh context window. This is an advantage — they're not polluted by your planning context. Use it.
- Put maximum effort into the spawn prompt. A well-scoped prompt with clear acceptance criteria lets the subagent one-shot the task. A vague prompt causes retries (2-3x cost).
- After dispatching, don't "check on" subagents by reading their files. Wait for them to report completion. Trust the acceptance criteria.

### The Orchestrator Tax
- You (the orchestrator / lead) should use the MINIMUM context necessary to coordinate.
- Don't read implementation files. Read summaries from completed tasks.
- Don't write code. Write plans and spawn prompts.
- Don't explore the codebase. Spawn an Explore agent and read its summary.
- Your context window is the most expensive resource in the system because everything routes through it. Protect it.

### Tool Selection Hierarchy
When you need to accomplish something, pick the cheapest tool:
1. **Bash command** — cheapest. `cp`, `mv`, `mkdir -p`, `grep`, `find`. Zero context cost.
2. **Subagent (Explore)** — cheap. Reads codebase in its own context, returns summary.
3. **MCP tool** — moderate. Context7 for docs, web search for current info. Results enter your context but are usually small.
4. **Reading files yourself** — expensive. Every line enters your context window. Only do this for files you MUST reason about directly (CLAUDE.md, plan.md, small config files).
5. **Writing content in conversation then to file** — most expensive. Double the tokens. Never do this. Write directly to file.

## Important Constraints

- Don't exceed 250 total lines on SKILL.md
- The new reference file should be 60-80 lines, dense and direct
- Keep the existing structure and flow of SKILL.md intact — this is additive, not a rewrite
- Write instructions as imperative commands to Claude ("Do X", "Never Y"), not as guidelines or suggestions
- Test your changes mentally: if Claude follows these rules, would it have avoided the mistake of reading files into context just to copy them to another location? If not, tighten the rules.
