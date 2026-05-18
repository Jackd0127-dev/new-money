import { useEffect, useState } from 'react'
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'

import {
  formatPence,
  getDailySafeToSpendPence,
  getRecurringPaymentOccurrences,
  getRecurringPaymentsDue,
  getSpendablePence,
  getTotalPence,
  getUncoveredRecurringPence,
  addIsoDays,
  toIsoDate,
} from '../domain/money'
import type { PlannerSnapshot } from '../hooks/usePlannerData'
import { BudgetInsights } from '../components/BudgetInsights'
import { PotRows } from '../components/PotRows'
import { Button, MoneyMetric, Panel } from '../components/ui'
import type { ViewKey } from '../types/navigation'

export function DashboardPage({
  snapshot,
  onViewChange,
}: {
  snapshot: PlannerSnapshot
  onViewChange: (view: ViewKey) => void
}) {
  const chartWidth = useDashboardChartWidth()
  const activePots = snapshot.pots.filter((pot) => !pot.archived)
  const latestPeriod = snapshot.payPeriods[0] ?? null
  const spendablePence = getSpendablePence(activePots)
  const periodAllocations = latestPeriod
    ? snapshot.potAllocations.filter((allocation) => allocation.payPeriodId === latestPeriod.id)
    : []
  const today = toIsoDate(new Date())
  const upcomingPayments = latestPeriod
    ? getRecurringPaymentsDue(
        snapshot.recurringPayments,
        latestPeriod.startDate,
        latestPeriod.endDate,
      )
    : []
  const upcomingOccurrences = latestPeriod
    ? getRecurringPaymentOccurrences(snapshot.recurringPayments, today, latestPeriod.endDate)
    : getRecurringPaymentOccurrences(snapshot.recurringPayments, today, addIsoDays(today, 30))
  const reservedPence = getTotalPence(upcomingPayments)
  const allocatedPence = getTotalPence(periodAllocations)
  const unreservedPence = getUncoveredRecurringPence(upcomingPayments, periodAllocations)
  const availableAfterBillsPence = spendablePence - unreservedPence
  const payLeftAfterPlanPence = latestPeriod
    ? latestPeriod.incomePence - allocatedPence - unreservedPence
    : 0
  const safeToSpendPence = latestPeriod
    ? getDailySafeToSpendPence(availableAfterBillsPence, today, latestPeriod.endDate)
    : 0
  const potChartData = activePots.map((pot) => ({
    name: pot.name,
    balance: pot.balancePence / 100,
  }))
  const historyData = snapshot.payPeriods
    .slice(0, 6)
    .reverse()
    .map((period) => ({
      name: period.payday.slice(5),
      income: period.incomePence / 100,
    }))

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <MoneyMetric
          label="Available after bills"
          value={formatPence(availableAfterBillsPence)}
          tone={availableAfterBillsPence < 0 ? 'bad' : 'good'}
        />
        <MoneyMetric label="Safe today" value={formatPence(safeToSpendPence)} tone={safeToSpendPence < 0 ? 'bad' : 'neutral'} />
        <MoneyMetric label="Bills due this period" value={formatPence(reservedPence)} tone="warning" />
        <MoneyMetric label="Next payday" value={latestPeriod?.nextPayday ?? 'Not planned'} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.3fr_0.7fr]">
        <Panel
          title="Current pay period"
          description={
            latestPeriod
              ? `${latestPeriod.startDate} to ${latestPeriod.endDate}`
              : 'Create your first paycheck plan to unlock the live control panel.'
          }
          action={<Button onClick={() => onViewChange('payday')}>Plan pay</Button>}
        >
          {latestPeriod ? (
            <>
              <div className="grid gap-4 md:grid-cols-3">
                <div className="rounded-lg bg-slate-950 p-5 text-white">
                  <p className="text-sm text-slate-300">Pay received</p>
                  <p className="mt-3 text-3xl font-semibold">{formatPence(latestPeriod.incomePence)}</p>
                </div>
                <div className="rounded-lg bg-slate-100 p-5">
                  <p className="text-sm text-slate-500">Allocated from pay</p>
                  <p className="mt-3 text-3xl font-semibold text-slate-950">{formatPence(allocatedPence)}</p>
                </div>
                <div className="rounded-lg bg-slate-100 p-5">
                  <p className="text-sm text-slate-500">Left after plan</p>
                  <p className="mt-3 text-3xl font-semibold text-slate-950">{formatPence(payLeftAfterPlanPence)}</p>
                </div>
              </div>
              {unreservedPence > 0 && (
                <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
                  {formatPence(unreservedPence)} of recurring bills due this period is not covered by the current paycheck plan.
                </div>
              )}
            </>
          ) : (
            <div className="rounded-lg border border-dashed border-slate-300 bg-slate-50 p-8 text-center">
              <p className="text-base font-semibold text-slate-950">No paycheck plan yet</p>
              <p className="mx-auto mt-2 max-w-lg text-sm leading-6 text-slate-500">
                Enter your first pay, reserve recurring bills, and allocate the rest into pots.
              </p>
            </div>
          )}
        </Panel>

        <Panel title="Upcoming bills" description="Due dates before the next payday stay visible here.">
          <div className="space-y-3">
            {upcomingOccurrences.length > 0 ? (
              upcomingOccurrences.slice(0, 6).map((occurrence) => (
                <div
                  key={`${occurrence.payment.id}-${occurrence.dueDate}`}
                  className="flex items-center justify-between rounded-lg bg-slate-50 px-4 py-3"
                >
                  <div>
                    <p className="text-sm font-semibold text-slate-950">{occurrence.payment.name}</p>
                    <p className="text-xs text-slate-500">
                      {formatShortDate(occurrence.dueDate)} · {occurrence.payment.frequency}
                    </p>
                  </div>
                  <p className="text-sm font-semibold text-slate-950">{formatPence(occurrence.amountPence)}</p>
                </div>
              ))
            ) : (
              <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">
                No recurring payments are due in the current pay period.
              </p>
            )}
          </div>
        </Panel>
      </div>

      <BudgetInsights snapshot={snapshot} chartWidth={chartWidth} />

      <div className="grid gap-6 xl:grid-cols-[0.6fr_1.4fr]">
        <Panel title="Pot balances">
          <PotRows pots={activePots.slice(0, 6)} />
        </Panel>

        <Panel title="Money shape" description="Balances by pot and recent pay history.">
          <div className="space-y-6">
            <div className="h-72 min-w-0 overflow-x-auto">
              <BarChart data={potChartData} width={chartWidth} height={288}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="name" tickLine={false} axisLine={false} fontSize={12} />
                <YAxis tickLine={false} axisLine={false} fontSize={12} />
                <Tooltip formatter={(value) => formatPence(Number(value) * 100)} />
                <Bar dataKey="balance" fill="#0f172a" radius={[6, 6, 0, 0]} />
              </BarChart>
            </div>
            <div className="h-72 min-w-0 overflow-x-auto">
              <AreaChart data={historyData} width={chartWidth} height={288}>
                <defs>
                  <linearGradient id="income" x1="0" x2="0" y1="0" y2="1">
                    <stop offset="5%" stopColor="#2563eb" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#2563eb" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="name" tickLine={false} axisLine={false} fontSize={12} />
                <YAxis tickLine={false} axisLine={false} fontSize={12} />
                <Tooltip formatter={(value) => formatPence(Number(value) * 100)} />
                <Area dataKey="income" stroke="#2563eb" fill="url(#income)" strokeWidth={2} />
              </AreaChart>
            </div>
          </div>
        </Panel>
      </div>
    </div>
  )
}

function formatShortDate(value: string) {
  return new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'short',
  }).format(new Date(`${value}T00:00:00.000Z`))
}

function useDashboardChartWidth() {
  const [chartWidth, setChartWidth] = useState(getDashboardChartWidth)

  useEffect(() => {
    const updateWidth = () => setChartWidth(getDashboardChartWidth())
    window.addEventListener('resize', updateWidth)

    return () => window.removeEventListener('resize', updateWidth)
  }, [])

  return chartWidth
}

function getDashboardChartWidth() {
  if (typeof window === 'undefined') {
    return 840
  }

  const viewportWidth = window.innerWidth
  const availableWidth = viewportWidth >= 1024 ? viewportWidth - 600 : viewportWidth - 72

  return Math.max(280, Math.min(840, availableWidth))
}
