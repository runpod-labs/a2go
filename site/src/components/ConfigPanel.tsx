import SectionHeader from './SectionHeader'
import GpuSelector from './VramLegend'
import VramGauge from './VramSelector'
import SelectedModels from './SelectedModels'
import DeployCard from './DeployOutput'
import type { CatalogModel, GpuInfo, OsPlatform } from '../lib/catalog'
import { VRAM_PRESETS } from '../lib/catalog'
import type { ModelGroup } from '../lib/group-models'

export default function ConfigPanel({
  selectedModels,
  totalVramGb,
  effectiveVramGb,
  selectedVramGb,
  selectedGpu,
  gpus,
  totalVramMb,
  onGpuSelect,
  onVramPreset,
  onToggleModel,
  onClearAll,
  modelIdToGroup,
  os,
}: {
  selectedModels: CatalogModel[]
  totalVramGb: number
  effectiveVramGb: number
  selectedVramGb: number | null
  selectedGpu: GpuInfo | null
  gpus: GpuInfo[]
  totalVramMb: number
  onGpuSelect: (gpu: GpuInfo) => void
  onVramPreset: (gb: number) => void
  onToggleModel: (model: CatalogModel) => void
  onClearAll: () => void
  modelIdToGroup: Map<string, ModelGroup>
  os: OsPlatform | null
}) {
  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      {/* Hardware + Logo row */}
      <div className="flex shrink-0 border-b border-foreground/[0.06]">
        {/* Hardware */}
        <div className="flex-1 border-r border-foreground/[0.06]">
          <SectionHeader>
            <span className="font-mono text-[10px] font-bold uppercase tracking-[0.2em] text-foreground/70">
              Hardware
            </span>
          </SectionHeader>
          <div className="flex flex-col gap-4 p-5">
            <VramGauge
              usedGb={totalVramGb}
              selectedGb={selectedVramGb ?? (selectedGpu ? selectedGpu.vramMb / 1024 : null)}
              presets={VRAM_PRESETS}
              onSelectPreset={onVramPreset}
              maxGb={selectedGpu ? selectedGpu.vramMb / 1024 : null}
            />
            <div className="h-px bg-foreground/[0.04]" />
            <div className="flex flex-col gap-2">
              <span className="font-mono text-[9px] font-medium uppercase tracking-widest text-foreground/60">
                GPU
              </span>
              <GpuSelector
                gpus={gpus}
                selectedGpu={selectedGpu}
                onSelect={onGpuSelect}
                totalVramNeeded={totalVramMb}
                selectedVramGb={selectedVramGb}
              />
            </div>
          </div>
        </div>

        {/* Logo card */}
        <div className="flex w-[200px] shrink-0 flex-col items-center justify-center">
          <img
            src={`${import.meta.env.BASE_URL}openclaw2go_logo_nobg.png`}
            alt="openclaw2go"
            width={140}
            height={140}
            className="-mb-3 h-32 w-32 object-contain"
          />
          <span className="font-mono text-[12px] font-bold tracking-tight text-foreground/70">
            openclaw2go
          </span>
          <span className="font-mono text-[9px] text-foreground/30">
            v0.1
          </span>
        </div>
      </div>

      {/* Selected Models */}
      <div className="flex flex-1 flex-col overflow-hidden">
        <SectionHeader className="justify-between">
          <div className="flex items-center gap-3">
            <span className="font-mono text-[10px] font-bold uppercase tracking-[0.2em] text-foreground/70">
              Selected Models
            </span>
            {selectedModels.length > 0 && (
              <span className="font-mono text-[10px] tabular-nums text-foreground/60">
                {selectedModels.length} model{selectedModels.length !== 1 ? "s" : ""}
                {" / "}
                {totalVramGb.toFixed(1)} GB
              </span>
            )}
          </div>
          {selectedModels.length > 0 && (
            <button
              onClick={onClearAll}
              className="font-mono text-[9px] font-medium uppercase tracking-widest text-foreground/50 transition-colors hover:text-foreground/80"
            >
              clear all
            </button>
          )}
        </SectionHeader>

        {/* Selected model slots */}
        <div className="flex-1 overflow-y-auto p-4">
          <SelectedModels
            models={selectedModels}
            onToggle={onToggleModel}
            modelIdToGroup={modelIdToGroup}
            os={os}
          />
        </div>

        {/* Deploy */}
        <div className="shrink-0 border-t border-foreground/[0.06]">
          <SectionHeader>
            <span className="font-mono text-[10px] font-bold uppercase tracking-[0.2em] text-foreground/70">
              Deploy
            </span>
          </SectionHeader>
          <div className="p-4">
            <DeployCard
              selectedModels={selectedModels}
              gpu={selectedGpu}
              vramGb={effectiveVramGb}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
