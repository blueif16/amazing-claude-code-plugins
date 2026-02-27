import { useState, useEffect, useCallback } from 'react'
import { useGoDagState } from './hooks/useGoDagState'
import { Header } from './components/Header'
import { StatsBar } from './components/StatsBar'
import { DagView } from './components/DagView'
import { TimelineView } from './components/TimelineView'
import { Sidebar } from './components/Sidebar'
import { motion, AnimatePresence } from 'framer-motion'

export function App() {
  const { state, events, error, transitions, loadFixture, loadFile, loadRun, toggleHitl, approveHitl } = useGoDagState()
  const [view, setView] = useState<'dag' | 'timeline'>('dag')
  const [selected, setSelected] = useState<string | null>(null)
  const [dark, setDark] = useState(() => localStorage.getItem('godag-theme') !== 'light')

  useEffect(() => {
    document.documentElement.className = dark ? 'dark' : 'light'
    document.body.className = dark ? 'bg-canvas text-ink antialiased' : 'bg-canvas text-ink antialiased'
    localStorage.setItem('godag-theme', dark ? 'dark' : 'light')
  }, [dark])

  // Tab title
  useEffect(() => {
    if (!state) return
    const ids = Object.keys(state.tasks)
    const done = ids.filter(id => state.tasks[id].status === 'done').length
    document.title = `[${done}/${ids.length}] GoDag — ${state.meta.project}`
  }, [state])

  // Keyboard nav
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (!state) return
      const ids = state.dag.tasks.map(t => t.id)
      if (e.key === 'Escape') { setSelected(null); return }
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        e.preventDefault()
        const idx = selected ? ids.indexOf(selected) : -1
        setSelected(ids[(idx + 1) % ids.length])
      }
      if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
        e.preventDefault()
        const idx = selected ? ids.indexOf(selected) : 1
        setSelected(ids[(idx - 1 + ids.length) % ids.length])
      }
      if (e.key === 'Tab') { e.preventDefault(); setView(v => v === 'dag' ? 'timeline' : 'dag') }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [state, selected])

  // Completion banner
  const showBanner = state && (state.meta.status === 'complete' || state.meta.status === 'failed')
  const bannerOk = state?.meta.status === 'complete'
  const done = state ? Object.values(state.tasks).filter(t => t.status === 'done' && t.acceptance_passed !== false).length : 0
  const total = state ? Object.keys(state.tasks).length : 0

  return (
    <div className="h-screen p-3 flex flex-col gap-3 overflow-hidden bg-canvas">
      <Header state={state} view={view} onViewChange={setView} dark={dark} onToggleDark={() => setDark(d => !d)} onLoadFixture={loadFixture} onLoadFile={loadFile} onLoadRun={loadRun} error={error} />
      <StatsBar state={state} />
      <div className="flex flex-1 gap-3 overflow-hidden min-h-0">
        <div className="flex-1 bg-surf-1 border border-edge-2 rounded-xl overflow-hidden">
          {view === 'dag'
            ? <DagView state={state} selected={selected} onSelect={setSelected} transitions={transitions} onToggleHitl={toggleHitl} />
            : <TimelineView state={state} onSelect={setSelected} />}
        </div>
        <Sidebar state={state} events={events} selected={selected} onSelect={setSelected} onApproveHitl={approveHitl} />
      </div>
      <AnimatePresence>
        {showBanner && (
          <motion.div initial={{ y: 60, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 60, opacity: 0 }}
            transition={{ type: 'spring', damping: 20, stiffness: 300 }}
            className={`fixed bottom-5 left-1/2 -translate-x-1/2 px-6 py-2.5 rounded-lg text-[12px] font-semibold z-50 shadow-[0_8px_24px_rgba(0,0,0,0.25)] backdrop-blur-sm ${bannerOk ? 'bg-ok/90 text-white' : 'bg-danger/90 text-white'}`}>
            {bannerOk ? `Done — ${done}/${total} passed · confidence ${state?.confidence.score}%` : `Failed — ${done}/${total} passed`}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
