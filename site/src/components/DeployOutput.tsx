import { useState, useMemo, useEffect } from 'react'
import { cn } from '../lib/utils'
import type { CatalogModel, GpuInfo, GpuCount, OsPlatform } from '../lib/catalog'

type DeployTab = 'cli-local' | 'cli-cloud' | 'docker' | 'mlx'

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false)
  const handleCopy = () => {
    navigator.clipboard.writeText(text)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }
  return (
    <button
      onClick={handleCopy}
      className={cn(
        "shrink-0 px-3 py-1.5 font-mono text-[10px] font-semibold uppercase tracking-wider transition-all duration-150",
        copied
          ? "text-primary"
          : "bg-foreground/[0.05] text-foreground/60 hover:bg-foreground/[0.08] hover:text-foreground"
      )}
    >
      {copied ? "copied" : "copy"}
    </button>
  )
}

function CodeBlock({ code, hint }: { code: string; hint?: string }) {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-start gap-2">
        <pre className="flex-1 overflow-x-auto font-mono text-[10px] leading-relaxed text-foreground/90">
          <code>{code}</code>
        </pre>
        <CopyButton text={code} />
      </div>
      {hint && (
        <span className="font-mono text-[9px] text-foreground/30">{hint}</span>
      )}
    </div>
  )
}

function TerminalIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2" className={className}>
      <rect x="1.5" y="2.5" width="13" height="11" rx="1.5" />
      <path d="M4.5 6 7 8l-2.5 2" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M8.5 10h3" strokeLinecap="round" />
    </svg>
  )
}

function CloudIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" fill="currentColor" className={className}>
      <path d="M12.5 6.2A4.5 4.5 0 0 0 4 5.5 3.5 3.5 0 0 0 3.5 12.5h9a3 3 0 0 0 0-6.3Z" />
    </svg>
  )
}

function DockerIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" fill="currentColor" className={className}>
      <path d="M9 3H7.5v1.5H9V3Zm0 2H7.5v1.5H9V5Zm-3 0H4.5v1.5H6V5Zm1.5 0v1.5h1.5V5H7.5ZM6 3H4.5v1.5H6V3Zm-3 2H1.5v1.5H3V5Zm12.3 2.3c-.4-.3-1.2-.4-1.8-.3-.2-1-.7-1.8-1.4-2.1l-.3-.2-.2.3c-.3.4-.4 1.1-.4 1.6 0 .5.1 1 .4 1.4-.6.3-1.5.4-1.8.4H.6c-.2 1 0 2.3.6 3.2.7 1 1.7 1.5 3.2 1.5 3 0 5.3-1.4 6.3-3.9.4 0 1.3 0 1.8-.9l.1-.2-.3-.2Z" />
    </svg>
  )
}

function MlxIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" fill="currentColor" className={className}>
      <path d="M8 1.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13ZM5.8 10.5 4 7l1.8-3.5h.9L5.2 6.2h2.3L6.2 10.5h-.4Zm4.4 0L8.5 6.2h-1l1.8-2.7h.9L8.8 6.2h2.3L9.8 10.5h-.4Z" />
    </svg>
  )
}

const TAB_CONFIG: { id: DeployTab; label: string; Icon: React.FC<{ className?: string }> }[] = [
  { id: 'cli-local', label: 'local', Icon: TerminalIcon },
  { id: 'cli-cloud', label: 'cloud', Icon: CloudIcon },
  { id: 'docker', label: 'docker', Icon: DockerIcon },
  { id: 'mlx', label: 'mlx', Icon: MlxIcon },
]

function isTabVisible(tab: DeployTab, os: OsPlatform | null): boolean {
  if (tab === 'docker') return os !== 'mac'
  if (tab === 'mlx') return os !== 'linux' && os !== 'windows'
  return true
}

function buildCliLocalCommand(models: CatalogModel[]): string {
  if (models.length === 0) return 'openclaw2go start'
  const parts: string[] = ['openclaw2go start']
  for (const m of models) {
    if (m.type === 'llm') {
      parts.push(m.isDefault ? '--llm' : `--llm=${m.id}`)
    } else if (m.type === 'audio') {
      parts.push(m.isDefault ? '--audio' : `--audio=${m.id}`)
    } else if (m.type === 'image') {
      parts.push(m.isDefault ? '--image' : `--image=${m.id}`)
    }
  }
  if (parts.length === 1) return parts[0]
  return parts.join(' \\\n  ')
}

function buildCliCloudCommand(
  models: CatalogModel[],
  gpu: GpuInfo | null,
  gpuCount: GpuCount,
  isMacGpu: boolean,
): { command: string; error?: string } {
  if (isMacGpu && gpu) {
    return { command: '', error: 'cloud deploy requires a linux gpu — select a linux gpu or use local.' }
  }

  const parts: string[] = ['openclaw2go deploy']
  for (const m of models) {
    if (m.type === 'llm') {
      parts.push(m.isDefault ? '--llm' : `--llm=${m.id}`)
    } else if (m.type === 'audio') {
      parts.push(m.isDefault ? '--audio' : `--audio=${m.id}`)
    } else if (m.type === 'image') {
      parts.push(m.isDefault ? '--image' : `--image=${m.id}`)
    }
  }
  if (gpu) {
    parts.push(`--gpu="${gpu.name}"`)
  }
  if (gpuCount > 1) {
    parts.push(`--gpu-count=${gpuCount}`)
  }

  if (parts.length === 1) return { command: parts[0] }
  return { command: parts.join(' \\\n  ') }
}

function buildDockerCommand(models: CatalogModel[]): string {
  const config: Record<string, string | boolean> = {}
  for (const m of models) {
    if (m.type === 'llm') {
      config.llm = m.isDefault ? true : m.repo
    } else if (m.type === 'audio') {
      config.audio = m.isDefault ? true : m.repo
    } else if (m.type === 'image') {
      config.image = m.isDefault ? true : m.repo
    }
  }

  const configStr = Object.keys(config).length > 0
    ? JSON.stringify(config)
    : '{}'

  return [
    'docker run --gpus all \\',
    `  -e OPENCLAW_CONFIG='${configStr}' \\`,
    '  -p 8000:8000 -p 8080:8080 -p 18789:18789 \\',
    '  -v openclaw-data:/workspace \\',
    '  runpod/openclaw2go:latest',
  ].join('\n')
}

function buildMlxCommand(models: CatalogModel[]): { command: string; missing: string[] } {
  const missing: string[] = []
  const sections: string[] = []

  const mlxModels = models.filter((m) => {
    if (!m.mlx) {
      missing.push(m.name)
      return false
    }
    return true
  })

  if (mlxModels.length === 0 && models.length === 0) {
    return {
      command: 'pip install mlx-lm\nmlx_lm.server --model <model-repo> --port 8000',
      missing,
    }
  }

  // Group by engine to show pip installs
  const engines = new Set(mlxModels.map((m) => m.mlx!.engine))
  if (engines.size > 0) {
    sections.push(
      [...engines].map((e) => `pip install ${e}`).join('\n')
    )
  }

  for (const m of mlxModels) {
    const port = m.type === 'llm' ? 8000 : m.type === 'audio' ? 8001 : 8002
    const comment = `# ${m.type}`
    if (m.mlx!.engine === 'mlx-lm') {
      sections.push(`${comment}\nmlx_lm.server --model ${m.mlx!.repo} --port ${port}`)
    } else if (m.mlx!.engine === 'mlx-audio') {
      sections.push(`${comment}\n# mlx-audio requires separate setup — see docs`)
    } else if (m.mlx!.engine === 'mflux') {
      sections.push(`${comment}\nmflux-generate --model ${m.mlx!.repo} --prompt "test"`)
    }
  }

  return { command: sections.join('\n\n'), missing }
}

export default function DeployCard({
  selectedModels,
  gpu,
  gpuCount,
  vramGb: _vramGb,
  os,
}: {
  selectedModels: CatalogModel[]
  gpu: GpuInfo | null
  gpuCount: GpuCount
  vramGb: number
  os: OsPlatform | null
}) {
  const [activeTab, setActiveTab] = useState<DeployTab>('cli-local')

  const visibleTabs = useMemo(
    () => TAB_CONFIG.filter((t) => isTabVisible(t.id, os)),
    [os]
  )

  // Reset to cli-local when active tab becomes hidden
  useEffect(() => {
    if (!visibleTabs.some((t) => t.id === activeTab)) {
      setActiveTab('cli-local')
    }
  }, [visibleTabs, activeTab])

  const isMacGpu = gpu?.os.includes('mac') ?? false

  const cliLocal = useMemo(() => buildCliLocalCommand(selectedModels), [selectedModels])

  const cliCloud = useMemo(
    () => buildCliCloudCommand(selectedModels, gpu, gpuCount, isMacGpu),
    [selectedModels, gpu, gpuCount, isMacGpu]
  )

  const docker = useMemo(() => buildDockerCommand(selectedModels), [selectedModels])

  const mlx = useMemo(() => buildMlxCommand(selectedModels), [selectedModels])

  return (
    <div className="flex flex-col" style={{ minHeight: '140px' }}>
      {/* Tab bar */}
      <div className="flex items-center gap-1">
        {visibleTabs.map(({ id, label, Icon }) => (
          <button
            key={id}
            onClick={() => setActiveTab(id)}
            className={cn(
              "flex items-center gap-1.5 px-3 py-1.5 font-mono text-[10px] font-semibold uppercase tracking-wider transition-all duration-150",
              activeTab === id
                ? "bg-foreground/[0.08] text-foreground/90"
                : "text-foreground/30 hover:text-foreground/50 hover:bg-foreground/[0.03]"
            )}
          >
            <Icon className="h-3 w-3" />
            {label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div className="flex-1 overflow-y-auto p-3">
        {activeTab === 'cli-local' && (
          <CodeBlock
            code={cliLocal}
            hint={
              selectedModels.length === 0
                ? 'uses all defaults that fit your gpu'
                : undefined
            }
          />
        )}

        {activeTab === 'cli-cloud' && (
          cliCloud.error ? (
            <span className="font-mono text-[10px] leading-relaxed text-foreground/40">
              {cliCloud.error}
            </span>
          ) : (
            <CodeBlock
              code={cliCloud.command}
              hint="requires RUNPOD_API_KEY env var"
            />
          )
        )}

        {activeTab === 'docker' && (
          <CodeBlock
            code={docker}
            hint="requires nvidia gpu + nvidia-container-toolkit"
          />
        )}

        {activeTab === 'mlx' && (
          <div className="flex flex-col gap-2">
            <CodeBlock
              code={mlx.command}
              hint="requires apple silicon (m1+) and python 3.10+"
            />
            {mlx.missing.length > 0 && (
              <span className="font-mono text-[9px] text-foreground/30">
                no mlx variant: {mlx.missing.join(', ')}
              </span>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
