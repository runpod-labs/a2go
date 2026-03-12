import type { ReactNode } from 'react'

export default function SectionHeader({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <div
      className={`flex shrink-0 items-center gap-2 border-b border-foreground/[0.06] bg-foreground/[0.03] px-4 py-2 ${className ?? ""}`}
    >
      {children}
    </div>
  )
}
