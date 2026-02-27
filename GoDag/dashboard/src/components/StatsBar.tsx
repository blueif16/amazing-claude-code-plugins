import { useState, useEffect } from 'react'
import { Clock } from '@phosphor-icons/react'
import type { GoDagState } from '../types'

function formatTimer(startedAt: string, endAt?: string) {
  const s = Math.floor((new Date(endAt || new Date().toISOString()).getTime() - new Date(startedAt).getTime()) / 1000)
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
}

const CARD = 'bg-surf-1 border border-edge-2 rounded-xl p-3 transition-all hover:-translate-y-px hover:shadow-[0_4px_12px_rgba(0,0,0,0.1)]'

interface Props { state: GoDagState | null }

export function StatsBar({ state }: Props) {
  const [timer, setTimer] = useState('00:00')

  useEffect(() => {
    if (!state?.meta.started_at) return
    const hasActive = Object.values(state.tasks).some(t => t.status === 'in_progress')
    const update = () => {
      // Only tick live when tasks are actively running; otherwise freeze at updated_at
      const end = (state.meta.status === 'running' && hasActive) ? undefined : state.meta.updated_at
      setTimer(formatTimer(state.meta.started_at, end))
    }
    update()
    if (state.meta.status === 'running' && hasActive) {
      const id = setInterval(update, 1000)
      return () => clearInterval(id)
    }
  }, [state?.meta.started_at, state?.meta.status, state?.meta.updated_at, state?.tasks])

  const ids = state ? Object.keys(state.tasks) : []
  const counts = { done: 0, in_progress: 0, blocked: 0, pending: 0, awaiting_human: 0 }
  ids.forEach(id => { const s = state!.tasks[id].status; counts[s]++ })
  const total = ids.length
  const done = counts.done
  const pct = total ? (done / total) * 100 : 0
  const c = state?.confidence
  const confCls = (c?.score ?? 0) >= 80 ? 'text-ok' : (c?.score ?? 0) >= 60 ? 'text-warn' : 'text-danger'

  // SVG ring params
  const R = 22, CIRC = 2 * Math.PI * R

  if (!state) return (
    <div className="grid grid-cols-4 gap-3">
      {[0,1,2,3].map(i => <div key={i} className={`${CARD} h-[72px] animate-pulse`} />)}
    </div>
  )
  return (
    <div className="grid grid-cols-4 gap-3">
      {/* Progress Ring */}
      <div className={CARD}>
        <div className="flex items-center gap-3">
          <svg width="52" height="52" viewBox="0 0 52 52" className="shrink-0 -rotate-90">
            <circle cx="26" cy="26" r={R} fill="none" stroke="var(--color-edge-2)" strokeWidth="4" />
            <circle cx="26" cy="26" r={R} fill="none" stroke="var(--color-ok)" strokeWidth="4"
              strokeDasharray={CIRC} strokeDashoffset={CIRC - (CIRC * pct / 100)}
              strokeLinecap="round" className="transition-all duration-700" />
          </svg>
          <div>
            <div className="text-[18px] font-bold text-ink tabular-nums">{done}<span className="text-ink-3 text-[12px] font-normal">/{total}</span></div>
            <div className="text-[9px] text-ink-3 uppercase tracking-wider">Progress</div>
          </div>
        </div>
      </div>

      {/* Task Counts */}
      <div className={CARD}>
        <div className="text-[9px] text-ink-3 uppercase tracking-wider mb-1.5">Tasks</div>
        <div className="grid grid-cols-2 gap-x-3 gap-y-0.5 text-[10px]">
          <span className="flex items-center gap-1"><span className="w-1.5 h-1.5 rounded-full bg-ok" /><span className="text-ink-2">{counts.done} done</span></span>
          <span className="flex items-center gap-1"><span className="w-1.5 h-1.5 rounded-full bg-accent" /><span className="text-ink-2">{counts.in_progress} active</span></span>
          <span className="flex items-center gap-1"><span className="w-1.5 h-1.5 rounded-full bg-ink-m" /><span className="text-ink-2">{counts.pending} pending</span></span>
          <span className="flex items-center gap-1"><span className="w-1.5 h-1.5 rounded-full bg-warn" /><span className="text-ink-2">{counts.blocked + counts.awaiting_human} blocked</span></span>
        </div>
      </div>

      {/* Confidence */}
      <div className={CARD}>
        <div className="text-[9px] text-ink-3 uppercase tracking-wider mb-1">Confidence</div>
        <div className={`text-[20px] font-bold tabular-nums ${confCls}`}>{c?.score ?? '—'}<span className="text-[11px] font-normal">%</span></div>
        {c && <div className="text-[9px] text-ink-3 mt-0.5">Pass {c.signals.acceptance_pass_rate != null ? (c.signals.acceptance_pass_rate * 100).toFixed(0) + '%' : '—'} · Retries {c.signals.retry_count}</div>}
      </div>

      {/* Timer */}
      <div className={CARD}>
        <div className="text-[9px] text-ink-3 uppercase tracking-wider mb-1">Elapsed</div>
        <div className="flex items-center gap-2">
          <Clock size={14} weight="light" className="text-ink-3 opacity-60" />
          <span className="text-[20px] font-mono font-bold text-ink tabular-nums">{timer}</span>
        </div>
        {state.meta.status === 'running' && <div className="text-[9px] text-ok mt-0.5 font-medium">Running</div>}
        {state.meta.status === 'complete' && <div className="text-[9px] text-ok mt-0.5 font-medium">Complete</div>}
        {state.meta.status === 'failed' && <div className="text-[9px] text-danger mt-0.5 font-medium">Failed</div>}
      </div>
    </div>
  )
}

