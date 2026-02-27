import { useState, useRef } from 'react'
import { Sun, Moon, Flask, FolderOpen, Power, ClockCounterClockwise, X } from '@phosphor-icons/react'
import { motion, AnimatePresence } from 'framer-motion'
import type { GoDagState } from '../types'

type PanelType = 'fixtures' | 'history' | null

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
  const [panel, setPanel] = useState<PanelType>(null)
  const [runs, setRuns] = useState<string[]>([])
  const fileRef = useRef<HTMLInputElement>(null)

  const m = state?.meta
  const btnBase = 'px-2 py-1 text-[11px] border border-edge-2 bg-surf-2 text-ink-3 rounded-md hover:bg-accent-d hover:text-accent hover:border-accent/30 transition-all'

  const openPanel = async (type: PanelType) => {
    if (panel === type) { setPanel(null); return }
    if (type === 'history') {
      const r = await fetch('/runs?' + Date.now()).then(r => r.json()).catch(() => [])
      setRuns(r)
    }
    setPanel(type)
  }
  return (
    <>
      {error && <div className="bg-danger/90 text-white text-center text-[11px] font-medium py-1.5 rounded-xl tracking-wide">Connection lost — server may be down</div>}
      <header className="px-4 py-2 bg-surf-1 border border-edge-2 rounded-xl flex items-center gap-3">
        <div className="flex items-center gap-2 text-[14px] font-bold tracking-tight whitespace-nowrap">
          <div className="w-3 h-3 bg-accent rotate-45 rounded-[2px] shrink-0 opacity-90" />GoDag
        </div>

        {m && <span className="px-1.5 py-0.5 rounded text-[9px] font-semibold uppercase tracking-wider bg-accent-d text-accent/80 border border-accent/10">{m.intent_type}</span>}
        {m && <span className={`px-1.5 py-0.5 rounded text-[9px] font-semibold uppercase tracking-wider border ${
          m.status === 'running' ? 'bg-ok-d text-ok/80 border-ok/10' : m.status === 'complete' ? 'bg-ok-d text-ok/80 border-ok/10' : 'bg-danger-d text-danger/80 border-danger/10'
        }`}>{m.status}</span>}

        <div className="flex-1" />

        <div className="flex gap-px bg-surf-3 rounded-md p-0.5">
          {(['dag', 'timeline'] as const).map(v => (
            <button key={v} onClick={() => onViewChange(v)} className={`px-2.5 py-1 text-[10px] font-semibold rounded transition-all ${view === v ? 'bg-surf-1 text-ink shadow-sm' : 'text-ink-3 hover:text-ink-2'}`}>
              {v === 'dag' ? 'DAG' : 'Timeline'}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-1">
          <button onClick={() => openPanel('fixtures')} className={`${btnBase} flex items-center gap-1 ${panel === 'fixtures' ? '!bg-accent-d !text-accent !border-accent/30' : ''}`}>
            <Flask size={11} />Fixtures
          </button>
          <button onClick={() => openPanel('history')} className={`${btnBase} flex items-center gap-1 ${panel === 'history' ? '!bg-accent-d !text-accent !border-accent/30' : ''}`}>
            <ClockCounterClockwise size={11} />History
          </button>
          <button onClick={() => fileRef.current?.click()} className={btnBase}><FolderOpen size={11} /></button>
          <input ref={fileRef} type="file" accept=".json" className="hidden" onChange={e => { const f = e.target.files?.[0]; if (f) onLoadFile(f); e.target.value = '' }} />
          <button onClick={onToggleDark} className={btnBase}>{dark ? <Sun size={11} /> : <Moon size={11} />}</button>
          <button onClick={() => { if (confirm('Stop dashboard server?')) fetch('/stop', { method: 'POST' }) }} className={`${btnBase} hover:!bg-danger-d hover:!text-danger hover:!border-danger/30`}><Power size={11} weight="bold" /></button>
        </div>
      </header>
      <AnimatePresence>
        {panel && (
          <>
            <motion.div className="fixed inset-0 bg-black/30 z-40" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setPanel(null)} />
            <motion.div
              initial={{ x: -280, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: -280, opacity: 0 }}
              transition={{ type: 'spring', damping: 28, stiffness: 320 }}
              className="fixed left-3 top-3 bottom-3 w-[260px] bg-surf-1 border border-edge-2 rounded-xl z-50 p-4 overflow-y-auto shadow-2xl flex flex-col"
            >
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-[12px] font-semibold text-ink flex items-center gap-1.5">
                  {panel === 'fixtures' ? <><Flask size={13} />Fixtures</> : <><ClockCounterClockwise size={13} />History</>}
                </h3>
                <button onClick={() => setPanel(null)} className="text-ink-3 hover:text-ink transition-colors"><X size={14} /></button>
              </div>
              <div className="flex flex-col gap-1.5">
                {panel === 'fixtures' && ['fanout-running', 'fanout-complete', 'linear-running'].map(fx => (
                  <button key={fx} onClick={() => { onLoadFixture(fx); setPanel(null) }}
                    className="px-3 py-2 text-[11px] text-left border border-edge-2 bg-surf-2 text-ink-2 rounded-lg hover:bg-accent-d hover:text-accent hover:border-accent/30 transition-all">
                    {fx}
                  </button>
                ))}
                {panel === 'history' && runs.length === 0 && <span className="text-[11px] text-ink-m py-2">No archived runs</span>}
                {panel === 'history' && runs.map(id => (
                  <button key={id} onClick={() => { onLoadRun(id); setPanel(null) }}
                    className="px-3 py-2 text-[11px] text-left border border-edge-2 bg-surf-2 text-ink-2 rounded-lg hover:bg-accent-d hover:text-accent hover:border-accent/30 transition-all font-mono tabular-nums">
                    {id}
                  </button>
                ))}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  )
}
