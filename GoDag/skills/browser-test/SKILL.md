---
name: browser-test
description: "Generate Playwright test scripts for browser-based acceptance verification. Load when DAG tasks touch UI, routes, or user-facing API responses."
---

# Browser Test — From Acceptance Criteria to Playwright Scripts

## When This Skill Activates

A task needs `browser_acceptance` when its scope touches:
- UI components, pages, layouts, forms
- Routes or navigation (frontend or API endpoints returning HTML)
- User-visible behavior (toasts, modals, redirects, error states)
- API responses that the frontend consumes (verify the contract end-to-end)

Tasks that are pure backend (DB migrations, config, internal services) do NOT need browser testing.

## browser_acceptance Format

Add to any DAG task alongside the CLI `acceptance` field:

```json
{
  "browser_acceptance": {
    "dev_server": "npm run dev",
    "base_url": "http://localhost:3000",
    "tests": [
      {
        "name": "Google OAuth button visible and clickable",
        "steps": [
          "Navigate to /login",
          "Verify a button containing 'Google' is visible",
          "Click the button",
          "Verify URL changes to contain '/oauth'"
        ],
        "assertions": [
          "No console errors on page load",
          "No failed network requests to /api/* endpoints"
        ]
      }
    ]
  }
}
```

### Rules

1. **Steps are natural language, not selectors.** Generated Playwright uses `getByRole`, `getByText`, accessibility tree. Never hardcode CSS selectors — this makes tests resilient to UI changes.
2. **Keep tests minimal.** 1-3 tests per task, 2-5 steps each. Test the acceptance criteria, not the entire app.
3. **Always include console/network assertions.** Even if the UI looks right, runtime errors indicate broken code.
4. **Inherit project defaults from `.godag/quality.md`** if it exists. Only specify per-task overrides.

## Quality Bar File (Optional)

If `.godag/quality.md` exists in the project root, read it during DAG generation for project-wide defaults:

```markdown
# Quality Bars
## Dev Server
- Command: `npm run dev`
- Port: 3000
- Ready signal: "ready in" or "Local:" in stdout

## Browser Defaults
- No console errors on any page
- All /api/* calls return 2xx
- No horizontal overflow at 375px viewport

## Code Quality
- `tsc --noEmit` clean
- `npm run lint` clean
```

When generating `browser_acceptance`, inherit these defaults. Only add task-specific assertions for behavior unique to that task.

## Playwright Script Generation

The orchestrator generates `.godag/tests/{task_id}.spec.ts` before running. Template:

```typescript
import { test, expect } from '@playwright/test';

test.describe('{task_id}: {task_title}', () => {
  let consoleErrors: string[] = [];

  test.beforeEach(async ({ page }) => {
    consoleErrors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
  });

  test('{test_name}', async ({ page }) => {
    await page.goto('{path}');

    // Natural language steps → Playwright locators:
    // "Verify button 'Sign in' visible" →
    await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible();
    // "Click the button" →
    await page.getByRole('button', { name: /sign in/i }).click();
    // "Verify URL contains '/dashboard'" →
    await expect(page).toHaveURL(/dashboard/);

    // Console error assertion (always appended)
    expect(consoleErrors).toEqual([]);
  });
});
```

### Playwright Config

Generate `.godag/tests/playwright.config.ts` once per run if absent:

```typescript
import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: '.',
  timeout: 30000,
  retries: 0,
  use: {
    baseURL: '{base_url}',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    video: 'off',
  },
  reporter: [
    ['json', { outputFile: '../context/{task_id}-results.json' }]
  ],
});
```

Screenshots on failure land in `test-results/` automatically. JSON reporter writes to `.godag/context/`. Traces retained for deep debugging.

### Running

```bash
cd .godag/tests && npx playwright test {task_id}.spec.ts \
  --config=playwright.config.ts 2>&1 | tail -20
```

Exit code 0 = pass, non-zero = fail. Orchestrator checks exit code only, then spawns summarizer.

## Summarizer Subagent

After Playwright runs, orchestrator spawns a **disposable** Task-tool subagent to distill results. This keeps verbose JSON + screenshots out of the orchestrator's context.

### Spawn Prompt

```
你是测试结果分析器。读取 Playwright 结果，生成简洁判定。

## 输入
- JSON: .godag/context/{task_id}-results.json
- 截图: .godag/tests/test-results/ (如有)

## 输出
写入 .godag/context/{task_id}-verdict.md：

# {task_id} Browser Verdict — PASS/FAIL

## Results
1. ✅/❌ [test name]: [one line]

## Failures (only if failed)
- Error: [message, max 2 lines]
- Location: [first line of stack]
- Screenshot: [path]

## Console Issues (if any)
- [message, truncated to 100 chars]

## Root Cause Guess
[one sentence]

---
上限 30 行。只报告关键信息。

返回：
\```godag-result
{"task_id":"{task_id}-verify","summary":"PASS/FAIL: one line","acceptance_passed":true/false}
\```
```

### What the Orchestrator Sees

Only the godag-result: ~30 tokens. The verdict.md stays on disk for the retry agent.

## Retry Flow

When browser verification fails, the retry implementation subagent gets:

```
你之前完成了 {task_id}，但浏览器验证失败。

## 上次工作摘要
{summary from original godag-result}

## 失败详情
读取 .godag/context/{task_id}-verdict.md 了解具体问题。
截图在 .godag/tests/test-results/ (如有)。

修复 verdict.md 中列出的所有失败项。
```

Retry agent reads verdict in its own fresh context. Never sees raw JSON or orchestrator reasoning.

## Dev Server Management

Before first browser test:

```bash
if ! curl -sf {base_url} > /dev/null 2>&1; then
  {dev_server_command} > .godag/.devserver.log 2>&1 &
  echo $! > .godag/.devserver.pid
  for i in $(seq 1 30); do
    curl -sf {base_url} > /dev/null 2>&1 && break
    sleep 1
  done
fi
```

After all tasks complete:

```bash
[ -f .godag/.devserver.pid ] && kill $(cat .godag/.devserver.pid) 2>/dev/null && rm .godag/.devserver.pid
```

## Prerequisites Check

Before generating any test:

```bash
npx playwright --version 2>/dev/null
```

If absent: `"Browser testing 需要 Playwright。安装: npm init playwright@latest"`

Skip `browser_acceptance` gracefully if unavailable — fall back to CLI-only acceptance.
