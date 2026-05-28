import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from 'react'
import { clsx } from 'clsx'
import { ChevronDown } from 'lucide-react'

export interface CalculationLine {
  label: string
  value: string
  detail?: string
  tone?: 'neutral' | 'add' | 'subtract' | 'result' | 'muted'
}

export interface CalculationBreakdown {
  formula?: string
  lines: CalculationLine[]
  note?: string
}

type PanelAccent = 'slate' | 'blue' | 'emerald' | 'amber' | 'rose' | 'violet' | 'cyan' | 'fuchsia'

export function Panel({
  title,
  description,
  action,
  children,
  className,
  accent = 'slate',
  density = 'normal',
}: {
  title?: string
  description?: string
  action?: ReactNode
  children: ReactNode
  className?: string
  accent?: PanelAccent
  density?: 'normal' | 'compact'
}) {
  return (
    <section
      aria-label={title}
      className={clsx(
        'app-panel relative overflow-hidden rounded-lg border bg-white/[0.92] shadow-[0_18px_55px_rgba(15,23,42,0.07),0_1px_2px_rgba(15,23,42,0.04)] backdrop-blur',
        density === 'compact' ? 'p-4' : 'p-5',
        panelAccentClassName(accent),
        className,
      )}
    >
      {(title || description || action) && (
        <div
          className={clsx(
            'app-panel__header flex flex-col gap-4 border-b border-slate-100/80',
            density === 'compact' ? 'mb-3 pb-3' : 'mb-4 pb-4',
          )}
        >
          <div className="min-w-0">
            {title && <h2 className="text-base font-semibold tracking-[-0.01em] text-slate-950">{title}</h2>}
            {description && <p className="mt-1 text-sm leading-5 text-slate-500">{description}</p>}
          </div>
          {action && <div className="app-panel__action w-full shrink-0">{action}</div>}
        </div>
      )}
      {children}
    </section>
  )
}

export function SectionGrid({
  children,
  variant = 'balanced',
  className,
}: {
  children: ReactNode
  variant?: 'balanced' | 'wideLeft' | 'wideRight' | 'compactLeft' | 'three'
  className?: string
}) {
  return (
    <div
      className={clsx(
        'grid items-start gap-6',
        variant === 'balanced' && 'xl:grid-cols-2',
        variant === 'wideLeft' && 'xl:grid-cols-[minmax(0,1.35fr)_minmax(320px,0.65fr)]',
        variant === 'wideRight' && 'xl:grid-cols-[minmax(320px,0.65fr)_minmax(0,1.35fr)]',
        variant === 'compactLeft' && 'xl:grid-cols-[minmax(280px,0.55fr)_minmax(0,1.45fr)]',
        variant === 'three' && 'xl:grid-cols-3',
        className,
      )}
    >
      {children}
    </div>
  )
}

function panelAccentClassName(accent: PanelAccent): string {
  if (accent === 'blue') {
    return 'border-blue-200/80 shadow-blue-950/5'
  }

  if (accent === 'emerald') {
    return 'border-emerald-200/90 shadow-emerald-950/5'
  }

  if (accent === 'amber') {
    return 'border-amber-200/90 shadow-amber-950/5'
  }

  if (accent === 'rose') {
    return 'border-rose-200/90 shadow-rose-950/5'
  }

  if (accent === 'violet') {
    return 'border-violet-200/90 shadow-violet-950/5'
  }

  if (accent === 'cyan') {
    return 'border-cyan-200/90 shadow-cyan-950/5'
  }

  if (accent === 'fuchsia') {
    return 'border-fuchsia-200/90 shadow-fuchsia-950/5'
  }

  return 'border-slate-200/90 shadow-slate-950/5'
}

export function Button({
  variant = 'primary',
  className,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost'
}) {
  return (
    <button
      className={clsx(
        'inline-flex min-h-10 items-center justify-center gap-2 rounded-lg px-4 text-sm font-semibold transition duration-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:cursor-not-allowed disabled:opacity-50',
        variant === 'primary' &&
          'bg-slate-950 text-white shadow-[0_10px_24px_rgba(15,23,42,0.18)] hover:-translate-y-0.5 hover:bg-slate-800 focus-visible:outline-slate-950',
        variant === 'secondary' &&
          'border border-slate-200/80 bg-white/90 text-slate-800 shadow-sm shadow-slate-200/60 hover:-translate-y-0.5 hover:border-slate-300 hover:bg-white',
        variant === 'danger' &&
          'bg-red-600 text-white shadow-[0_10px_24px_rgba(185,28,28,0.16)] hover:-translate-y-0.5 hover:bg-red-700 focus-visible:outline-red-600',
        variant === 'ghost' && 'text-slate-600 hover:bg-slate-100/80 hover:text-slate-950',
        className,
      )}
      {...props}
    />
  )
}

export function Field({
  label,
  children,
  hint,
}: {
  label: string
  children: ReactNode
  hint?: string
}) {
  return (
    <label className="block">
      <span className="text-sm font-semibold text-slate-700">{label}</span>
      <div className="mt-1">{children}</div>
      {hint && <span className="mt-1 block text-xs text-slate-500">{hint}</span>}
    </label>
  )
}

export function TextInput({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={clsx(
        'h-10 w-full rounded-lg border border-slate-200/90 bg-white/95 px-3 text-sm text-slate-950 shadow-sm shadow-slate-200/70 outline-none transition placeholder:text-slate-400 focus:border-cyan-400 focus:ring-4 focus:ring-cyan-100',
        className,
      )}
      {...props}
    />
  )
}

export function SelectInput({ className, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={clsx(
        'h-10 w-full rounded-lg border border-slate-200/90 bg-white/95 px-3 text-sm text-slate-950 shadow-sm shadow-slate-200/70 outline-none transition focus:border-cyan-400 focus:ring-4 focus:ring-cyan-100',
        className,
      )}
      {...props}
    />
  )
}

export function TextArea({ className, ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      className={clsx(
        'min-h-24 w-full rounded-lg border border-slate-200/90 bg-white/95 px-3 py-2 text-sm text-slate-950 shadow-sm shadow-slate-200/70 outline-none transition placeholder:text-slate-400 focus:border-cyan-400 focus:ring-4 focus:ring-cyan-100',
        className,
      )}
      {...props}
    />
  )
}

export function MoneyMetric({
  label,
  value,
  tone = 'neutral',
  breakdown,
  open,
  onOpenChange,
}: {
  label: string
  value: string
  tone?: 'neutral' | 'primary' | 'good' | 'warning' | 'bad'
  breakdown?: CalculationBreakdown
  open?: boolean
  onOpenChange?: (isOpen: boolean) => void
}) {
  const isPrimary = tone === 'primary'
  const className = clsx(
    'relative h-fit self-start overflow-hidden rounded-lg border p-4 shadow-[0_16px_42px_rgba(15,23,42,0.06)]',
    metricCardClassName(tone),
  )
  const labelClassName = isPrimary ? 'text-slate-300' : metricLabelClassName(tone)
  const valueClassName = isPrimary ? 'text-white' : 'text-slate-950'

  if (!breakdown) {
    return (
      <div className={className}>
        <p className={clsx('text-xs font-semibold uppercase tracking-wide', labelClassName)}>{label}</p>
        <p className={clsx('mt-2 text-2xl font-semibold tracking-[-0.02em]', valueClassName)}>{value}</p>
        <MetricSparkline tone={tone} />
      </div>
    )
  }

  return (
    <details
      className={clsx(className, 'group')}
      open={open}
      onToggle={(event) => onOpenChange?.(event.currentTarget.open)}
    >
      <summary className="-m-2 cursor-pointer list-none rounded-md p-2 outline-none transition focus-visible:ring-4 focus-visible:ring-slate-200">
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className={clsx('text-xs font-semibold uppercase tracking-wide', labelClassName)}>{label}</p>
            <p className={clsx('mt-2 text-2xl font-semibold tracking-[-0.02em]', valueClassName)}>{value}</p>
          </div>
          <ChevronDown
            size={18}
            className={clsx('mt-1 shrink-0 transition group-open:rotate-180', isPrimary ? 'text-slate-300' : 'text-slate-500')}
          />
        </div>
        <p className={clsx('mt-3 text-xs font-semibold', isPrimary ? 'text-slate-300' : 'text-slate-500')}>
          Show calculation
        </p>
        <MetricSparkline tone={tone} />
      </summary>
      <CalculationDetails breakdown={breakdown} inverted={isPrimary} />
    </details>
  )
}

function metricCardClassName(tone: 'neutral' | 'primary' | 'good' | 'warning' | 'bad'): string {
  if (tone === 'primary') {
    return 'border-slate-900 bg-[linear-gradient(135deg,#020617,#071526_54%,#0f2d36)] text-white shadow-slate-950/15'
  }

  if (tone === 'good') {
    return 'border-emerald-200/90 bg-[linear-gradient(135deg,#ffffff,#ecfdf5)]'
  }

  if (tone === 'warning') {
    return 'border-amber-200/90 bg-[linear-gradient(135deg,#ffffff,#fffbeb)]'
  }

  if (tone === 'bad') {
    return 'border-red-200/90 bg-[linear-gradient(135deg,#ffffff,#fef2f2)]'
  }

  return 'border-slate-200/90 bg-[linear-gradient(135deg,#ffffff,#f8fafc)]'
}

function metricLabelClassName(tone: 'neutral' | 'primary' | 'good' | 'warning' | 'bad'): string {
  if (tone === 'good') {
    return 'text-emerald-700'
  }

  if (tone === 'warning') {
    return 'text-amber-700'
  }

  if (tone === 'bad') {
    return 'text-red-700'
  }

  return 'text-slate-500'
}

function metricSparklineClassName(tone: 'neutral' | 'primary' | 'good' | 'warning' | 'bad'): string {
  if (tone === 'primary') {
    return 'bg-emerald-300/80'
  }

  if (tone === 'good') {
    return 'bg-emerald-500/70'
  }

  if (tone === 'warning') {
    return 'bg-amber-400/80'
  }

  if (tone === 'bad') {
    return 'bg-red-400/80'
  }

  return 'bg-cyan-500/60'
}

function MetricSparkline({ tone }: { tone: 'neutral' | 'primary' | 'good' | 'warning' | 'bad' }) {
  const bars = [31, 42, 28, 55, 47, 36, 64, 72, 58, 44, 39, 68, 76, 61, 49, 34, 26, 46, 59, 71]

  return (
    <div className="mt-4 flex h-7 items-end gap-1.5" aria-hidden="true">
      {bars.map((height, index) => (
        <span
          key={`${height}-${index}`}
          className={clsx('w-1 flex-1 rounded-full opacity-80', index > 13 && 'opacity-25', metricSparklineClassName(tone))}
          style={{ height: `${height}%` }}
        />
      ))}
    </div>
  )
}

export function CalculationDetails({
  breakdown,
  inverted = false,
}: {
  breakdown: CalculationBreakdown
  inverted?: boolean
}) {
  return (
    <div
      className={clsx(
        'mt-4 rounded-lg border p-3',
        inverted ? 'border-white/10 bg-white/10' : 'border-slate-200/80 bg-white/80',
      )}
    >
      {breakdown.formula && (
        <p className={clsx('text-xs leading-5', inverted ? 'text-slate-200' : 'text-slate-500')}>
          {breakdown.formula}
        </p>
      )}
      <div className="mt-3 space-y-2">
        {breakdown.lines.map((line) => (
          <div key={`${line.label}-${line.value}`} className="grid grid-cols-[1fr_auto] gap-3 text-sm">
            <div className="min-w-0">
              <p className={clsx('font-medium', inverted ? 'text-slate-100' : 'text-slate-700')}>{line.label}</p>
              {line.detail && (
                <p className={clsx('mt-0.5 text-xs leading-5', inverted ? 'text-slate-300' : 'text-slate-500')}>
                  {line.detail}
                </p>
              )}
            </div>
            <p className={clsx('font-semibold', calculationLineValueClass(line.tone, inverted))}>{line.value}</p>
          </div>
        ))}
      </div>
      {breakdown.note && (
        <p className={clsx('mt-3 border-t pt-3 text-xs leading-5', inverted ? 'border-white/10 text-slate-300' : 'border-slate-100 text-slate-500')}>
          {breakdown.note}
        </p>
      )}
    </div>
  )
}

function calculationLineValueClass(tone: CalculationLine['tone'] = 'neutral', inverted: boolean): string {
  if (tone === 'add') {
    return inverted ? 'text-emerald-200' : 'text-emerald-700'
  }

  if (tone === 'subtract') {
    return inverted ? 'text-red-200' : 'text-red-700'
  }

  if (tone === 'result') {
    return inverted ? 'text-white' : 'text-slate-950'
  }

  if (tone === 'muted') {
    return inverted ? 'text-slate-300' : 'text-slate-500'
  }

  return inverted ? 'text-slate-100' : 'text-slate-700'
}
