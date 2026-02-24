import { memo, useCallback } from 'react'
import { Handle, Position, type NodeProps } from '@xyflow/react'
import { Lightning, Check, X, Lock, Clock, GearSix, Code, Flask, MagnifyingGlass, Eye, UserCircle, HandPalm } from '@phosphor-icons/react'
import type { DagTask, TaskRuntime } from '../types'

const STATUS_CFG = {
  pending:        { icon: Clock,     weight: 'light' as const,   border: 'border-ink-m/60',  bg: 'bg-surf-2',     dot: 'bg-ink-m' },
  blocked:        { icon: Lock,      weight: 'light' as const,   border: 'border-ink-m/40',  bg: 'bg-surf-2',     dot: 'bg-ink-m' },
  in_progress:    { icon: Lightning, weight: 'fill' as const,    border: 'border-accent/60', bg: 'bg-accent-d',   dot: 'bg-accent' },
  awaiting_human: { icon: HandPalm,  weight: 'fill' as const,    border: 'border-warn/60',   bg: 'bg-warn-d',     dot: 'bg-warn' },
  'done-pass':    { icon: Check,     weight: 'fill' as const,    border: 'border-ok/50',     bg: 'bg-ok-d',       dot: 'bg-ok' },
  'done-fail':    { icon: X,         weight: 'bold' as const,    border: 'border-danger/50', bg: 'bg-danger-d',   dot: 'bg-danger' },
} as const

const TYPE_ICON: Record<string, typeof Code> = {
  implement: Code, test: Flask, review: Eye, research: MagnifyingGlass, config: GearSix,
}

function formatDuration(sec: number) {
  return `${Math.floor(sec / 60)}m${String(sec % 60).padStart(2, '0')}s`
}

export type TaskNodeData = {
  task: DagTask
  runtime: TaskRuntime
  transition?: 'done' | 'fail'
  onToggleHitl?: (id: string) => void
}

export const TaskNode = memo(({ data }: NodeProps & { data: TaskNodeData }) => {
  const { task, runtime, transition, onToggleHitl } = data
  const key = runtime.status === 'done'
    ? (runtime.acceptance_passed !== false ? 'done-pass' : 'done-fail')
    : runtime.status
  const cfg = STATUS_CFG[key] || STATUS_CFG.pending
  const StatusIcon = cfg.icon
  const TypeIcon = TYPE_ICON[task.type] || Code
  const isPulse = runtime.status === 'in_progress'
  const isAwaiting = runtime.status === 'awaiting_human'

  let elapsed = ''
  if (runtime.status === 'in_progress' && runtime.started_at) {
    const sec = Math.floor((Date.now() - new Date(runtime.started_at).getTime()) / 1000)
    elapsed = formatDuration(sec)
  } else if (runtime.duration_s != null) {
    elapsed = formatDuration(runtime.duration_s)
  }

  const handleGateClick = useCallback((e: React.MouseEvent) => {
    e.stopPropagation()
    onToggleHitl?.(task.id)
  }, [onToggleHitl, task.id])

  return (
    <>
      <Handle type="target" position={Position.Left} className="!bg-ink-m !border-0 !w-1.5 !h-1.5" />
      <div className={`w-[220px] rounded-lg border-l-2 ${cfg.border} ${cfg.bg} px-3 py-2.5
        transition-all duration-300 cursor-pointer hover:-translate-y-px hover:shadow-lg
        ${isPulse ? 'node-pulse' : ''}
        ${isAwaiting ? 'node-pulse-warn' : ''}
        ${transition === 'done' ? 'animate-[glow-ok_0.8s_ease-out]' : ''}
        ${transition === 'fail' ? 'animate-[glow-fail_0.6s_ease-out]' : ''}
        ${runtime.status === 'blocked' ? 'opacity-40' : ''}
      `}>
        <div className="flex items-center gap-1.5 mb-1">
          <StatusIcon size={12} weight={cfg.weight} className={`${
            key === 'done-pass' ? 'text-ok' : key === 'done-fail' ? 'text-danger' : key === 'in_progress' ? 'text-accent' : key === 'awaiting_human' ? 'text-warn' : 'text-ink-3'
          } shrink-0 opacity-80`} />
          <span className="text-[11px] font-semibold text-ink leading-tight truncate flex-1">{task.id}: {task.title}</span>
          {/* HITL gate toggle */}
          <button onClick={handleGateClick} title={task.hitl ? 'Remove gate' : 'Add gate'}
            className={`shrink-0 w-4 h-4 flex items-center justify-center rounded transition-all
              ${task.hitl
                ? 'text-warn bg-warn-d hover:bg-warn/20'
                : 'text-ink-m/40 hover:text-ink-3 hover:bg-surf-3'}`}>
            <UserCircle size={11} weight={task.hitl ? 'fill' : 'light'} />
          </button>
        </div>
        <div className="flex items-center gap-2 text-[9px] text-ink-3">
          <span className="flex items-center gap-0.5"><TypeIcon size={9} weight="duotone" className="opacity-60" />{task.type}</span>
          {isAwaiting && <span className="text-warn font-semibold">Awaiting approval</span>}
          {!isAwaiting && task.agent_role && <span className="truncate opacity-70">{task.agent_role}</span>}
          {elapsed && <span className="font-mono text-accent/80 font-medium ml-auto tabular-nums">{elapsed}</span>}
        </div>
      </div>
      <Handle type="source" position={Position.Right} className="!bg-ink-m !border-0 !w-1.5 !h-1.5" />
    </>
  )
})
