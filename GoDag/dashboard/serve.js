#!/usr/bin/env node
// Minimal static server — zero dependencies, serves dashboard + .godag data
import { createServer } from 'node:http'
import { readFile, readdir, writeFile, appendFile } from 'node:fs/promises'
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
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' })
    res.end('{"ok":true}')
    setTimeout(() => process.exit(0), 300)
    return
  }

  // POST /hitl — toggle gate or approve
  if (req.method === 'POST' && url.pathname === '/hitl') {
    const chunks = []
    for await (const chunk of req) chunks.push(chunk)
    const body = JSON.parse(Buffer.concat(chunks).toString())
    const stateFile = join(godagDir, 'state.json')
    const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
    try {
      const data = JSON.parse(await readFile(stateFile, 'utf-8'))
      if (body.action === 'toggle') {
        const dt = data.dag.tasks.find(t => t.id === body.task_id)
        if (dt) dt.hitl = !dt.hitl
      } else if (body.action === 'approve') {
        if (data.tasks[body.task_id]?.status === 'awaiting_human') {
          data.tasks[body.task_id].status = 'pending'
          const logFile = join(godagDir, 'log.jsonl')
          const event = JSON.stringify({ ts: new Date().toISOString(), event: 'hitl_approved', data: { task: body.task_id } })
          await appendFile(logFile, event + '\n').catch(() => {})
        }
      }
      data.meta.updated_at = new Date().toISOString()
      await writeFile(stateFile, JSON.stringify(data, null, 2))
      res.writeHead(200, headers)
      res.end('{"ok":true}')
    } catch (e) {
      res.writeHead(500, headers)
      res.end(JSON.stringify({ error: String(e) }))
    }
    return
  }

  let filePath

  if (DATA_FILES.has(base)) {
    filePath = join(godagDir, base)
  } else if (base === 'runs') {
    // List archived runs
    const runsDir = join(godagDir, 'runs')
    const entries = await readdir(runsDir).catch(() => [])
    const runs = entries.filter(e => existsSync(join(runsDir, e, 'state.json'))).sort().reverse()
    const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-cache', 'Access-Control-Allow-Origin': '*' }
    res.writeHead(200, headers)
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
