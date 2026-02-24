export interface GoDagMeta {
  project: string
  intent_type: 'implement' | 'fix' | 'refactor' | 'review' | 'research'
  level: 1 | 2 | 3
  strategy: 'sequential' | 'parallel_fanout' | 'full_team' | 'debate'
  started_at: string
  updated_at: string
  status: 'running' | 'complete' | 'failed'
  user_prompt: string
  teammates_max: number
}

export interface DagTask {
  id: string
  title: string
  type: 'implement' | 'test' | 'review' | 'research' | 'config'
  scope: string[]
  blocked_by: string[]
  acceptance: string
  estimated_complexity: 'small' | 'medium' | 'large'
  agent_role: string
  hitl?: boolean
}

export interface TaskRuntime {
  status: 'pending' | 'blocked' | 'in_progress' | 'done' | 'awaiting_human'
  agent: string | null
  started_at: string | null
  completed_at: string | null
  duration_s: number | null
  acceptance_passed: boolean | null
  acceptance_output: string | null
  summary: string | null
  decisions: string[]
  issues: string[]
  retries: number
  files_changed: string[]
}

export interface Confidence {
  score: number
  level: 'low' | 'medium' | 'high'
  signals: {
    acceptance_pass_rate: number
    retry_count: number
    lint_clean: boolean | null
    has_tests: boolean | null
    escalation_count: number
  }
}

export interface GoDagState {
  $schema: string
  meta: GoDagMeta
  dag: { tasks: DagTask[]; edges: [string, string][] }
  tasks: Record<string, TaskRuntime>
  confidence: Confidence
  dashboard: { server_pid: number | null; port: number | null; url: string | null }
}

export interface LogEvent {
  ts: string
  event: string
  data: Record<string, unknown>
}
