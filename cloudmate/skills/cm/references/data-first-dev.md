# Data-First Full-Stack Development

This file applies to any agent implementing or fixing full-stack features — whether you're the L1 lead doing solo work, or an L2/L3 subagent. The principle: **never write rendering code against imagined data. Verify the real shape, then code against it.**

## Rule 1: Backend First, Always

Write or modify the API endpoint before touching frontend rendering. Verify what it actually returns:

```bash
# Hit the endpoint directly — no browser needed
curl -s http://localhost:8000/api/courses | python3 -c "import sys,json; d=json.load(sys.stdin); print(type(d).__name__, len(d) if isinstance(d,list) else list(d.keys()))"
```

If the endpoint already exists and you're building new frontend against it:
```bash
agent-browser open http://localhost:3000/<page>
agent-browser network requests --filter <endpoint-keyword>
```

Now you know the exact shape. Write frontend against that, not your training data.

## Rule 2: Log Types and Shape, Not Full Payloads

When adding temporary observability, log the DATA STRUCTURE — not the full content. Full payloads flood console output and waste tokens when the agent reads them back.

**Wrong — dumps everything, 500+ tokens to read back:**
```tsx
console.log('[DATA-FLOW]', JSON.stringify(data, null, 2));
```

**Right — shape only, 20-50 tokens to read back:**
```tsx
console.log('[DATA-FLOW] courses:', {
  type: typeof data,
  isArray: Array.isArray(data),
  length: Array.isArray(data) ? data.length : undefined,
  keys: Array.isArray(data) ? Object.keys(data[0] || {}) : Object.keys(data || {}),
  sample: Array.isArray(data) ? data[0] : undefined  // ONE item, not all
});
```

```python
# Backend equivalent
import logging
logger = logging.getLogger("data-flow")
logger.info(f"[DATA-FLOW] /api/courses → type={type(result).__name__} len={len(result) if hasattr(result,'__len__') else 'N/A'} keys={list(result[0].keys()) if isinstance(result,list) and result else list(result.keys()) if isinstance(result,dict) else 'N/A'}")
```

This tells you: "it's a list of 5 objects with keys [id, name, status, created_at]" — everything you need to write rendering code. Not 200 lines of JSON.

**Tag all temporary logs with `[DATA-FLOW]` prefix. Remove before committing:**
```bash
grep -rn "DATA-FLOW" src/
```

## Rule 3: Browser Verification — Cheap Signals First

After making changes, verify in ascending token cost:

```
~0 tok:   Read terminal output (build errors, server logs)
~50 tok:  agent-browser errors            # JS runtime errors
~200 tok: agent-browser console            # your [DATA-FLOW] logs land here
~300 tok: agent-browser network requests --filter <keyword>
~20 tok:  agent-browser eval '<targeted JS expression>'
~20 tok:  agent-browser get styles @e1     # CSS computed styles
~300 tok: agent-browser snapshot -i        # interactive elements with refs
~2000+:   agent-browser screenshot         # full visual — last resort
```

**Default verification after any code change:**
```bash
agent-browser errors       # anything blow up?
agent-browser console      # any warnings? any [DATA-FLOW] output?
```

**Use `snapshot -i` when you need to INTERACT** (click a button, fill a form, trigger a flow). It's the standard agent-browser workflow — not expensive for interactive-only. Don't use bare `snapshot` without `-i` (returns full tree, 3-5x tokens).

**Use `eval` for surgical checks** — cheaper than snapshot when you know what to verify:
```bash
agent-browser eval 'document.querySelectorAll(".course-card").length'         # "3"
agent-browser eval 'document.querySelector(".error-message")?.textContent'    # null
agent-browser eval 'document.querySelector("[data-loading]") !== null'        # "false"
```

## Rule 4: The Implement-Verify Cycle

For each piece of a feature:

1. **Check version**: `cat package.json | grep <lib>` or `pip show <pkg>`
2. **Check docs**: Context7 for the specific API you're about to use
3. **Backend change** → verify with curl or network requests
4. **Frontend change** → add [DATA-FLOW] type-shape log → `agent-browser console` to verify shape → write rendering code against verified shape → remove log
5. **Verify**: `agent-browser errors` + `agent-browser console`
6. **Interact if needed**: `agent-browser snapshot -i` → click/fill → re-check errors

One feature slice at a time. Don't implement 5 components then check — implement one, verify, next.

## Rule 5: Common Data Flow Bugs and How to Catch Them

**API shape mismatch** (most common):
```bash
# Compare what backend sends vs what frontend expects
agent-browser network requests --filter <endpoint>
# Look for: camelCase vs snake_case, nested vs flat, missing fields
```

**Auth/cookie issues**:
```bash
agent-browser cookies                    # is the token present?
agent-browser network requests --filter auth  # was it sent in the request?
```

**SSE/streaming not connecting**:
```bash
agent-browser console    # connection errors show here
agent-browser network requests --filter stream
```

**State not updating after action**:
```bash
agent-browser eval 'JSON.stringify(Object.keys(window.__NEXT_DATA__?.props || {}))'
agent-browser errors     # look for hydration warnings
```

## For CloudMate Spawn Prompts

Include in every `implement` or `fix` subagent prompt:
```
Read references/data-first-dev.md for implementation methodology.
- Verify API response shapes before writing rendering code.
- Use [DATA-FLOW] type-shape logs (not full payload dumps).
- Verify with `agent-browser errors` after each change.
- Use Context7 before using any library API.
```
