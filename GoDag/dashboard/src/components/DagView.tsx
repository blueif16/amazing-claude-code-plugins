import { useMemo, useCallback } from 'react'
import {
  ReactFlow, Background, Controls, MiniMap,
  type Node, type Edge, useNodesState, useEdgesState,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import dagre from '@dagrejs/dagre'
import { TaskNode, type TaskNodeData } from './TaskNode'
import type { GoDagState } from '../types'

const nodeTypes = { task: TaskNode }
const NODE_W = 220, NODE_H = 64, GAP_X = 80, GAP_Y = 32

function layout(state: GoDagState, transitions: Record<string, 'done' | 'fail'>) {
  const g = new dagre.graphlib.Graph().setDefaultEdgeLabel(() => ({}))
  g.setGraph({ rankdir: 'LR', nodesep: GAP_Y, ranksep: GAP_X, marginx: 40, marginy: 40 })
  state.dag.tasks.forEach(t => g.setNode(t.id, { width: NODE_W, height: NODE_H }))
  state.dag.edges.forEach(([f, t]) => g.setEdge(f, t))
  dagre.layout(g)

  const nodes: Node<TaskNodeData>[] = state.dag.tasks.map(t => {
    const pos = g.node(t.id)
    return {
      id: t.id, type: 'task', position: { x: pos.x - NODE_W / 2, y: pos.y - NODE_H / 2 },
      data: { task: t, runtime: state.tasks[t.id], transition: transitions[t.id] },
    }
  })

  const edges: Edge[] = state.dag.edges.map(([f, t]) => {
    const fs = state.tasks[f], ts = state.tasks[t]
    let stroke = 'var(--color-edge-2)', animated = false
    if (fs?.status === 'done' && fs.acceptance_passed !== false) {
      if (ts?.status === 'in_progress') { stroke = 'var(--color-accent)'; animated = true }
      else if (ts?.status === 'done') stroke = 'var(--color-ok)'
      else stroke = 'var(--color-ok)'
    }
    return {
      id: `${f}-${t}`, source: f, target: t, animated,
      style: { stroke, strokeWidth: 1.2, opacity: 0.8 },
      markerEnd: { type: 'arrowclosed' as const, color: stroke, width: 12, height: 8 },
    }
  })
  return { nodes, edges }
}

interface Props {
  state: GoDagState | null
  selected: string | null
  onSelect: (id: string) => void
  transitions: Record<string, 'done' | 'fail'>
}

export function DagView({ state, selected, onSelect, transitions }: Props) {
  const { initialNodes, initialEdges } = useMemo(() => {
    if (!state) return { initialNodes: [], initialEdges: [] }
    const { nodes, edges } = layout(state, transitions)
    return { initialNodes: nodes, initialEdges: edges }
  }, [state, transitions])

  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)

  useMemo(() => { setNodes(initialNodes); setEdges(initialEdges) }, [initialNodes, initialEdges])

  const onNodeClick = useCallback((_: unknown, node: Node) => onSelect(node.id), [onSelect])

  if (!state) return <div className="flex-1 flex items-center justify-center text-ink-3 text-sm">Waiting for data...</div>

  return (
    <div className="flex-1">
      <ReactFlow
        nodes={nodes} edges={edges}
        onNodesChange={onNodesChange} onEdgesChange={onEdgesChange}
        onNodeClick={onNodeClick}
        nodeTypes={nodeTypes}
        fitView fitViewOptions={{ padding: 0.2 }}
        minZoom={0.3} maxZoom={2}
        proOptions={{ hideAttribution: true }}
      >
        <Background color="var(--color-edge)" gap={24} size={0.8} />
        <Controls showInteractive={false} />
        <MiniMap
          nodeColor={(n: Node<TaskNodeData>) => {
            const s = n.data?.runtime?.status
            if (s === 'done') return n.data?.runtime?.acceptance_passed !== false ? 'var(--color-ok)' : 'var(--color-danger)'
            if (s === 'in_progress') return 'var(--color-accent)'
            return 'var(--color-ink-m)'
          }}
          maskColor="rgba(0,0,0,0.55)"
          style={{ background: 'var(--color-surf-1)' }}
        />
      </ReactFlow>
    </div>
  )
}
