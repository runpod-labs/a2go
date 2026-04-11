import { cn } from '../lib/utils'
import type { Platform } from '../lib/catalog'
import type { ReactNode } from 'react'
import { FaLinux, FaWindows, FaApple } from 'react-icons/fa'
import { Globe } from 'lucide-react'

function PlatformIcon({ os, className }: { os: Platform; className?: string }): ReactNode {
  if (os === 'web') return <Globe className={className} />
  if (os === 'linux') return <FaLinux className={className} />
  if (os === 'windows') return <FaWindows className={className} />
  return <FaApple className={className} />
}

const OS_OPTIONS: { id: Platform; label: string }[] = [
  { id: 'mac', label: 'macOS' },
  { id: 'linux', label: 'Linux' },
  { id: 'windows', label: 'Windows' },
  { id: 'web', label: 'Web' },
]

const OS_ACTIVE_STYLES: Record<Platform, string> = {
  linux: 'bg-[#E8B931] text-[#1a1a1a]',
  windows: 'bg-[#0078D4] text-white',
  mac: 'bg-[#A2AAAD] text-[#1a1a1a]',
  web: 'bg-[#71E4FF] text-[#06131A]',
}

export { PlatformIcon }

export function PlatformPills({ os, onChange }: { os: Platform; onChange: (os: Platform) => void }) {
  return (
    <div className="flex items-center gap-0.5">
      {OS_OPTIONS.map((opt) => {
        const active = os === opt.id
        return (
          <button
            key={opt.id}
            onClick={() => onChange(opt.id)}
            className={cn(
              "flex h-5 w-5 items-center justify-center rounded transition-all duration-150",
              active
                ? OS_ACTIVE_STYLES[opt.id]
                : "text-foreground/50 hover:bg-foreground/[0.05] hover:text-foreground/70"
            )}
            title={opt.label}
          >
            <PlatformIcon os={opt.id} className="h-2.5 w-2.5" />
          </button>
        )
      })}
    </div>
  )
}

export default function PlatformSelector({
  os,
  onChange,
}: {
  os: Platform
  onChange: (os: Platform) => void
}) {
  return (
    <div className="grid grid-cols-2 lg:grid-cols-4">
      {OS_OPTIONS.map((opt) => {
        const active = os === opt.id
        return (
          <button
            key={opt.id}
            onClick={() => onChange(opt.id)}
            className={cn(
              "flex items-center justify-center gap-1.5 border-foreground/[0.06] py-3 font-mono transition-colors",
              opt.id !== 'web' && 'lg:border-r',
              opt.id === 'mac' || opt.id === 'linux' ? 'border-b lg:border-b-0' : '',
              opt.id === 'mac' || opt.id === 'windows' ? 'border-r lg:border-r-0' : '',
              active
                ? OS_ACTIVE_STYLES[opt.id]
                : "bg-transparent text-foreground/60 hover:bg-foreground/[0.04] hover:text-foreground/80"
            )}
          >
            <span className="flex items-center gap-1.5 text-[11px] font-semibold tracking-tight">
              <PlatformIcon os={opt.id} className="h-3 w-3" />
              {opt.label}
            </span>
          </button>
        )
      })}
    </div>
  )
}
