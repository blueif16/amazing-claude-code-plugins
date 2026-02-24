import { useState, useEffect, useRef, useCallback } from 'react'
import type { GoDagState, LogEvent } from '../types'

export function useGoDagState() {
  const [state, setState] = useState<GoDagState | null>(null)
  const [events, setEvents] = useState<LogEvent[]>([])
  const [error, setError] = useState(false)
  const [manual, setManual] = useState(false)
  const prevRef = useRef<Record<string, string>>({})
  const [transitions, setTransitions] = useState<Record<string, 'done' | 'fail'>>({})

  const poll = useCallback(async () => {
    if (manual) return
    try {
      const res = await fetch('/state.json?' + Date.now())
      const data: GoDagState = await res.json()
      // detect transitions
      const newTrans: Record<string, 'done' | 'fail'> = {}
      for (const [id, t] of Object.entries(data.tasks)) {
        const prev = prevRef.current[id]
        if (prev && prev !== 'done' && t.status === 'done') {
          newTrans[id] = t.acceptance_passed !== false ? 'done' : 'fail'
        }
      }
      if (Object.keys(newTrans).length) {
        setTransitions(prev => ({ ...prev, ...newTrans }))
        setTimeout(() => setTransitions(prev => {
          const next = { ...prev }
          for (const id of Object.keys(newTrans)) delete next[id]
          return next
        }), 1200)
      }
      prevRef.current = Object.fromEntries(Object.entries(data.tasks).map(([id, t]) => [id, t.status]))
      setState(data)
      setError(false)
    } catch { setError(true) }
    try {
      const res = await fetch('/log.jsonl?' + Date.now())
      const text = await res.text()
      const lines = text.trim().split('\n').filter(Boolean)
      setEvents(lines.map(l => { try { return JSON.parse(l) } catch { return null } }).filter(Boolean) as LogEvent[])
    } catch {}
  }, [manual])

  useEffect(() => {
    poll()
    const id = setInterval(poll, state?.tasks && Object.values(state.tasks).some(t => t.status === 'in_progress') ? 1500 : 4000)
    return () => clearInterval(id)
  }, [poll, state?.meta?.status])

  const loadFixture = useCallback(async (name: string) => {
    const res = await fetch(`/fixtures/${name}.json?` + Date.now())
    if (!res.ok) throw new Error('Fixture not found')
    setManual(true)
    setState(await res.json())
    setEvents([])
  }, [])

  const loadFile = useCallback((file: File) => {
    const reader = new FileReader()
    reader.onload = e => {
      setManual(true)
      setState(JSON.parse(e.target!.result as string))
      setEvents([])
    }
    reader.readAsText(file)
  }, [])

  const loadRun = useCallback(async (id: string) => {
    const res = await fetch(`/runs/${id}/state.json?` + Date.now())
    if (!res.ok) throw new Error('Run not found')
    setManual(true)
    setState(await res.json())
    try {
      const logRes = await fetch(`/runs/${id}/log.jsonl?` + Date.now())
      const text = await logRes.text()
      const lines = text.trim().split('\n').filter(Boolean)
      setEvents(lines.map(l => { try { return JSON.parse(l) } catch { return null } }).filter(Boolean) as LogEvent[])
    } catch { setEvents([]) }
  }, [])

  return { state, events, error, transitions, loadFixture, loadFile, loadRun, manual }
}
