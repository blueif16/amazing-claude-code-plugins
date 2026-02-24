import { useState, useEffect, useRef } from 'react'
import { Sun, Moon, Clock, Flask, FolderOpen, CaretDown, Power, ClockCounterClockwise } from '@phosphor-icons/react'
import type { GoDagState } from '../types'

function formatTimer(startedAt: string, endAt?: string) {
  const s = Math.floor((new Date(endAt || new Date().toISOString()).getTime() - new Date(startedAt).getTime()) / 1000)
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
}

interface Props {
  state: GoDagState | null
  view: 'dag' | 'timeline'
  onViewChange: (v: 'dag' | 'timeline') => void
  dark: boolean
  onToggleDark: () => void
  onLoadFixture: (name: string) => void
  onLoadFile: (file: File) => void
  onLoadRun: (id: string) => void
  error: boolean
}

export function Header({ state, view, onViewChange, dark, onToggleDark, onLoadFixture, onLoadFile, onLoadRun, error }: Props) {
  const [timer, setTimer] = useState('00:00')
  const [showFixtures, setShowFixtures] = useState(false)
  const [showHistory, setShowHistory] = useState(false)
  const [runs, setRuns] = useState<string[]>([])
  const fileRef = useRef<HTMLInputElement>(null)
  useEffect(() => {
    if (!state?.meta.started_at) return
    const update = () => {
      const end = state.meta.status !== 'running' ? state.meta.updated_at : undefined
      setTimer(formatTimer(state.meta.started_at, end))
    }
    update()
    const id = setInterval(update, 1000)
    return () => clearInterval(id)
  }, [state?.meta.started_at, state?.meta.status, state?.meta.updated_at])

  const m = state?.meta
  const c = state?.confidence
  const ids = state ? Object.keys(state.tasks) : []
  const counts = { done: 0, in_progress: 0, blocked: 0, pending: 0, awaiting_human: 0 }
  ids.forEach(id => { const s = state!.tasks[id].status; counts[s === 'done' ? 'done' : s === 'in_progress' ? 'in_progress' : s === 'blocked' ? 'blocked' : s === 'awaiting_human' ? 'awaiting_human' : 'pending']++ })
  const total = ids.length || 1
  const confCls = (c?.score ?? 0) >= 80 ? 'bg-ok' : (c?.score ?? 0) >= 60 ? 'bg-warn' : 'bg-danger'
  const btnBase = 'px-2 py-1 text-[11px] border border-edge-2 bg-surf-2 text-ink-3 rounded-md hover:bg-accent-d hover:text-accent hover:border-accent/30 transition-all'
  return (
    <>
      {error && <div className="bg-danger/90 text-white text-center text-[11px] font-medium py-1.5 tracking-wide">Connection lost — server may be down</div>}
      <header className="px-4 py-2 bg-surf-1 border-b border-edge-2 flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-2 text-[14px] font-bold tracking-tight whitespace-nowrap">
          <div className="w-3 h-3 bg-accent rotate-45 rounded-[2px] shrink-0 opacity-90" />GoDag
        </div>

        {m && <span className="px-1.5 py-0.5 rounded text-[9px] font-semibold uppercase tracking-wider bg-accent-d text-accent/80 border border-accent/10">{m.intent_type}</span>}
        {m && <span className={`px-1.5 py-0.5 rounded text-[9px] font-semibold uppercase tracking-wider border ${
          m.status === 'running' ? 'bg-ok-d text-ok/80 border-ok/10' : m.status === 'complete' ? 'bg-ok-d text-ok/80 border-ok/10' : 'bg-danger-d text-danger/80 border-danger/10'
        }`}>{m.status}</span>}

        <div className="flex-1 min-w-[140px] flex items-center gap-2">
          <div className="flex-1 h-1 bg-surf-3 rounded-full overflow-hidden flex">
            <div className="h-full bg-ok/80 transition-all duration-700 ease-out" style={{ width: `${counts.done / total * 100}%` }} />
            <div className="h-full bg-accent/70 transition-all duration-700 ease-out" style={{ width: `${counts.in_progress / total * 100}%` }} />
            <div className="h-full bg-warn/70 transition-all duration-700 ease-out" style={{ width: `${counts.awaiting_human / total * 100}%` }} />
            <div className="h-full bg-warn/30 transition-all duration-700 ease-out" style={{ width: `${counts.blocked / total * 100}%` }} />
          </div>
          <span className="text-[10px] text-ink-3 font-medium tabular-nums whitespace-nowrap">{counts.done}/{total}{counts.in_progress ? ` · ${counts.in_progress} active` : ''}{counts.awaiting_human ? ` · ${counts.awaiting_human} gated` : ''}</span>
        </div>
        {c && (
          <div className="text-[10px] text-ink-2 flex items-center gap-1.5 group relative cursor-default">
            <div className={`w-1.5 h-1.5 rounded-full ${confCls}`} /><span className="tabular-nums">{c.score}%</span>
            <div className="hidden group-hover:block absolute top-full right-0 mt-2 bg-surf-2 border border-edge-2 rounded-lg p-3 text-[10px] whitespace-nowrap z-50 shadow-[0_8px_24px_rgba(0,0,0,0.2)]">
              {[['Pass Rate', c.signals.acceptance_pass_rate != null ? (c.signals.acceptance_pass_rate * 100).toFixed(0) + '%' : '-'],
                ['Retries', c.signals.retry_count ?? '-'], ['Lint', c.signals.lint_clean == null ? '-' : c.signals.lint_clean ? 'Clean' : 'Issues'],
                ['Tests', c.signals.has_tests == null ? '-' : c.signals.has_tests ? 'Yes' : 'No'], ['Escalations', c.signals.escalation_count ?? '-'],
              ].map(([k, v]) => <div key={k as string} className="flex justify-between gap-6 py-0.5 text-ink-3"><span>{k}</span><span className="text-ink-2 font-medium">{v}</span></div>)}
            </div>
          </div>
        )}

        <span className="text-[10px] text-ink-3 font-mono font-medium tabular-nums"><Clock size={10} weight="light" className="inline -mt-px mr-1 opacity-60" />{timer}</span>

        <div className="flex gap-px bg-surf-3 rounded-md p-0.5">
          {(['dag', 'timeline'] as const).map(v => (
            <button key={v} onClick={() => onViewChange(v)} className={`px-2.5 py-1 text-[10px] font-semibold rounded transition-all ${view === v ? 'bg-surf-1 text-ink shadow-sm' : 'text-ink-3 hover:text-ink-2'}`}>
              {v === 'dag' ? 'DAG' : 'Timeline'}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-1 ml-auto">
          <button onClick={() => setShowFixtures(!showFixtures)} className={`${btnBase} flex items-center gap-1`}>
            <Flask size={11} />Fixtures<CaretDown size={9} weight="bold" className={`transition-transform ${showFixtures ? 'rotate-180' : ''}`} />
          </button>
          <button onClick={async () => { if (!showHistory) { const r = await fetch('/runs?' + Date.now()).then(r => r.json()).catch(() => []); setRuns(r) } setShowHistory(!showHistory) }} className={`${btnBase} flex items-center gap-1`}>
            <ClockCounterClockwise size={11} />History<CaretDown size={9} weight="bold" className={`transition-transform ${showHistory ? 'rotate-180' : ''}`} />
          </button>
          <button onClick={() => fileRef.current?.click()} className={btnBase}><FolderOpen size={11} /></button>
          <input ref={fileRef} type="file" accept=".json" className="hidden" onChange={e => { const f = e.target.files?.[0]; if (f) onLoadFile(f); e.target.value = '' }} />
          <button onClick={onToggleDark} className={btnBase}>{dark ? <Sun size={11} /> : <Moon size={11} />}</button>
          <button onClick={() => { if (confirm('Stop dashboard server?')) fetch('/stop', { method: 'POST' }) }} className={`${btnBase} hover:!bg-danger-d hover:!text-danger hover:!border-danger/30`}><Power size={11} weight="bold" /></button>
        </div>
      </header>
      {showFixtures && (
        <div className="px-4 py-1.5 bg-surf-2 border-b border-edge flex gap-2 items-center text-[10px] text-ink-3">
          <Flask size={11} className="opacity-50" />
          {['fanout-running', 'fanout-complete', 'linear-running'].map(fx => (
            <button key={fx} onClick={() => onLoadFixture(fx)} className="px-2 py-0.5 text-[10px] border border-edge-2 bg-surf-1 text-ink-3 rounded hover:bg-accent-d hover:text-accent hover:border-accent/30 transition-all">{fx}</button>
          ))}
        </div>
      )}
      {showHistory && (
        <div className="px-4 py-1.5 bg-surf-2 border-b border-edge flex gap-2 items-center text-[10px] text-ink-3 flex-wrap">
          <ClockCounterClockwise size={11} className="opacity-50" />
          {runs.length === 0 && <span className="text-ink-m">No archived runs</span>}
          {runs.map(id => (
            <button key={id} onClick={() => { onLoadRun(id); setShowHistory(false) }} className="px-2 py-0.5 text-[10px] border border-edge-2 bg-surf-1 text-ink-3 rounded hover:bg-accent-d hover:text-accent hover:border-accent/30 transition-all font-mono tabular-nums">{id}</button>
          ))}
        </div>
      )}
    </>
  )
}
