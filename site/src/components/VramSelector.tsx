import { cn } from '../lib/utils'

export default function VramGauge({
  usedGb,
  selectedGb,
  presets,
  onSelectPreset,
  maxGb,
}: {
  usedGb: number
  selectedGb: number | null
  presets: number[]
  onSelectPreset: (gb: number) => void
  maxGb?: number | null
}) {
  const effectiveTotal = selectedGb ?? 0
  const fillPercent = effectiveTotal > 0 ? Math.min((usedGb / effectiveTotal) * 100, 100) : 0
  const overflows = usedGb > effectiveTotal && effectiveTotal > 0

  return (
    <div className="flex flex-col gap-4">
      {/* usage readout */}
      <div className="flex flex-col gap-2">
        <div className="flex items-baseline gap-2">
          <span
            className={cn(
              "font-mono text-3xl font-bold tabular-nums tracking-tighter transition-colors",
              overflows ? "text-destructive" : usedGb > 0 ? "text-foreground" : "text-foreground/30"
            )}
          >
            {usedGb.toFixed(1)}
          </span>
          <span className="font-mono text-xs text-foreground/50">
            {effectiveTotal > 0 ? `/ ${effectiveTotal} GB` : "GB used"}
          </span>
          {overflows && (
            <span className="ml-auto font-mono text-[10px] font-semibold uppercase tracking-wider text-destructive animate-pulse-subtle">
              exceeds vram
            </span>
          )}
        </div>

        {/* bar */}
        <div className="relative h-1.5 w-full overflow-hidden bg-foreground/[0.06]">
          <div
            className={cn(
              "absolute inset-y-0 left-0 transition-all duration-700 ease-out",
              overflows ? "bg-destructive" : "bg-primary/60"
            )}
            style={{ width: effectiveTotal > 0 ? `${fillPercent}%` : "0%" }}
          />
          {/* tick marks at 25/50/75 */}
          {effectiveTotal > 0 && [25, 50, 75].map((pct) => (
            <div
              key={pct}
              className="absolute top-0 h-full w-px bg-foreground/[0.06]"
              style={{ left: `${pct}%` }}
            />
          ))}
        </div>
      </div>

      {/* presets */}
      <div className="flex flex-wrap items-center gap-1.5">
        {presets.map((gb) => {
          const isSelected = selectedGb === gb
          const exceedsGpu = maxGb != null && gb > maxGb

          return (
            <button
              key={gb}
              onClick={() => !exceedsGpu && onSelectPreset(gb)}
              disabled={exceedsGpu}
              className={cn(
                "px-2.5 py-1 font-mono text-[10px] font-medium tabular-nums transition-all duration-150",
                exceedsGpu
                  ? "text-foreground/15 cursor-not-allowed"
                  : isSelected
                    ? "bg-foreground/10 text-foreground"
                    : "text-foreground/60 hover:bg-foreground/[0.04] hover:text-foreground"
              )}
            >
              {gb}
            </button>
          )
        })}
      </div>
    </div>
  )
}
