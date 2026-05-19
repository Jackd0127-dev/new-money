import {
  formatPence,
  getPayPeriodMoneySummary,
  getRecurringPaymentOccurrences,
} from '../domain/money'
import type { PlannerSnapshot } from '../hooks/usePlannerData'
import type { DailyBriefController } from '../hooks/useDailyBrief'
import { Button, Panel } from '../components/ui'
import type { ViewKey } from '../types/navigation'

export function DashboardPage({
  snapshot,
  onViewChange,
  dailyBrief,
}: {
  snapshot: PlannerSnapshot
  onViewChange: (view: ViewKey) => void
  dailyBrief?: DailyBriefController
}) {
  const latestPeriod = snapshot.payPeriods[0] ?? null
  const periodAllocations = latestPeriod
    ? snapshot.potAllocations.filter((allocation) => allocation.payPeriodId === latestPeriod.id)
    : []
  const paymentOccurrences = latestPeriod
    ? getRecurringPaymentOccurrences(snapshot.recurringPayments, latestPeriod.startDate, latestPeriod.endDate)
    : []
  const summary = latestPeriod
    ? getPayPeriodMoneySummary({
        incomePence: latestPeriod.incomePence,
        duePayments: paymentOccurrences.map((occurrence) => occurrence.payment),
        allocations: periodAllocations,
      })
    : null

  return (
    <div className="space-y-6">
      {dailyBrief && dailyBrief.status !== 'signed-out' && (
        <Panel
          title="Today's Gemini run-through"
          description="Generated once per day from your signed-in planner data."
          action={
            <Button
              variant="secondary"
              onClick={() => void dailyBrief.regenerate()}
              disabled={dailyBrief.status === 'generating'}
            >
              Refresh brief
            </Button>
          }
        >
          {dailyBrief.currentBrief ? (
            <p className="whitespace-pre-line rounded-lg bg-slate-50 p-4 text-sm leading-6 text-slate-700">
              {dailyBrief.currentBrief.content}
            </p>
          ) : dailyBrief.status === 'generating' ? (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">
              Generating today's run-through.
            </p>
          ) : dailyBrief.status === 'error' ? (
            <p className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
              {dailyBrief.error ?? "Unable to generate today's run-through."}
            </p>
          ) : (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">
              Today's run-through will appear after sign-in and sync finish.
            </p>
          )}
        </Panel>
      )}

      <Panel
        title="Current pay period"
        description={
          latestPeriod
            ? `${latestPeriod.startDate} to ${latestPeriod.endDate} · next payday ${latestPeriod.nextPayday}`
            : 'Create your first paycheck plan to see your pay, payments due, and money left.'
        }
        action={<Button onClick={() => onViewChange('payday')}>{latestPeriod ? 'Update pay' : 'Plan pay'}</Button>}
      >
        {latestPeriod && summary ? (
          <>
            <div className="grid gap-4 lg:grid-cols-3">
              <PaySummaryCard
                label="Pay received"
                value={formatPence(summary.payReceivedPence)}
                tone="primary"
              />
              <PaySummaryCard
                label="Total payments due"
                value={formatPence(summary.totalPaymentsDuePence)}
                tone="warning"
              />
              <PaySummaryCard
                label="Money left"
                value={formatPence(summary.moneyLeftPence)}
                tone={summary.moneyLeftPence < 0 ? 'bad' : 'good'}
              />
            </div>

            {summary.uncoveredRecurringPence > 0 && (
              <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
                {formatPence(summary.uncoveredRecurringPence)} of recurring payments due this period is not reserved in
                the current paycheck plan yet.
              </div>
            )}

            <div className="mt-5 rounded-lg border border-slate-200">
              <div className="flex items-center justify-between gap-3 border-b border-slate-200 px-4 py-3">
                <div>
                  <p className="text-sm font-semibold text-slate-950">Payments due this period</p>
                  <p className="mt-1 text-xs text-slate-500">Recurring payments between this payday and the next.</p>
                </div>
                <p className="text-sm font-semibold text-slate-950">
                  {formatPence(paymentOccurrences.reduce((total, occurrence) => total + occurrence.amountPence, 0))}
                </p>
              </div>
              <div className="divide-y divide-slate-100">
                {paymentOccurrences.length > 0 ? (
                  paymentOccurrences.map((occurrence) => (
                    <div
                      key={`${occurrence.payment.id}-${occurrence.dueDate}`}
                      className="grid grid-cols-[1fr_auto] items-center gap-4 px-4 py-3"
                    >
                      <div>
                        <p className="text-sm font-semibold text-slate-950">{occurrence.payment.name}</p>
                        <p className="mt-1 text-xs text-slate-500">
                          {formatShortDate(occurrence.dueDate)} · {occurrence.payment.frequency}
                        </p>
                      </div>
                      <p className="text-sm font-semibold text-slate-950">{formatPence(occurrence.amountPence)}</p>
                    </div>
                  ))
                ) : (
                  <p className="px-4 py-5 text-sm text-slate-500">No recurring payments are due in this pay period.</p>
                )}
              </div>
            </div>
          </>
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

function formatShortDate(value: string) {
  return new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'short',
  }).format(new Date(`${value}T00:00:00.000Z`))
}
