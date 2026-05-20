import {
  formatPence,
  getPayPeriodCostSummary,
} from '../domain/money'
import type { PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Panel } from '../components/ui'
import type { ViewKey } from '../types/navigation'

export function DashboardPage({
  snapshot,
  onViewChange,
}: {
  snapshot: PlannerSnapshot
  onViewChange: (view: ViewKey) => void
}) {
  const latestPeriod = snapshot.payPeriods[0] ?? null
  const summary = getPayPeriodCostSummary({
    payPeriod: latestPeriod,
    recurringPayments: snapshot.recurringPayments,
    customPayments: snapshot.customPayments,
    transactions: snapshot.transactions,
    debts: snapshot.debts,
    creditCardRepayments: snapshot.creditCardRepayments,
  })

  return (
    <div className="space-y-6">
      <Panel
        title="Current pay period"
        description={
          latestPeriod
            ? `${latestPeriod.startDate} to ${latestPeriod.endDate} · next payday ${latestPeriod.nextPayday}`
            : 'Create your first paycheck plan to see your pay, payments due, and money left.'
        }
        action={<Button onClick={() => onViewChange('payday')}>{latestPeriod ? 'Update pay' : 'Plan pay'}</Button>}
      >
        {latestPeriod ? (
          <div className="grid gap-4 lg:grid-cols-3">
            <PaySummaryCard
              label="Total pay"
              value={formatPence(summary.payReceivedPence)}
              tone="primary"
            />
            <PaySummaryCard
              label="Total costs"
              value={formatPence(summary.totalCostsPence)}
              tone="warning"
            />
            <PaySummaryCard
              label="Money left"
              value={formatPence(summary.moneyLeftPence)}
              tone={summary.moneyLeftPence < 0 ? 'bad' : 'good'}
            />
          </div>
        ) : (
          <div className="rounded-lg border border-dashed border-slate-300 bg-slate-50 p-8 text-center">
            <p className="text-base font-semibold text-slate-950">No paycheck plan yet</p>
            <p className="mx-auto mt-2 max-w-lg text-sm leading-6 text-slate-500">
              Enter your pay and recurring payments to get one clear dashboard total.
            </p>
          </div>
        )}
      </Panel>
    </div>
  )
}

function PaySummaryCard({
  label,
  value,
  tone,
}: {
  label: string
  value: string
  tone: 'primary' | 'warning' | 'good' | 'bad'
}) {
  const className =
    tone === 'primary'
      ? 'bg-slate-950 text-white'
      : tone === 'warning'
        ? 'border border-amber-200 bg-amber-50 text-slate-950'
        : tone === 'good'
          ? 'border border-emerald-200 bg-emerald-50 text-slate-950'
          : 'border border-red-200 bg-red-50 text-slate-950'
  const labelClassName = tone === 'primary' ? 'text-slate-300' : 'text-slate-500'

  return (
    <div className={`rounded-lg p-5 ${className}`}>
      <p className={`text-sm font-medium ${labelClassName}`}>{label}</p>
      <p className="mt-3 text-3xl font-semibold">{value}</p>
    </div>
  )
}
