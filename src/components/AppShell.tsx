import {
  Banknote,
  CalendarClock,
  CreditCard,
  CircleDollarSign,
  Clock3,
  Gauge,
  ListChecks,
  PiggyBank,
  Settings,
  Sparkles,
  TrendingUp,
  WalletCards,
} from 'lucide-react'
import { clsx } from 'clsx'

import type { ViewKey } from '../types/navigation'
import type { PayPeriod } from '../types/models'
import { Button } from './ui'

const navItems: Array<{
  key: ViewKey
  label: string
  icon: typeof Gauge
}> = [
  { key: 'dashboard', label: 'Dashboard', icon: Gauge },
  { key: 'payday', label: 'Pay day', icon: Banknote },
  { key: 'spending', label: 'Spending', icon: WalletCards },
  { key: 'allocatingPayments', label: 'Allocating Payments', icon: ListChecks },
  { key: 'recurring', label: 'Recurring', icon: CalendarClock },
  { key: 'pots', label: 'Pots', icon: PiggyBank },
  { key: 'savingsInvestments', label: 'Savings & Investments', icon: TrendingUp },
  { key: 'debts', label: 'Debts', icon: CreditCard },
  { key: 'calendar', label: 'Calendar', icon: CalendarClock },
  { key: 'aiPlan', label: 'AI', icon: Sparkles },
  { key: 'settings', label: 'Settings', icon: Settings },
]

export function AppShell({
  activeView,
  onViewChange,
  selectedPayPeriod,
  headerAction,
  children,
}: {
  activeView: ViewKey
  onViewChange: (view: ViewKey) => void
  selectedPayPeriod?: PayPeriod | null
  headerAction?: React.ReactNode
  children: React.ReactNode
}) {
  const activeItem = navItems.find((item) => item.key === activeView) ?? navItems[0]
  const ActiveIcon = activeItem.icon

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_16%_8%,rgba(45,212,191,0.16),transparent_28%),linear-gradient(180deg,#f8fbff_0%,#eef5f7_46%,#f7fafc_100%)] text-slate-900">
      <aside className="fixed inset-y-0 left-0 z-20 hidden w-64 overflow-hidden border-r border-white/10 bg-[radial-gradient(circle_at_18%_12%,rgba(20,184,166,0.20),transparent_30%),linear-gradient(180deg,#06122a_0%,#071a2d_48%,#06101f_100%)] px-4 py-5 text-white shadow-[18px_0_55px_rgba(15,23,42,0.16)] lg:block">
        <div className="pointer-events-none absolute inset-x-5 top-20 h-28 rounded-full bg-cyan-300/10 blur-3xl" />
        <div className="flex items-center gap-3 px-2">
          <div className="flex size-10 items-center justify-center rounded-lg bg-white p-2 text-slate-950 shadow-lg shadow-emerald-950/20">
            <img src="/favicon.svg" alt="" className="size-full" />
          </div>
          <div className="min-w-0">
            <p className="text-sm font-semibold text-white">Money Manager</p>
            <p className="text-xs font-medium text-slate-300">Private paycheck planning</p>
          </div>
        </div>

        <div className="relative mt-6 rounded-lg border border-white/10 bg-white/[0.08] p-3 shadow-2xl shadow-slate-950/20 backdrop-blur">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-[11px] font-semibold uppercase text-slate-400">Active workspace</p>
              <p className="mt-1 text-sm font-semibold text-white">{activeItem.label}</p>
            </div>
            <span className="flex size-9 items-center justify-center rounded-lg border border-white/10 bg-slate-950/35 text-emerald-200">
              <ActiveIcon size={17} />
            </span>
          </div>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <ShellTinyStat label="Paydays" value={selectedPayPeriod ? 'Live' : 'Setup'} />
            <ShellTinyStat label="Mode" value="Private" />
          </div>
        </div>

        <nav className="relative mt-5 space-y-1.5">
          {navItems.map((item) => {
            const Icon = item.icon

            return (
              <button
                key={item.key}
                type="button"
                onClick={() => onViewChange(item.key)}
                className={clsx(
                  'group flex w-full items-center gap-3 rounded-lg border px-3 py-2.5 text-left text-sm font-medium transition duration-200',
                  activeView === item.key
                    ? 'border-emerald-300/25 bg-[linear-gradient(135deg,rgba(20,184,166,0.46),rgba(34,211,238,0.18))] text-white shadow-[0_10px_26px_rgba(20,184,166,0.18)]'
                    : 'border-transparent text-slate-300 hover:border-white/10 hover:bg-white/[0.07] hover:text-white',
                )}
              >
                <span
                  className={clsx(
                    'flex size-7 shrink-0 items-center justify-center rounded-md border transition',
                    activeView === item.key
                      ? 'border-white/15 bg-white/15 text-white'
                      : 'border-transparent bg-white/[0.04] text-slate-400 group-hover:border-white/10 group-hover:text-white',
                  )}
                >
                  <Icon size={16} />
                </span>
                <span className="min-w-0 truncate">{item.label}</span>
              </button>
            )
          })}
        </nav>
        <div className="absolute inset-x-4 bottom-5 rounded-lg border border-white/10 bg-white/[0.08] p-3 text-sm shadow-2xl shadow-slate-950/20 backdrop-blur">
          <div className="flex items-start gap-3">
            <span className="flex size-9 shrink-0 items-center justify-center rounded-lg border border-white/10 bg-slate-950/35 text-cyan-200">
              <CircleDollarSign size={17} />
            </span>
            <div>
              <p className="font-semibold text-white">Paycheck flow</p>
              <p className="mt-1 text-xs leading-5 text-slate-300">Dashboard, pots, calendar, and cards stay in one workspace.</p>
            </div>
          </div>
        </div>
      </aside>

      <div className="lg:pl-64">
        <header className="sticky top-0 z-10 border-b border-white/70 bg-white/80 px-4 py-3 shadow-sm shadow-slate-200/60 backdrop-blur-xl md:px-8">
          <div className="flex flex-col items-start gap-3 xl:flex-row xl:items-center xl:justify-between">
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <span className="inline-flex items-center gap-2 rounded-lg border border-cyan-200/80 bg-cyan-50/80 px-2.5 py-1 text-xs font-semibold text-cyan-900">
                  <Clock3 size={13} />
                  Planner live
                </span>
                <span className="text-xs font-semibold text-slate-400">{activeItem.label}</span>
              </div>
              <h1 className="mt-1 text-xl font-semibold text-slate-950">Paycheck control panel</h1>
              <p className="hidden text-sm text-slate-500 sm:block">
                {selectedPayPeriod
                  ? `Viewing ${formatShellDate(selectedPayPeriod.startDate)} to ${formatShellDate(selectedPayPeriod.endDate)}`
                  : 'Plan pay, track costs, and keep cloud sync running.'}
                </p>
            </div>
            <div className="grid w-full gap-2 sm:grid-cols-[1fr_auto] xl:w-auto">
              {selectedPayPeriod && (
                <div className="hidden rounded-lg border border-slate-200/80 bg-white/80 px-3 py-2 text-sm shadow-sm shadow-slate-200/50 md:block">
                  <p className="text-[11px] font-semibold uppercase text-slate-400">Current window</p>
                  <p className="mt-0.5 font-semibold text-slate-950">
                    {formatShellDate(selectedPayPeriod.startDate)} to {formatShellDate(selectedPayPeriod.endDate)}
                  </p>
                </div>
              )}
              <Button className="w-full lg:w-auto" variant="secondary" onClick={() => onViewChange('spending')}>
                <WalletCards size={18} />
                <span className="hidden sm:inline">Log spend</span>
                <span className="sm:hidden">Spend</span>
              </Button>
              {headerAction}
            </div>
          </div>
          <nav className="mt-3 flex gap-2 overflow-x-auto pb-1 lg:hidden">
            {navItems.map((item) => {
              const Icon = item.icon

              return (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => onViewChange(item.key)}
                  className={clsx(
                    'inline-flex shrink-0 items-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium shadow-sm transition',
                    activeView === item.key
                      ? 'border-slate-950 bg-[linear-gradient(135deg,#020617,#0f172a)] text-white shadow-slate-300/60'
                      : 'border-slate-200 bg-white/80 text-slate-600 hover:border-slate-300 hover:bg-white',
                  )}
                >
                  <Icon size={16} />
                  {item.label}
                </button>
              )
            })}
          </nav>
        </header>
        <main className="mx-auto max-w-7xl px-4 py-6 md:px-8">{children}</main>
      </div>
    </div>
  )
}

function ShellTinyStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-white/10 bg-slate-950/25 px-2 py-1.5">
      <p className="text-[10px] font-semibold uppercase text-slate-400">{label}</p>
      <p className="mt-0.5 text-xs font-semibold text-white">{value}</p>
    </div>
  )
}

function formatShellDate(value: string): string {
  return new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'short',
    year: '2-digit',
  }).format(new Date(`${value}T00:00:00.000Z`))
}
