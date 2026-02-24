#!/usr/bin/env node
// Minimal static server — zero dependencies, serves dashboard + .godag data
import { createServer } from 'node:http'
import { readFile, readdir } from 'node:fs/promises'
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

  // POST /stop — graceful shutdown
  if (req.method === 'POST' && url.pathname === '/stop') {
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' })
    res.end('{"ok":true}')
    setTimeout(() => process.exit(0), 300)
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
