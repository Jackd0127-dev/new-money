import { AlertTriangle, CalendarDays } from 'lucide-react'

import {
  addIsoDays,
  formatPence,
  getRecurringPaymentOccurrences,
  toIsoDate,
} from '../domain/money'
import type { PlannerSnapshot } from '../hooks/usePlannerData'
import { Panel } from './ui'

export function RecurringCalendar({
  snapshot,
  horizonDays = 60,
}: {
  snapshot: PlannerSnapshot
  horizonDays?: number
}) {
  const today = toIsoDate(new Date())
  const latestPeriod = snapshot.payPeriods[0] ?? null
  const upcomingEndDate = addIsoDays(today, horizonDays)
  const upcomingOccurrences = getRecurringPaymentOccurrences(
    snapshot.recurringPayments,
    today,
    upcomingEndDate,
  )
  const dueBeforeNextPayday = latestPeriod
    ? upcomingOccurrences.filter((occurrence) => occurrence.dueDate <= latestPeriod.endDate)
    : []
  const dueBeforeNextPaydayPence = dueBeforeNextPayday.reduce(
    (total, occurrence) => total + occurrence.amountPence,
    0,
  )

  return (
    <Panel
      title="Recurring calendar"
      description={`Next ${horizonDays} days of bills, subscriptions, insurance, debt payments, and investment commitments.`}
      action={<CalendarDays className="text-slate-500" size={20} />}
    >
      <div className="grid gap-4 lg:grid-cols-[0.72fr_1.28fr]">
        <div className="space-y-3">
          <div className="rounded-lg border border-slate-200 bg-slate-50 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Before next payday</p>
            <p className="mt-2 text-2xl font-semibold text-slate-950">
              {formatPence(dueBeforeNextPaydayPence)}
            </p>
            <p className="mt-1 text-xs leading-5 text-slate-500">
              {latestPeriod ? `Due by ${latestPeriod.endDate}` : 'Create a paycheck plan to unlock period warnings.'}
            </p>
          </div>

          {dueBeforeNextPaydayPence > 0 && (
            <div className="flex gap-3 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-900">
              <AlertTriangle className="mt-0.5 shrink-0" size={18} />
              <p>Reserve these payments before treating pot balances as spendable.</p>
            </div>
          )}
        </div>

        <div className="space-y-3">
          {upcomingOccurrences.length > 0 ? (
            upcomingOccurrences.slice(0, 10).map((occurrence) => {
              const pot = snapshot.pots.find((candidate) => candidate.id === occurrence.payment.potId)
              const isBeforeNextPayday = latestPeriod
                ? occurrence.dueDate >= latestPeriod.startDate && occurrence.dueDate <= latestPeriod.endDate
                : false

              return (
                <div
                  key={`${occurrence.payment.id}-${occurrence.dueDate}`}
                  className="flex flex-col gap-3 rounded-lg border border-slate-200 bg-white px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="text-sm font-semibold text-slate-950">{occurrence.payment.name}</p>
                      {isBeforeNextPayday && (
                        <span className="rounded-md bg-amber-100 px-2 py-1 text-xs font-semibold text-amber-800">
                          Before payday
                        </span>
                      )}
                    </div>
                    <p className="mt-1 text-xs text-slate-500">
                      {formatCalendarDate(occurrence.dueDate)} · {occurrence.payment.frequency} ·{' '}
                      {pot?.name ?? 'Archived pot'}
                    </p>
                  </div>
                  <p className="text-sm font-semibold text-slate-950">{formatPence(occurrence.amountPence)}</p>
                </div>
              )
            })
          ) : (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">
              No active recurring payments are due in this window.
            </p>
          )}
        </div>
      </div>
    </Panel>
  )
}

function formatCalendarDate(value: string): string {
  return new Intl.DateTimeFormat('en-GB', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  }).format(new Date(`${value}T00:00:00.000Z`))
}
