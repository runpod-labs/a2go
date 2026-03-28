import { cn } from '../lib/utils'
import type { AgentFramework } from '../lib/frameworks'
import { FRAMEWORKS } from '../lib/frameworks'

export default function FrameworkSelector({
  selected,
  onSelect,
}: {
  selected: AgentFramework
  onSelect?: (fw: AgentFramework) => void
}) {
  const cols = 3
  const lastRowStart = Math.floor((FRAMEWORKS.length - 1) / cols) * cols

  return (
    <div className="grid grid-cols-3">
      {FRAMEWORKS.map((fw, i) => {
        const active = fw.id === selected.id
        const isLastCol = (i + 1) % cols === 0
        const isLastRow = i >= lastRowStart
        return (
          <div
            key={fw.id}
            onClick={() => fw.available && onSelect?.(fw)}
            className={cn(
              'flex flex-col items-center justify-center gap-1 border-foreground/[0.06] py-3',
              !isLastCol && 'border-r',
              !isLastRow && 'border-b',
              active
                ? 'bg-foreground/[0.07]'
                : 'bg-transparent',
              fw.available && !active
                ? 'cursor-pointer hover:bg-foreground/[0.04]'
                : !fw.available && 'cursor-default',
            )}
          >
            <span
              className={cn(
                'font-mono text-[11px] font-semibold tracking-tight',
                active
                  ? 'text-foreground'
                  : fw.available
                    ? 'text-foreground/60'
                    : 'text-foreground/25',
              )}
            >
              {fw.name}
            </span>
            {!fw.available && (
              <span className="font-mono text-[7px] font-semibold uppercase tracking-[0.12em] text-foreground/15">
                coming soon
              </span>
            )}
          </div>
        )
      })}
    </div>
  )
}

/** Compact inline selector for mobile header */
export function FrameworkPill({
  selected,
  onSelect,
}: {
  selected: AgentFramework
  onSelect?: (fw: AgentFramework) => void
}) {
  const availableFrameworks = FRAMEWORKS.filter((fw) => fw.available)
  const unavailableCount = FRAMEWORKS.filter((fw) => !fw.available).length

  return (
    <div className="flex items-center gap-1">
      {availableFrameworks.map((fw) => (
        <button
          key={fw.id}
          onClick={() => onSelect?.(fw)}
          className={cn(
            'font-mono text-[9px] font-medium tracking-tight px-1.5 py-0.5 transition-colors',
            fw.id === selected.id
              ? 'text-foreground/80 bg-foreground/[0.08]'
              : 'text-foreground/30 hover:text-foreground/50',
          )}
        >
          {fw.name}
        </button>
      ))}
      {unavailableCount > 0 && (
        <span className="font-mono text-[7px] text-foreground/15">
          +{unavailableCount} soon
        </span>
      )}
    </div>
  )
}
