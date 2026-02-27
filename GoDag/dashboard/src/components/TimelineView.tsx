import type { GoDagState } from '../types'

function formatDuration(sec: number) {
  return `${Math.floor(sec / 60)}m${String(sec % 60).padStart(2, '0')}s`
}

interface Props { state: GoDagState | null; onSelect: (id: string) => void }

export function TimelineView({ state, onSelect }: Props) {
  if (!state) return <div className="flex-1 h-full flex items-center justify-center text-ink-3 text-sm">Waiting for data...</div>

  const start = new Date(state.meta.started_at).getTime()
  const now = Date.now()
  const hasActive = Object.values(state.tasks).some(t => t.status === 'in_progress')
  // When no tasks are actively running, use the latest completed_at as the end
  // instead of Date.now() — prevents the timeline from stretching to infinity
  const lastCompleted = Object.values(state.tasks)
    .filter(t => t.completed_at)
    .reduce((max, t) => Math.max(max, new Date(t.completed_at!).getTime()), start)
  const end = state.meta.status !== 'running'
    ? new Date(state.meta.updated_at).getTime()
    : hasActive ? now : Math.max(lastCompleted, start + 1000)
  const span = Math.max(end - start, 1000)

  const ticks = 5
  const tickMarks = Array.from({ length: ticks + 1 }, (_, i) => {
    const t = new Date(start + span * (i / ticks))
    return { pct: (i / ticks) * 100, label: `${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}` }
  })

  return (
    <div className="flex-1 overflow-auto p-6 flex flex-col gap-0">
      {state.dag.tasks.map(dt => {
        const t = state.tasks[dt.id]
        const cls = t?.status === 'done' ? (t.acceptance_passed !== false ? 'bg-ok-d border border-ok/40' : 'bg-danger-d border border-danger/40')
          : t?.status === 'in_progress' ? 'tl-bar-active border border-accent/30'
          : t?.status === 'awaiting_human' ? 'bg-warn-d border border-warn/40'
          : 'bg-surf-3 border border-dashed border-ink-m/40'
        const opacity = t?.status === 'blocked' ? 'opacity-30' : ''
        let left = 0, width = 0
        if (t?.started_at) {
          left = (new Date(t.started_at).getTime() - start) / span * 100
          const taskEnd = t.completed_at ? new Date(t.completed_at).getTime() : (t.status === 'in_progress' ? now : new Date(t.started_at).getTime())
          width = Math.max((taskEnd - new Date(t.started_at).getTime()) / span * 100, 1)
        }
        const dur = t?.duration_s != null ? formatDuration(t.duration_s) : ''
        return (
          <div key={dt.id} className="flex items-center h-8 cursor-pointer hover:bg-surf-2/40 rounded transition-colors" onClick={() => onSelect(dt.id)}>
            <div className="w-44 shrink-0 text-[10px] font-medium text-ink-2 pr-3 text-right truncate">{dt.id}: {dt.title}</div>
            <div className="flex-1 relative h-4">
              <div className={`absolute h-3.5 top-px rounded-sm transition-all duration-500 ${cls} ${opacity}`} style={{ left: `${left}%`, width: `${width}%`, minWidth: 4 }}>
                {dur && <span className="absolute right-1 top-0 text-[8px] font-mono text-ink-2/70 leading-[14px] tabular-nums">{dur}</span>}
              </div>
            </div>
          </div>
        )
      })}
      {state.meta.status === 'running' && (
        <div className="relative ml-44 h-0">
          <div className="absolute bg-accent/30 w-px" style={{ left: `${(now - start) / span * 100}%`, height: state.dag.tasks.length * 32, top: -state.dag.tasks.length * 32 }} />
        </div>
      )}
      <div className="flex h-5 ml-44 relative border-t border-edge mt-1.5">
        {tickMarks.map((t, i) => <span key={i} className="absolute top-1.5 text-[8px] font-mono text-ink-m tabular-nums" style={{ left: `${t.pct}%` }}>{t.label}</span>)}
      </div>
    </div>
  )
}
