import { useRef, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { RocketLaunch, MapTrifold, SealCheck, ChartBar, Play, Check, ArrowCounterClockwise, LockOpen, PencilSimple, Flag, Power, Copy, HandPalm, UserCircle } from '@phosphor-icons/react'
import type { GoDagState, LogEvent } from '../types'

const EV_ICONS: Record<string, typeof RocketLaunch> = {
  session_start: RocketLaunch, plan_generated: MapTrifold, user_confirmed: SealCheck, dashboard_started: ChartBar,
  task_started: Play, task_done: Check, task_retry: ArrowCounterClockwise, task_unblocked: LockOpen,
  file_changed: PencilSimple, session_complete: Flag, dashboard_stopped: Power,
  hitl_waiting: HandPalm, hitl_approved: UserCircle,
}
const EV_COLORS: Record<string, string> = {
  task_done: 'text-ok', task_retry: 'text-warn', task_started: 'text-accent',
  session_complete: 'text-ok', file_changed: 'text-ink-3',
  hitl_waiting: 'text-warn', hitl_approved: 'text-ok',
}

function relTime(ts: string) {
  const d = Math.floor((Date.now() - new Date(ts).getTime()) / 1000)
  if (d < 60) return d + 's'
  if (d < 3600) return Math.floor(d / 60) + 'm'
  return Math.floor(d / 3600) + 'h'
}
function humanize(e: LogEvent, state: GoDagState | null) {
  const d = e.data || {}
  const taskTitle = (id: string) => state?.dag.tasks.find(t => t.id === id)?.title || ''
  switch (e.event) {
    case 'session_start': return <><b>{String(d.project || '-')}</b> started (Level {String(d.level || '?')})</>
    case 'plan_generated': return <>Plan generated — {String(d.tasks || '?')} tasks, {String(d.strategy || '?')}</>
    case 'user_confirmed': return <>User confirmed</>
    case 'task_started': return <><b>{String(d.task)}</b> started{taskTitle(String(d.task)) ? ` — ${taskTitle(String(d.task))}` : ''}</>
    case 'task_done': return <><b>{String(d.task)}</b> done{d.duration_s ? ` (${Math.floor(Number(d.duration_s) / 60)}m${Number(d.duration_s) % 60}s)` : ''}{d.acceptance === 'pass' ? ' pass' : d.acceptance === 'fail' ? ' fail' : ''}</>
    case 'task_retry': return <><b>{String(d.task)}</b> retry #{String(d.attempt || '?')}</>
    case 'task_unblocked': return <><b>{String(d.task)}</b> unblocked{taskTitle(String(d.task)) ? ` — ${taskTitle(String(d.task))}` : ''}</>
    case 'file_changed': return <>{String(d.file || '?')} modified{d.task ? ` (${String(d.task)})` : ''}</>
    case 'session_complete': return <>Session complete — confidence {state?.confidence?.score || '?'}%</>
    case 'hitl_waiting': return <><b>{String(d.task)}</b> awaiting human approval</>
    case 'hitl_approved': return <><b>{String(d.task)}</b> approved by human</>
    default: return <>{e.event}</>
  }
}
function DetailPanel({ state, taskId, onApproveHitl }: { state: GoDagState; taskId: string; onApproveHitl?: (id: string) => void }) {
  const dt = state.dag.tasks.find(t => t.id === taskId)
  const ts = state.tasks[taskId]
  if (!dt || !ts) return null
  const statusLabel = ts.status === 'done' ? (ts.acceptance_passed !== false ? 'Passed' : 'Failed') : ts.status === 'awaiting_human' ? 'Awaiting approval' : ts.status
  const scope = Array.isArray(dt.scope) ? dt.scope : [dt.scope]

  return (
    <div className="border-t border-edge-2 max-h-[55%] overflow-y-auto p-3 bg-surf-1">
      <h3 className="text-[12px] font-semibold mb-2.5 text-ink">{dt.id}: {dt.title}</h3>
      <div className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-[10px] mb-2.5">
        <span className="text-ink-3">Type</span><span className="text-ink-2">{dt.type}</span>
        <span className="text-ink-3">Complexity</span><span className="text-ink-2">{dt.estimated_complexity}</span>
        <span className="text-ink-3">Status</span><span className="text-ink-2">{statusLabel}{ts.agent ? ` · ${ts.agent}` : ''}</span>
        <span className="text-ink-3">Role</span><span className="text-ink-2">{dt.agent_role}</span>
        {dt.hitl && <><span className="text-ink-3">Gate</span><span className="text-warn font-semibold">HITL enabled</span></>}
        {ts.retries > 0 && <><span className="text-ink-3">Retries</span><span className="text-warn">{ts.retries}</span></>}
        {ts.duration_s != null && <><span className="text-ink-3">Duration</span><span className="text-ink-2 font-mono tabular-nums">{Math.floor(ts.duration_s / 60)}m{String(ts.duration_s % 60).padStart(2, '0')}s</span></>}
      </div>
      <Section label="Scope"><span className="text-[10px] text-ink-2">{scope.join(', ')}</span></Section>
      {ts.files_changed?.length > 0 && (
        <Section label="Files Changed">
          <ul className="text-[10px] text-ink-2 space-y-0.5">{ts.files_changed.map(f => <li key={f} className="flex items-center gap-1"><PencilSimple size={9} weight="light" className="text-ink-m shrink-0" />{f}</li>)}</ul>
        </Section>
      )}
      {ts.summary && <Section label="Summary"><div className="text-[10px] text-ink-2 leading-relaxed">{ts.summary}</div></Section>}
      {ts.decisions?.length > 0 && (
        <Section label="Decisions">
          <ul className="text-[10px] text-ink-2 space-y-0.5">{ts.decisions.map((d, i) => <li key={i} className="leading-relaxed">· {d}</li>)}</ul>
        </Section>
      )}
      {ts.issues?.length > 0 && (
        <Section label="Issues">
          <ul className="text-[10px] text-danger/80 space-y-0.5">{ts.issues.map((d, i) => <li key={i} className="leading-relaxed">· {d}</li>)}</ul>
        </Section>
      )}
      <div className="mt-2.5">
        <div className="text-[9px] font-semibold text-ink-3 uppercase tracking-wider mb-1 flex items-center gap-1.5">
          Acceptance
          <button onClick={() => navigator.clipboard.writeText(dt.acceptance)} className="text-[9px] px-1.5 py-px bg-surf-3 border border-edge-2 rounded text-ink-m hover:text-accent hover:border-accent/30 transition-colors"><Copy size={8} weight="regular" className="inline -mt-px" /></button>
        </div>
        <pre className="text-[10px] font-mono bg-canvas text-ink-2 p-2 rounded border border-edge overflow-x-auto whitespace-pre-wrap leading-relaxed">{dt.acceptance}</pre>
      </div>
      {ts.acceptance_output && <Section label="Output"><pre className="text-[10px] font-mono bg-canvas text-ink-2 p-2 rounded border border-edge overflow-x-auto whitespace-pre-wrap leading-relaxed">{ts.acceptance_output}</pre></Section>}
      {ts.status === 'awaiting_human' && onApproveHitl && (
        <div className="mt-3">
          <button onClick={() => onApproveHitl(taskId)}
            className="w-full py-2 text-[11px] font-semibold rounded-md bg-warn/90 text-white hover:bg-warn transition-colors flex items-center justify-center gap-1.5">
            <HandPalm size={13} weight="fill" />Approve &amp; Continue
          </button>
        </div>
      )}
    </div>
  )
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return <div className="mt-2.5"><div className="text-[9px] font-semibold text-ink-3 uppercase tracking-wider mb-1">{label}</div>{children}</div>
}
interface Props { state: GoDagState | null; events: LogEvent[]; selected: string | null; onSelect: (id: string) => void; onApproveHitl?: (id: string) => void }

export function Sidebar({ state, events, selected, onSelect, onApproveHitl }: Props) {
  const feedRef = useRef<HTMLDivElement>(null)
  useEffect(() => { feedRef.current?.scrollTo(0, 0) }, [events.length])

  return (
    <div className="w-[280px] max-xl:w-[240px] max-lg:hidden border-l border-edge-2 flex flex-col bg-surf-1">
      <div className="px-3 py-2 text-[9px] font-semibold uppercase tracking-[0.1em] text-ink-m border-b border-edge">Activity</div>
      <div ref={feedRef} className="flex-1 overflow-y-auto">
        <AnimatePresence initial={false}>
          {[...events].reverse().map((e, i) => {
            const Icon = EV_ICONS[e.event] || Play
            const color = EV_COLORS[e.event] || 'text-accent'
            const taskId = e.data?.task as string | undefined
            return (
              <motion.div key={`${e.ts}-${i}`} initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }}
                className="px-3 py-1.5 text-[10px] text-ink-3 border-b border-edge flex gap-1.5 items-baseline leading-snug cursor-pointer hover:bg-surf-2/60 transition-colors"
                onClick={() => taskId && onSelect(taskId)}>
                <span className="text-ink-m font-mono text-[9px] shrink-0 min-w-[32px] tabular-nums">{relTime(e.ts)}</span>
                <Icon size={10} className={`${color} shrink-0 mt-0.5 opacity-70`} />
                <span className="text-ink-2 flex-1">{humanize(e, state)}</span>
              </motion.div>
            )
          })}
        </AnimatePresence>
      </div>
      {selected && state && <DetailPanel state={state} taskId={selected} onApproveHitl={onApproveHitl} />}
    </div>
  )
}
