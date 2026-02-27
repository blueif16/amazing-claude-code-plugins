#!/usr/bin/env node
// GoDag Dashboard Server — zero dependencies
// Serves dashboard static files + .godag data + state transition API
import { createServer } from 'node:http'
import { readFile, readdir, writeFile, appendFile, mkdir } from 'node:fs/promises'
import { join, extname } from 'node:path'
import { existsSync } from 'node:fs'

const MIME = {
  '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
  '.json': 'application/json', '.jsonl': 'text/plain', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.woff2': 'font/woff2',
}
const godagDir = process.env.GODAG_DIR || process.cwd()
const distDir = new URL('./dist', import.meta.url).pathname
const port = parseInt(process.env.PORT || '4567', 10)
const DATA_FILES = new Set(['state.json', 'log.jsonl'])
const HEADERS = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }

// ── Helpers ──────────────────────────────────────────────────────────

const stateFile = join(godagDir, 'state.json')
const logFile = join(godagDir, 'log.jsonl')
const now = () => new Date().toISOString()

async function readState() {
  return JSON.parse(await readFile(stateFile, 'utf-8'))
}

async function writeState(data) {
  data.meta.updated_at = now()
  await writeFile(stateFile, JSON.stringify(data, null, 2))
}

async function log(event, data) {
  const line = JSON.stringify({ ts: now(), event, data })
  await appendFile(logFile, line + '\n').catch(() => {})
}

async function readBody(req) {
  const chunks = []
  for await (const chunk of req) chunks.push(chunk)
  return JSON.parse(Buffer.concat(chunks).toString())
}

function ok(res, extra) {
  res.writeHead(200, HEADERS)
  res.end(JSON.stringify({ ok: true, ...extra }))
}

function err(res, code, msg) {
  res.writeHead(code, HEADERS)
  res.end(JSON.stringify({ error: msg }))
}

// ── Confidence calculation ───────────────────────────────────────────

function recalcConfidence(data) {
  const tasks = Object.values(data.tasks)
  const done = tasks.filter(t => t.status === 'done')
  const total = tasks.filter(t => t.status !== 'cancelled')

  if (total.length === 0) {
    data.confidence = { score: 0, level: 'low', signals: {} }
    return
  }

  const acceptPass = done.filter(t => t.acceptance_passed === true).length
  const acceptTotal = done.filter(t => t.acceptance_passed !== null).length
  const acceptRate = acceptTotal > 0 ? acceptPass / acceptTotal : 0

  const retries = tasks.reduce((sum, t) => sum + (t.retries || 0), 0)
  const retryScore = retries === 0 ? 1 : retries <= 2 ? 0.5 : 0

  const escalations = tasks.filter(t => (t.issues?.length || 0) > 0).length
  const escalationScore = escalations === 0 ? 1 : 0.5

  const score = Math.round(
    acceptRate * 40 +
    retryScore * 20 +
    escalationScore * 10 +
    // lint_clean and has_tests left at 0 — filled by acceptance checks
    30 * (done.length / total.length) // proxy for progress
  )

  data.confidence = {
    score,
    level: score >= 80 ? 'high' : score >= 60 ? 'medium' : 'low',
    signals: {
      acceptance_pass_rate: acceptTotal > 0 ? Math.round(acceptRate * 100) : 0,
      retry_count: retries,
      lint_clean: null,
      has_tests: null,
      escalation_count: escalations,
    },
  }
}

// ── Downstream unblock ───────────────────────────────────────────────

function unblockDownstream(data, completedId) {
  const dagTasks = data.dag.tasks
  for (const dt of dagTasks) {
    if (!dt.blocked_by?.includes(completedId)) continue
    const allDone = dt.blocked_by.every(dep => {
      const s = data.tasks[dep]?.status
      return s === 'done' || s === 'cancelled'
    })
    if (!allDone) continue
    const rt = data.tasks[dt.id]
    if (!rt || rt.status !== 'blocked') continue
    rt.status = dt.hitl ? 'awaiting_human' : 'pending'
    log(dt.hitl ? 'hitl_waiting' : 'task_unblocked', { task: dt.id })
  }
}

// ── Check session completeness ───────────────────────────────────────

function checkComplete(data) {
  const statuses = Object.values(data.tasks).map(t => t.status)
  const active = statuses.some(s => s === 'pending' || s === 'blocked' || s === 'in_progress' || s === 'awaiting_human')
  if (!active) {
    const allPassed = Object.values(data.tasks)
      .filter(t => t.status === 'done')
      .every(t => t.acceptance_passed !== false)
    data.meta.status = allPassed ? 'complete' : 'failed'
    log('session_complete', { status: data.meta.status, confidence: data.confidence.score })
  }
}

// ── State transition endpoints ───────────────────────────────────────

const stateRoutes = {

  // POST /state/init — initialize a fresh run
  // Body: { meta: {...}, dag: {...} }
  // Server handles: timestamps, task runtime map, confidence init, session_start log
  async init(body, res) {
    const ts = now()
    const meta = { ...body.meta, started_at: ts, updated_at: ts, status: 'running' }
    const dag = body.dag

    // Build runtime task map from dag definition
    const tasks = {}
    for (const dt of dag.tasks) {
      const isBlocked = dt.blocked_by && dt.blocked_by.length > 0
      tasks[dt.id] = {
        status: isBlocked ? 'blocked' : 'pending',
        agent: null, started_at: null, completed_at: null, duration_s: null,
        acceptance_passed: null, acceptance_output: null,
        summary: null, decisions: [], issues: [], retries: 0, files_changed: [],
      }
    }

    const data = {
      $schema: 'godag/v2.1', meta, dag, tasks,
      confidence: { score: 0, level: 'low', signals: { acceptance_pass_rate: 0, retry_count: 0, lint_clean: null, has_tests: null, escalation_count: 0 } },
      dashboard: { server_pid: process.pid, port, url: `http://localhost:${port}` },
    }

    await writeState(data)
    await log('session_start', { project: meta.project, level: meta.level })
    ok(res, { started_at: ts })
  },

  // POST /state/start — mark task in_progress
  // Body: { task: "T1", agent: "godag:frontend-dev" }
  async start(body, res) {
    const data = await readState()
    const rt = data.tasks[body.task]
    if (!rt) return err(res, 404, `Task ${body.task} not found`)

    const ts = now()
    rt.status = 'in_progress'
    rt.started_at = ts
    rt.agent = body.agent || null

    await writeState(data)
    await log('task_started', { task: body.task, agent: rt.agent })
    ok(res, { started_at: ts })
  },

  // POST /state/done — mark task done, compute timing, unblock downstream
  // Body: { task: "T1", summary: "...", files_changed: [...], decisions: [...], issues: [...],
  //         acceptance_passed: true|false|null, acceptance_output: "..." }
  async done(body, res) {
    const data = await readState()
    const rt = data.tasks[body.task]
    if (!rt) return err(res, 404, `Task ${body.task} not found`)

    const ts = now()
    rt.status = 'done'
    rt.completed_at = ts
    rt.duration_s = rt.started_at ? Math.round((new Date(ts) - new Date(rt.started_at)) / 1000) : null
    rt.summary = body.summary || null
    rt.files_changed = body.files_changed || []
    rt.decisions = body.decisions || []
    rt.issues = body.issues || []

    if (body.acceptance_passed !== undefined) {
      rt.acceptance_passed = body.acceptance_passed
      rt.acceptance_output = body.acceptance_output || null
    }

    // Log file changes
    for (const f of rt.files_changed) {
      await log('file_changed', { task: body.task, file: f })
    }
    await log('task_done', {
      task: body.task, duration_s: rt.duration_s,
      acceptance: rt.acceptance_passed === true ? 'pass' : rt.acceptance_passed === false ? 'fail' : 'skipped',
      summary: rt.summary,
    })

    unblockDownstream(data, body.task)
    recalcConfidence(data)
    checkComplete(data)
    await writeState(data)
    ok(res, { completed_at: ts, duration_s: rt.duration_s })
  },

  // POST /state/cancel — cancel pending/blocked tasks
  // Body: { task: "T5" } or { tasks: ["T5", "T6"] }
  async cancel(body, res) {
    const data = await readState()
    const ids = body.tasks || [body.task]
    const cancelled = []

    for (const id of ids) {
      const rt = data.tasks[id]
      if (!rt) continue
      if (rt.status === 'done' || rt.status === 'in_progress') continue // can't cancel done/running
      rt.status = 'cancelled'
      rt.completed_at = now()
      cancelled.push(id)
      await log('task_cancelled', { task: id })
      unblockDownstream(data, id) // cancelled counts as "resolved" for downstream
    }

    recalcConfidence(data)
    checkComplete(data)
    await writeState(data)
    ok(res, { cancelled })
  },

  // POST /state/retry — bump retry count, reset to in_progress
  // Body: { task: "T1", reason: "acceptance failed: ..." }
  async retry(body, res) {
    const data = await readState()
    const rt = data.tasks[body.task]
    if (!rt) return err(res, 404, `Task ${body.task} not found`)

    const ts = now()
    rt.retries = (rt.retries || 0) + 1
    rt.status = 'in_progress'
    rt.started_at = ts
    rt.acceptance_passed = null
    rt.acceptance_output = null

    await writeState(data)
    await log('task_retry', { task: body.task, retry: rt.retries, reason: body.reason || '' })
    ok(res, { retry: rt.retries, started_at: ts })
  },

  // POST /state/replace — replace a task's definition in-place, keeping all inbound edges
  // Body: { task: "T5", title: "new title", type: "implement", scope: [...], acceptance: "...", agent_role: "...", hitl: false }
  // Only replaces fields provided. Resets runtime state to pending.
  async replace(body, res) {
    const data = await readState()
    const rt = data.tasks[body.task]
    if (!rt) return err(res, 404, `Task ${body.task} not found`)

    // Update DAG definition fields
    const dt = data.dag.tasks.find(t => t.id === body.task)
    if (!dt) return err(res, 404, `Task ${body.task} not in DAG`)

    const prev = { title: dt.title, type: dt.type }
    if (body.title !== undefined) dt.title = body.title
    if (body.type !== undefined) dt.type = body.type
    if (body.scope !== undefined) dt.scope = body.scope
    if (body.acceptance !== undefined) dt.acceptance = body.acceptance
    if (body.estimated_complexity !== undefined) dt.estimated_complexity = body.estimated_complexity
    if (body.agent_role !== undefined) dt.agent_role = body.agent_role
    if (body.hitl !== undefined) dt.hitl = body.hitl

    // Reset runtime state — all inbound edges stay, just re-run this node
    const depsAllDone = (dt.blocked_by || []).every(dep => {
      const s = data.tasks[dep]?.status
      return s === 'done' || s === 'cancelled'
    })
    rt.status = depsAllDone ? 'pending' : 'blocked'
    rt.agent = null
    rt.started_at = null
    rt.completed_at = null
    rt.duration_s = null
    rt.acceptance_passed = null
    rt.acceptance_output = null
    rt.summary = null
    rt.decisions = []
    rt.issues = []
    rt.retries = 0
    rt.files_changed = []

    // Session back to running
    if (data.meta.status !== 'running') data.meta.status = 'running'

    recalcConfidence(data)
    await writeState(data)
    await log('task_replaced', { task: body.task, prev_title: prev.title, new_title: dt.title })
    ok(res, { task: body.task, status: rt.status })
  },

  // POST /state/append — add new tasks to a living DAG
  // Body: { tasks: [{ id:"T6", title:"...", type:"...", scope:[...], blocked_by:[], acceptance:"...", ... }] }
  async append(body, res) {
    const data = await readState()
    const added = []

    for (const dt of (body.tasks || [])) {
      // Add to dag definition
      data.dag.tasks.push(dt)
      // Add edges
      for (const dep of (dt.blocked_by || [])) {
        data.dag.edges.push([dep, dt.id])
      }
      // Add runtime entry
      const isBlocked = dt.blocked_by && dt.blocked_by.length > 0
      const depsAllDone = isBlocked && dt.blocked_by.every(dep => {
        const s = data.tasks[dep]?.status
        return s === 'done' || s === 'cancelled'
      })
      data.tasks[dt.id] = {
        status: depsAllDone ? (dt.hitl ? 'awaiting_human' : 'pending') : isBlocked ? 'blocked' : 'pending',
        agent: null, started_at: null, completed_at: null, duration_s: null,
        acceptance_passed: null, acceptance_output: null,
        summary: null, decisions: [], issues: [], retries: 0, files_changed: [],
      }
      added.push(dt.id)
      await log('task_appended', { task: dt.id, blocked_by: dt.blocked_by || [] })
    }

    // Session back to running if it was complete
    if (data.meta.status !== 'running') data.meta.status = 'running'

    recalcConfidence(data)
    await writeState(data)
    ok(res, { added })
  },
}

// ── HTTP handler ─────────────────────────────────────────────────────

async function handler(req, res) {
  const url = new URL(req.url, `http://localhost:${port}`)
  const base = url.pathname.replace(/^\//, '')

  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end()
    return
  }

  // POST /stop — graceful shutdown
  if (req.method === 'POST' && url.pathname === '/stop') {
    ok(res)
    setTimeout(() => process.exit(0), 300)
    return
  }

  // POST /hitl — toggle gate or approve (dashboard UI)
  if (req.method === 'POST' && url.pathname === '/hitl') {
    try {
      const body = await readBody(req)
      const data = await readState()
      if (body.action === 'toggle') {
        const dt = data.dag.tasks.find(t => t.id === body.task_id)
        if (dt) dt.hitl = !dt.hitl
      } else if (body.action === 'approve') {
        if (data.tasks[body.task_id]?.status === 'awaiting_human') {
          data.tasks[body.task_id].status = 'pending'
          await log('hitl_approved', { task: body.task_id })
        }
      }
      await writeState(data)
      ok(res)
    } catch (e) { err(res, 500, String(e)) }
    return
  }

  // POST /state/* — state transition API
  if (req.method === 'POST' && url.pathname.startsWith('/state/')) {
    const action = url.pathname.slice('/state/'.length)
    const route = stateRoutes[action]
    if (!route) return err(res, 404, `Unknown action: ${action}`)
    try {
      const body = await readBody(req)
      await route(body, res)
    } catch (e) { err(res, 500, String(e)) }
    return
  }

  // ── Static / data file serving ──

  let filePath

  if (DATA_FILES.has(base)) {
    filePath = join(godagDir, base)
  } else if (base === 'runs') {
    const runsDir = join(godagDir, 'runs')
    const entries = await readdir(runsDir).catch(() => [])
    const runs = entries.filter(e => existsSync(join(runsDir, e, 'state.json'))).sort().reverse()
    res.writeHead(200, { ...HEADERS, 'Cache-Control': 'no-cache' })
    res.end(JSON.stringify(runs))
    return
  } else if (base.startsWith('runs/')) {
    filePath = join(godagDir, base)
  } else if (base.startsWith('fixtures/')) {
    filePath = join(godagDir, base)
  } else {
    filePath = join(distDir, base || 'index.html')
    if (!existsSync(filePath)) filePath = join(distDir, 'index.html')
  }

  try {
    const data = await readFile(filePath)
    const ext = extname(filePath)
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cache-Control': 'no-cache',
      'Access-Control-Allow-Origin': '*',
    })
    res.end(data)
  } catch {
    res.writeHead(404)
    res.end('Not found')
  }
}

createServer(handler).listen(port, '127.0.0.1', () => {
  console.log(`GoDag Dashboard → http://localhost:${port}`)
})
