export type TaskChip = 'llm' | 'vision' | 'image' | 'audio'

export interface FilterState {
  contextMin: number | null
  task: TaskChip | null
}

export const EMPTY_FILTERS: FilterState = {
  contextMin: null,
  task: null,
}
