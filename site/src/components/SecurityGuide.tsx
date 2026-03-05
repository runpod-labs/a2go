type GuideLink = {
  step: number
  label: string
  href: string
  description: string
}

const ESSENTIAL_LINKS: GuideLink[] = [
  {
    step: 1,
    label: 'Getting Started',
    href: 'https://openclaw.ai/start/getting-started',
    description: 'Install, onboarding wizard, first chat',
  },
  {
    step: 2,
    label: 'Security Guide',
    href: 'https://openclaw.ai/gateway/security',
    description: 'Trust model, access control, hardening',
  },
]

const VULN_LINK = {
  label: 'Report a Vulnerability',
  href: 'https://trust.openclaw.ai',
  description: 'Responsible disclosure & security contacts',
}

function ArrowIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" className={className}>
      <path d="M4.5 11.5 11 5m0 0H5.5m5.5 0v5.5" />
    </svg>
  )
}

export default function SecurityGuide() {
  return (
    <div className="flex flex-col gap-4">
      <p className="font-mono text-[9px] leading-relaxed text-foreground/40">
        OpenClaw gives AI agents shell access, file access, and network
        tools on your GPU. Read these first.
      </p>

      {/* Numbered essential guides */}
      <div className="flex flex-col gap-1">
        {ESSENTIAL_LINKS.map((link) => (
          <a
            key={link.href}
            href={link.href}
            target="_blank"
            rel="noopener noreferrer"
            className="group flex items-start gap-3 px-2 py-2 -mx-2 transition-colors hover:bg-foreground/[0.04]"
          >
            <span className="font-mono text-[10px] font-bold tabular-nums text-primary/50 transition-colors group-hover:text-primary/80">
              {link.step}
            </span>
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-1.5">
                <span className="font-mono text-[10px] font-medium text-foreground/70 transition-colors group-hover:text-foreground/90">
                  {link.label}
                </span>
                <ArrowIcon className="h-2.5 w-2.5 shrink-0 text-foreground/15 transition-colors group-hover:text-foreground/40" />
              </div>
              <span className="font-mono text-[8px] text-foreground/30">
                {link.description}
              </span>
            </div>
          </a>
        ))}
      </div>

      {/* Separator */}
      <div className="border-t border-foreground/[0.06]" />

      {/* Vulnerability reporting */}
      <a
        href={VULN_LINK.href}
        target="_blank"
        rel="noopener noreferrer"
        className="group flex items-start gap-2 px-2 py-1.5 -mx-2 transition-colors hover:bg-foreground/[0.04]"
      >
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5">
            <span className="font-mono text-[9px] font-medium text-foreground/40 transition-colors group-hover:text-foreground/60">
              {VULN_LINK.label}
            </span>
            <ArrowIcon className="h-2.5 w-2.5 shrink-0 text-foreground/15 transition-colors group-hover:text-foreground/30" />
          </div>
          <span className="font-mono text-[8px] text-foreground/25">
            {VULN_LINK.description}
          </span>
        </div>
      </a>
    </div>
  )
}
