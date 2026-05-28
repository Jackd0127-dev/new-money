import type { ReactNode } from 'react'
import { BadgePoundSterling, CalendarDays, CircleDollarSign, Trash2, TrendingUp, WalletCards } from 'lucide-react'

import { formatPence } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, CalculationDetails, Panel, type CalculationBreakdown } from '../components/ui'

export function HistoryPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  return <PayPeriodHistoryPanel snapshot={snapshot} actions={actions} />
}

export function PayPeriodHistoryPanel({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  const totalIncomePence = snapshot.payPeriods.reduce((total, period) => total + period.incomePence, 0)
  const totalAllocatedPence = snapshot.payPeriods.reduce((total, period) => {
    const allocated = snapshot.potAllocations
      .filter((allocation) => allocation.payPeriodId === period.id)
      .reduce((allocationTotal, allocation) => allocationTotal + allocation.amountPence, 0)

    return total + allocated
  }, 0)
  const allocationRate = totalIncomePence > 0 ? Math.round((totalAllocatedPence / totalIncomePence) * 100) : 0
  const unallocatedPence = Math.max(0, totalIncomePence - totalAllocatedPence)
  const latestPeriods = snapshot.payPeriods.slice(0, 10)
  const maxHistoryIncomePence = Math.max(1, ...latestPeriods.map((period) => period.incomePence))

  async function deletePeriod(periodId: string, payday: string) {
    if (window.confirm(`Delete paycheck plan for ${payday}?`)) {
      await actions.deletePayPeriod(periodId)
    }
  }

  return (
    <Panel title="Pay period history" description="Previous paycheck plans and their allocations." accent="blue">
      <HistoryOverview
        latestPeriods={latestPeriods}
        maxHistoryIncomePence={maxHistoryIncomePence}
        totalIncomePence={totalIncomePence}
        totalAllocatedPence={totalAllocatedPence}
        unallocatedPence={unallocatedPence}
        allocationRate={allocationRate}
      />

      <div className="mb-4 mt-4 grid gap-3 md:grid-cols-3">
        <HistoryStat icon={<CalendarDays size={17} />} label="Paychecks" value={String(snapshot.payPeriods.length)} tone="blue" />
        <HistoryStat icon={<CircleDollarSign size={17} />} label="Total income" value={formatPence(totalIncomePence)} tone="emerald" />
        <HistoryStat icon={<WalletCards size={17} />} label="Total allocated" value={formatPence(totalAllocatedPence)} tone="violet" />
      </div>

      <div className="overflow-x-auto rounded-2xl border border-slate-200/90 bg-white/95 shadow-[0_16px_42px_rgba(15,23,42,0.06)]">
        <table className="w-full min-w-[720px] border-collapse text-left text-sm">
          <thead className="bg-slate-50/90 text-xs uppercase tracking-wide text-slate-500">
            <tr>
              <th className="px-4 py-3 font-semibold">Payday</th>
              <th className="px-4 py-3 font-semibold">Period</th>
              <th className="px-4 py-3 font-semibold">Income</th>
              <th className="px-4 py-3 font-semibold">Allocated</th>
              <th className="px-4 py-3 font-semibold">Status</th>
              <th className="px-4 py-3 font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-200/80 bg-white/95">
            {snapshot.payPeriods.length > 0 ? (
              snapshot.payPeriods.map((period) => {
                const allocated = snapshot.potAllocations
                  .filter((allocation) => allocation.payPeriodId === period.id)
                  .reduce((total, allocation) => total + allocation.amountPence, 0)
                const rowAllocationPercent = period.incomePence > 0 ? Math.round((allocated / period.incomePence) * 100) : 0
                const rowAllocationWidth = `${Math.min(100, Math.max(0, rowAllocationPercent))}%`

                return (
                  <tr key={period.id} className="transition hover:bg-slate-50/80">
                    <td className="px-4 py-3 font-medium text-slate-950">{period.payday}</td>
                    <td className="px-4 py-3 text-slate-600">
                      {period.startDate} to {period.endDate}
                    </td>
                    <td className="px-4 py-3 text-slate-950">{formatPence(period.incomePence)}</td>
                    <td className="px-4 py-3 text-slate-950">
                      <details>
                        <summary className="cursor-pointer list-none font-semibold text-slate-950">
                          {formatPence(allocated)}
                          <span className="ml-2 text-xs font-semibold text-slate-500">{rowAllocationPercent}%</span>
                        </summary>
                        <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-slate-100 shadow-inner shadow-slate-200/80">
                          <div className="h-full rounded-full bg-[linear-gradient(90deg,#2563eb,#06b6d4)]" style={{ width: rowAllocationWidth }} />
                        </div>
                        <CalculationDetails
                          breakdown={getHistoryAllocationBreakdown(
                            snapshot.potAllocations.filter((allocation) => allocation.payPeriodId === period.id),
                            snapshot,
                          )}
                        />
                      </details>
                    </td>
                    <td className="px-4 py-3">
                      <span className="rounded-md border border-slate-200/80 bg-white/80 px-2 py-1 text-xs font-semibold capitalize text-slate-600 shadow-sm shadow-slate-200/50">
                        {period.status}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <Button
                        variant="danger"
                        onClick={() => void deletePeriod(period.id, period.payday)}
                        aria-label={`Delete paycheck plan for ${period.payday}`}
                      >
                        <Trash2 size={16} />
                      </Button>
                    </td>
                  </tr>
                )
              })
            ) : (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-slate-500">
                  No paycheck history yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </Panel>
  )
}

function HistoryOverview({
  latestPeriods,
  maxHistoryIncomePence,
  totalIncomePence,
  totalAllocatedPence,
  unallocatedPence,
  allocationRate,
}: {
  latestPeriods: PlannerSnapshot['payPeriods']
  maxHistoryIncomePence: number
  totalIncomePence: number
  totalAllocatedPence: number
  unallocatedPence: number
  allocationRate: number
}) {
  const allocationWidth = `${Math.min(100, Math.max(0, allocationRate))}%`

  return (
    <section className="overflow-hidden rounded-2xl border border-slate-900 bg-[linear-gradient(135deg,#020617,#071526_54%,#0f2d36)] text-white shadow-[0_22px_65px_rgba(15,23,42,0.18)]">
      <div className="grid gap-5 p-5 lg:grid-cols-[minmax(0,1fr)_minmax(260px,0.45fr)] lg:items-end">
        <div className="min-w-0">
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-cyan-200">
            <TrendingUp size={15} />
            Paycheck history
          </div>
          <p className="mt-4 text-4xl font-semibold tracking-[-0.04em] text-white">{formatPence(totalIncomePence)}</p>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
            {latestPeriods.length > 0
              ? `Latest paycheck ${latestPeriods[0].payday} was ${formatPence(latestPeriods[0].incomePence)}.`
              : 'Create a paycheck plan to start building a history.'}
          </p>
        </div>
        <div className="rounded-2xl border border-white/10 bg-white/10 p-4 shadow-inner shadow-white/10">
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-300">
            <BadgePoundSterling size={15} />
            Allocated rate
          </div>
          <p className="mt-2 text-2xl font-semibold tracking-[-0.02em] text-white">{allocationRate}%</p>
          <p className="mt-1 text-xs leading-5 text-slate-300">
            {formatPence(totalAllocatedPence)} allocated · {formatPence(unallocatedPence)} not allocated
          </p>
          <div className="mt-3 h-2 overflow-hidden rounded-full bg-white/15 shadow-inner shadow-slate-950/20">
            <div className="h-full rounded-full bg-[linear-gradient(90deg,#34d399,#22d3ee)]" style={{ width: allocationWidth }} />
          </div>
        </div>
      </div>
      {latestPeriods.length > 0 && (
        <div className="border-t border-white/10 bg-white/[0.06] p-4">
          <div className="mb-3 flex items-center justify-between gap-3 text-xs font-semibold uppercase tracking-wide text-slate-300">
            <span>Pay rhythm</span>
            <span>Newest first</span>
          </div>
          <div className="flex h-20 items-end gap-1.5" aria-hidden="true">
            {latestPeriods.map((period) => (
              <span
                key={period.id}
                className="min-w-3 flex-1 rounded-t-lg bg-cyan-300/75 shadow-sm"
                style={{ height: `${Math.max(12, Math.round((period.incomePence / maxHistoryIncomePence) * 100))}%` }}
                title={`${period.payday}: ${formatPence(period.incomePence)}`}
              />
            ))}
          </div>
        </div>
      )}
    </section>
  )
}

function HistoryStat({
  icon,
  label,
  value,
  tone,
}: {
  icon: ReactNode
  label: string
  value: string
  tone: 'blue' | 'emerald' | 'violet'
}) {
  const toneClassName =
    tone === 'emerald'
      ? 'border-emerald-200 bg-[linear-gradient(135deg,#ffffff,#ecfdf5)] text-emerald-700'
      : tone === 'violet'
        ? 'border-violet-200 bg-[linear-gradient(135deg,#ffffff,#f5f3ff)] text-violet-700'
        : 'border-blue-200 bg-[linear-gradient(135deg,#ffffff,#eff6ff)] text-blue-700'

  return (
    <div className={`rounded-2xl border p-4 shadow-[0_14px_35px_rgba(15,23,42,0.05)] ${toneClassName}`}>
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide">
        {icon}
        {label}
      </div>
      <p className="mt-2 text-xl font-semibold tracking-[-0.02em] text-slate-950">{value}</p>
    </div>
  )
}

function getHistoryAllocationBreakdown(
  allocations: PlannerSnapshot['potAllocations'],
  snapshot: PlannerSnapshot,
): CalculationBreakdown {
  const allocatedPence = allocations.reduce((total, allocation) => total + allocation.amountPence, 0)

  return {
    formula: 'Allocated = recurring reserves plus any manual allocations saved on that paycheck plan.',
    lines:
      allocations.length > 0
        ? [
            ...allocations.map((allocation) => {
              const pot = snapshot.pots.find((candidate) => candidate.id === allocation.potId)
              const payment = allocation.recurringPaymentId
                ? snapshot.recurringPayments.find((candidate) => candidate.id === allocation.recurringPaymentId)
                : null

              return {
                label: payment?.name ?? pot?.name ?? 'Deleted pot',
                value: formatPence(allocation.amountPence),
                detail: allocation.source === 'recurring' ? 'Recurring reserve' : 'Manual allocation',
                tone: 'add' as const,
              }
            }),
            {
              label: 'Allocated',
              value: formatPence(allocatedPence),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No allocations', value: formatPence(0), tone: 'result' }],
  }
}
