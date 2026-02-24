---
name: market-recon
description: "Guide for using Reddit MCP to gather community sentiment, pain points, and adoption trends. Load this skill when a DAG contains research tasks about market validation, developer experience, or community opinions."
---

# Market Recon — Community Research via MCP

This skill is for the **main thread / orchestrator only**. Subagents cannot call MCP tools directly. You fetch the data, write it to disk, and pass the file path to the subagent.

## When to Use

DAG contains tasks with type=research AND signals like: community, sentiment, pain points, adoption, market, trends, opinions, practitioners, experience.

## Query Strategy

1. **Pick 2-3 subreddits** matching the topic:
   - Dev tooling / AI coding: `ClaudeAI`, `ChatGPTCoding`, `cursor`
   - General dev: `programming`, `webdev`, `ExperiencedDevs`
   - Infra / backend: `devops`, `sysadmin`, `kubernetes`
   - Frontend: `reactjs`, `nextjs`, `webdev`
   - Specific tech: use the technology's own subreddit

2. **Search with short, specific queries** (2-4 words). Run 2-3 queries per subreddit to cover angles: the tool name, the pain point, the alternative.

3. **Skim results for signal**: recurring complaints, praise patterns, specific user stories. Ignore hype posts with no substance.

## Output Format

Write results to `.godag/context/{task_id}-market.md`:

```markdown
# Market Recon: {topic}
## Sources
- r/{sub1}: {N} relevant posts searched
- r/{sub2}: {N} relevant posts searched

## Key Pain Points
1. {pain point} — {1-2 sentence evidence with post reference}
2. ...

## Positive Signals
1. {signal} — {evidence}

## Sentiment: {positive|negative|mixed|shifting}

## Gaps / Unmet Needs
- {gap}
```

Keep the file under 2000 tokens. The subagent needs a concise briefing, not a data dump.

## Passing to Subagent

In the spawn prompt, add:
```
Read .godag/context/{task_id}-market.md for community research data.
Analyze and synthesize — don't just summarize what's in the file.
```
