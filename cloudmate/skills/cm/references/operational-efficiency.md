# Operational Efficiency — Context Quality = Output Quality

This file applies to Level 2+ orchestration. You are the orchestrator — you do not write code. Subagents write code.

Every irrelevant byte in your context window degrades your reasoning on the actual task. This is not about cost. It is about preventing the attention dilution that makes you produce wrong plans, miss dependencies, and write vague spawn prompts.

## Rule 1: Never Be a Clipboard

- File moves/copies: use `cp`, `mv`, `sed`, bash redirects. Never read a file into context just to write it elsewhere.
- Plan files and spawn prompts: write directly to `.tasks/`. Do not draft them in your response then also write them to a file.

Why: content that passes through your context twice pushes out the signal you need to reason about the next task.

## Rule 2: Gather Context via Subagents

- Codebase understanding: spawn an Explore subagent. It reads files in its own context and returns a focused summary. Your context stays clean.
- After dispatching work: read task completion summaries, not the implementation files subagents produced.
- The Explore subagent MUST write a `findings.md` to `.tasks/` (or a location you specify) with detailed discoveries — file paths, interface shapes, patterns found, gotchas. Then return a compact summary to you. This way detailed context persists on disk for spawn prompts without entering your window.

Why: raw file contents are low-signal, high-noise. A subagent summary is pre-filtered to what matters. The findings file lets you pass precise context to downstream subagents by reference, not by reading it yourself.

## Rule 3: Verify Before You Write — Context7 via Subagent

- Before writing code that uses ANY library or framework beyond the most basic builtins (fs.readFileSync, console.log, basic string ops), verify current usage patterns via Context7.
- Only skip verification when you are absolutely certain about the practice — meaning you could write it from muscle memory. If there is any doubt, look it up.
- Include Context7 verification as a mandatory step in every `implement` and `fix` spawn prompt. The implementing subagent looks up docs in its own clean window.
- If you need to understand a library to write a good spawn prompt, spawn a quick verification subagent first: "Use Context7 to find current best practice for [specific thing]. Write a cheatsheet to `.tasks/context7-[topic].md`. Return a one-line confirmation." You get the one-liner; the full docs stay in the subagent's window.

Why: a hallucinated API causes a failed acceptance check. The retry runs in a context polluted by the failed attempt, biasing the second try. One subagent lookup prevents the entire cascade — and the docs never touch the orchestrator's window.

## Rule 4: Batch Operations

- Prefer one `bash` call with `&&`-chained commands over multiple sequential calls.
  `mkdir -p src/{auth,api,tests} && cp template.ts src/auth/index.ts && chmod +x scripts/setup.sh` — one call, not three.
- Directory scaffolding: one `mkdir -p`, not N separate creates.

Why: each tool call result enters your context. Three results saying "directory created" is three blocks of noise. One combined result is one.

## Rule 5: Protect the Orchestrator Window

You (the lead/coordinator) hold the MINIMUM context necessary to coordinate:
- Do NOT read implementation files. Read summaries from completed tasks.
- Do NOT write code. Write plans and spawn prompts.
- Do NOT explore the codebase. Spawn Explore and read its summary.
- Do NOT "check on" subagents by reading their output files. Wait for completion + acceptance results.
- When passing context to downstream tasks, reference the findings file path in the spawn prompt (`"Read .tasks/explore-findings.md for codebase context"`). Do not paste its contents into the prompt yourself.

Why: your window is the bottleneck. Everything routes through you. If it is filled with implementation details from T1, your planning quality for T4 degrades.

## Rule 6: Invest Tokens Where They Compound

Spend heavily on these — they are high-leverage:
- Plan quality: a precise DAG prevents wasted parallel work.
- Spawn prompt precision: exact scope + acceptance criteria + upstream findings file path = subagent one-shots in a clean window.
- Acceptance criteria specificity: a runnable command, not a vague description.

A vague spawn prompt causes a retry. The retry runs in a context polluted by the first failed attempt. Output quality on attempt 2 is WORSE than attempt 1. Front-load the thinking.
