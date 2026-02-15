import { cn } from '../lib/utils'
import type { GpuInfo } from '../lib/catalog'
import { formatVram } from '../lib/catalog'

export default function GpuSelector({
  gpus,
  selectedGpu,
  onSelect,
  totalVramNeeded,
  selectedVramGb,
}: {
  gpus: GpuInfo[]
  selectedGpu: GpuInfo | null
  onSelect: (gpu: GpuInfo) => void
  totalVramNeeded: number
  selectedVramGb: number | null
}) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {gpus.map((gpu) => {
        const isSelected = selectedGpu?.id === gpu.id
        const fitsModels = gpu.vramMb >= totalVramNeeded
        const fitsPreset = selectedVramGb ? gpu.vramMb >= selectedVramGb * 1024 : true
        const disabled = (!fitsModels && totalVramNeeded > 0) || !fitsPreset

        return (
          <button
            key={gpu.id}
            onClick={() => !disabled && onSelect(gpu)}
            disabled={disabled && !isSelected}
            className={cn(
              "flex items-baseline gap-1.5 px-3 py-1.5 font-mono text-[11px] transition-all duration-150",
              isSelected
                ? "bg-foreground/10 text-foreground"
                : "bg-foreground/[0.03] text-foreground/80 hover:bg-foreground/[0.06] hover:text-foreground",
              disabled && !isSelected && "opacity-20 pointer-events-none"
            )}
          >
            <span className="font-semibold uppercase tracking-wide">{gpu.name}</span>
            <span className="text-[9px] text-foreground/60 tabular-nums">
              {formatVram(gpu.vramMb)}
            </span>
          </button>
        )
      })}
    </div>
  )
}
