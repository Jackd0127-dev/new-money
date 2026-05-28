import { useState, type ReactNode } from 'react'
import { ArrowRight, CalendarDays, CheckCircle2, Clock3, WalletCards } from 'lucide-react'

import {
  calculatePaycheckAmount,
  createNextPayPeriod,
  formatPence,
  getAppTodayIso,
  parsePoundsToPence,
} from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { PayPeriodHistoryPanel } from './HistoryPage'
import {
  Button,
  Field,
  MoneyMetric,
  Panel,
  SectionGrid,
  SelectInput,
  TextInput,
  type CalculationBreakdown,
  type CalculationLine,
} from '../components/ui'
import type { PayFrequency, PayPeriod } from '../types/models'

export function PaydayWizardPage({
  snapshot,
  actions,
  selectedPayPeriod,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
  selectedPayPeriod?: PayPeriod | null
}) {
  const initialDraft = getPaydayDraft(
    snapshot,
    selectedPayPeriod?.payday ?? snapshot.payPeriods[0]?.payday ?? getAppTodayIso(snapshot.settings),
  )
  const [payday, setPayday] = useState(initialDraft.payday)
  const [hoursWorked, setHoursWorked] = useState(initialDraft.hoursWorked)
  const [hourlyRate, setHourlyRate] = useState(initialDraft.hourlyRate)
  const [payFrequency, setPayFrequency] = useState<PayFrequency>(initialDraft.payFrequency)
  const [actualReceived, setActualReceived] = useState(initialDraft.actualReceived)
  const [saved, setSaved] = useState(false)

  const hasValidPayday = isValidIsoDateInput(payday)
  const existingPeriod = snapshot.payPeriods.find((candidate) => candidate.payday === payday) ?? null
  const period = hasValidPayday ? createNextPayPeriod(payday, payFrequency) : null
  const hours = Number.parseFloat(hoursWorked) || 0
  const hourlyRatePence = parsePoundsToPence(hourlyRate)
  const actualAmountPence = actualReceived ? parsePoundsToPence(actualReceived) : null
  const incomePence = calculatePaycheckAmount({
    hoursWorked: hours,
    hourlyRatePence,
    actualAmountPence,
  })
  const calculatedPence = calculatePaycheckAmount({
    hoursWorked: hours,
    hourlyRatePence,
  })
  const canSubmit = hasValidPayday && incomePence > 0
  const payPeriodDays = period ? getDaysBetween(period.startDate, period.endDate) + 1 : 0
  const actualOverrideDifferencePence = actualAmountPence === null ? 0 : actualAmountPence - calculatedPence

  function loadPayday(nextPayday: string) {
    const draft = getPaydayDraft(snapshot, nextPayday)

    setPayday(draft.payday)
    setHoursWorked(draft.hoursWorked)
    setHourlyRate(draft.hourlyRate)
    setPayFrequency(draft.payFrequency)
    setActualReceived(draft.actualReceived)
    setSaved(false)
  }

  async function submitPlan() {
    if (!canSubmit || saved) {
      return
    }

    await actions.createPaycheckPlan({
      payday,
      payFrequency,
      hoursWorked: hours,
      hourlyRatePence,
      actualAmountPence,
      allocations: [],
    })
    setSaved(true)
  }

  return (
    <div className="space-y-6">
      <section className="overflow-hidden rounded-lg border border-slate-900 bg-[radial-gradient(circle_at_16%_16%,rgba(16,185,129,0.24),transparent_28%),linear-gradient(135deg,#020617,#072019_50%,#0f172a)] shadow-[0_24px_70px_rgba(15,23,42,0.18)]">
        <div className="grid gap-6 p-5 text-white xl:grid-cols-[1.05fr_1fr] xl:items-end">
          <div>
            <div className="inline-flex items-center gap-2 rounded-lg border border-white/10 bg-white/10 px-3 py-2 text-xs font-semibold text-emerald-100 shadow-sm shadow-slate-950/20 backdrop-blur">
              <WalletCards size={14} />
              Paycheck planner
            </div>
            <h2 className="mt-5 text-3xl font-semibold sm:text-4xl">{formatPence(incomePence)}</h2>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-300">
              Shape the paycheck once, then let dashboard, pots, cards, debts, savings, and calendar views read from the same saved plan.
            </p>
          </div>

          <div className="grid gap-3 sm:grid-cols-3">
            <PaydayOverviewMetric
              label="Estimate"
              value={formatPence(calculatedPence)}
              caption={`${hours || 0} hours at ${formatPence(hourlyRatePence)}`}
              tone="neutral"
            />
            <PaydayOverviewMetric
              label="Override"
              value={actualAmountPence === null ? 'Unused' : formatSignedPence(actualOverrideDifferencePence)}
              caption={actualAmountPence === null ? 'using hours estimate' : 'difference from estimate'}
              tone={actualAmountPence === null || actualOverrideDifferencePence >= 0 ? 'good' : 'warning'}
            />
            <PaydayOverviewMetric
              label="Plan state"
              value={existingPeriod ? 'Update' : 'New'}
              caption={canSubmit ? 'ready to save' : 'needs pay details'}
              tone={canSubmit ? 'good' : 'warning'}
            />
          </div>
        </div>

        <div className="grid gap-4 border-t border-white/10 bg-white/[0.04] p-5 lg:grid-cols-[1fr_1.15fr]">
          <div className="rounded-lg border border-white/10 bg-white/[0.08] p-4 backdrop-blur">
            <p className="text-xs font-semibold uppercase text-slate-400">Pay period route</p>
            <div className="mt-4 grid grid-cols-[1fr_auto_1fr] items-center gap-3">
              <PaydayRouteNode label="Starts" value={period?.startDate ?? 'Choose date'} />
              <span className="flex size-9 items-center justify-center rounded-lg border border-white/10 bg-slate-950/35 text-emerald-100">
                <ArrowRight size={17} />
              </span>
              <PaydayRouteNode label="Ends" value={period?.endDate ?? 'Choose date'} align="right" />
            </div>
            <div className="mt-4 h-2 overflow-hidden rounded-full bg-white/10">
              <div
                className="h-full rounded-full bg-emerald-300"
                style={{ width: `${canSubmit ? 100 : hasValidPayday ? 58 : 22}%` }}
              />
            </div>
          </div>

          <div className="rounded-lg border border-white/10 bg-white/[0.08] p-4 backdrop-blur">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="text-xs font-semibold uppercase text-slate-400">Pay rhythm</p>
                <p className="mt-1 text-lg font-semibold text-white">{formatPayFrequencyLabel(payFrequency)}</p>
              </div>
              <div className="rounded-lg border border-white/10 bg-slate-950/35 px-3 py-2 text-right">
                <p className="text-2xl font-semibold text-white">{payPeriodDays || '-'}</p>
                <p className="text-[11px] font-semibold uppercase text-slate-400">days</p>
              </div>
            </div>
            <div className="mt-4 grid gap-2 sm:grid-cols-3">
              <PaydaySignal label="Payday" value={hasValidPayday ? payday : 'Invalid'} />
              <PaydaySignal label="Next payday" value={period?.nextPayday ?? 'Pending'} />
              <PaydaySignal label="Mode" value={actualAmountPence === null ? 'Estimate' : 'Actual'} />
            </div>
          </div>
        </div>
      </section>

      <Panel title="Pay day" description="Enter pay details for this payday." accent="emerald">
        <SectionGrid variant="wideLeft" className="items-start">
          <div className="grid gap-4 md:grid-cols-2">
            <Field label="Payday">
              <TextInput
                type="date"
                value={payday}
                onChange={(event) => {
                  loadPayday(event.target.value)
                }}
              />
            </Field>
            <Field label="Pay frequency">
              <SelectInput
                value={payFrequency}
                onChange={(event) => {
                  setPayFrequency(event.target.value as PayFrequency)
                  setSaved(false)
                }}
              >
                <option value="weekly">Weekly</option>
                <option value="biweekly">Biweekly</option>
                <option value="monthly">Monthly</option>
                <option value="custom">Custom</option>
              </SelectInput>
            </Field>
            <Field label="Hours worked">
              <TextInput
                inputMode="decimal"
                value={hoursWorked}
                onChange={(event) => {
                  setHoursWorked(event.target.value)
                  setSaved(false)
                }}
              />
            </Field>
            <Field label="Hourly rate">
              <TextInput
                inputMode="decimal"
                value={hourlyRate}
                onChange={(event) => {
                  setHourlyRate(event.target.value)
                  setSaved(false)
                }}
              />
            </Field>
            <Field label="Actual received" hint="Optional. If payroll differs, this overrides the estimate.">
              <TextInput
                inputMode="decimal"
                placeholder="Leave blank"
                value={actualReceived}
                onChange={(event) => {
                  setActualReceived(event.target.value)
                  setSaved(false)
                }}
              />
            </Field>
            <Field label="Pay period">
              <TextInput value={period ? `${period.startDate} to ${period.endDate}` : 'Choose a valid payday'} disabled />
            </Field>
          </div>

          <div className="space-y-5">
            <MoneyMetric
              label="Pay to plan"
              value={formatPence(incomePence)}
              tone="primary"
              breakdown={getPayToPlanBreakdown({
                actualAmountPence,
                calculatedPence,
                hourlyRatePence,
                hours,
                incomePence,
              })}
            />

            <div className="overflow-hidden rounded-2xl border border-emerald-200/90 bg-[linear-gradient(135deg,#f0fdf4,#ecfeff)] p-4 shadow-[0_18px_45px_rgba(15,23,42,0.07)]">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">Paycheck flow</p>
                  <p className="mt-1 text-sm font-semibold text-slate-950">
                    {period ? `${period.startDate} to ${period.endDate}` : 'Waiting for a valid payday'}
                  </p>
                </div>
                <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-white/80 text-emerald-700 shadow-sm shadow-emerald-100/60">
                  <WalletCards size={18} />
                </span>
              </div>
              <div className="mt-4 grid gap-2 sm:grid-cols-3">
                <PaydayFlowStep icon={<CalendarDays size={15} />} label="Payday" value={hasValidPayday ? payday : 'Invalid'} />
                <PaydayFlowStep icon={<Clock3 size={15} />} label="Frequency" value={payFrequency} />
                <PaydayFlowStep icon={<CheckCircle2 size={15} />} label="Status" value={existingPeriod ? 'Updating' : 'New plan'} />
              </div>
              <div className="mt-4 h-2 overflow-hidden rounded-full bg-white/80 shadow-inner shadow-emerald-100">
                <div
                  className="h-full rounded-full bg-emerald-500 shadow-sm transition-all"
                  style={{ width: `${canSubmit ? 100 : hasValidPayday ? 58 : 24}%` }}
                />
              </div>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <Button disabled={!canSubmit || saved} onClick={submitPlan}>
                {existingPeriod ? 'Update paycheck plan' : 'Confirm paycheck plan'}
              </Button>
              <span className="rounded-lg border border-slate-200/90 bg-white/90 px-3 py-2 text-sm font-medium capitalize text-slate-700 shadow-sm shadow-slate-200/60">
                {payFrequency} plan
              </span>
              {saved && (
                <span className="inline-flex items-center gap-2 text-sm font-medium text-emerald-700">
                  <CheckCircle2 size={18} />
                  Saved locally
                </span>
              )}
            </div>
          </div>
        </SectionGrid>
      </Panel>

      <PayPeriodHistoryPanel snapshot={snapshot} actions={actions} />
    </div>
  )
}

function PaydayFlowStep({
  icon,
  label,
  value,
}: {
  icon: ReactNode
  label: string
  value: string
}) {
  return (
    <div className="rounded-xl border border-white/70 bg-white/[0.78] px-3 py-2 shadow-sm shadow-emerald-100/50">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-500">
        <span className="text-emerald-700">{icon}</span>
        {label}
      </div>
      <p className="mt-1 truncate text-sm font-semibold capitalize text-slate-950">{value}</p>
    </div>
  )
}

function PaydayOverviewMetric({
  label,
  value,
  caption,
  tone,
}: {
  label: string
  value: string
  caption: string
  tone: 'neutral' | 'good' | 'warning'
}) {
  return (
    <div
      className={[
        'rounded-lg border p-4 shadow-sm backdrop-blur',
        tone === 'neutral' ? 'border-white/10 bg-white/[0.08]' : '',
        tone === 'good' ? 'border-emerald-300/20 bg-emerald-300/10' : '',
        tone === 'warning' ? 'border-amber-300/20 bg-amber-300/10' : '',
      ].join(' ')}
    >
      <p className="text-xs font-semibold uppercase text-slate-300">{label}</p>
      <p className="mt-2 text-2xl font-semibold text-white">{value}</p>
      <p className="mt-1 text-xs font-medium text-slate-400">{caption}</p>
    </div>
  )
}

function PaydayRouteNode({
  label,
  value,
  align = 'left',
}: {
  label: string
  value: string
  align?: 'left' | 'right'
}) {
  return (
    <div className={align === 'right' ? 'text-right' : undefined}>
      <p className="text-xs font-semibold uppercase text-slate-400">{label}</p>
      <p className="mt-1 text-sm font-semibold text-white">{value}</p>
    </div>
  )
}

function PaydaySignal({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-white/10 bg-slate-950/25 px-3 py-2">
      <p className="text-[11px] font-semibold uppercase text-slate-400">{label}</p>
      <p className="mt-1 truncate text-sm font-semibold text-white">{value}</p>
    </div>
  )
}

function getPayToPlanBreakdown({
  actualAmountPence,
  calculatedPence,
  hourlyRatePence,
  hours,
  incomePence,
}: {
  actualAmountPence: number | null
  calculatedPence: number
  hourlyRatePence: number
  hours: number
  incomePence: number
}): CalculationBreakdown {
  const lines: CalculationLine[] = [
    {
      label: 'Hours worked',
      value: String(hours),
      tone: 'muted' as const,
    },
    {
      label: 'Hourly rate',
      value: formatPence(hourlyRatePence),
      tone: 'muted' as const,
    },
    {
      label: 'Hours estimate',
      value: formatPence(calculatedPence),
      detail: `${hours} hours × ${formatPence(hourlyRatePence)} per hour.`,
      tone: 'add' as const,
    },
  ]

  if (actualAmountPence !== null) {
    lines.push({
      label: 'Actual received override',
      value: formatPence(actualAmountPence),
      detail: 'Because actual received is filled in, this replaces the hours estimate.',
      tone: 'result' as const,
    })
  }

  lines.push({
    label: 'Pay to plan',
    value: formatPence(incomePence),
    tone: 'result' as const,
  })

  return {
    formula: actualAmountPence === null ? 'Pay to plan = hours worked × hourly rate.' : 'Pay to plan = actual received.',
    lines,
    note: 'This is the income saved to the paycheck plan when you confirm or update it.',
  }
}

function getDaysBetween(startDate: string, endDate: string): number {
  const start = new Date(`${startDate}T00:00:00.000Z`).getTime()
  const end = new Date(`${endDate}T00:00:00.000Z`).getTime()

  return Math.max(0, Math.round((end - start) / (24 * 60 * 60 * 1000)))
}

function getPaydayDraft(snapshot: PlannerSnapshot, payday: string) {
  const period = snapshot.payPeriods.find((candidate) => candidate.payday === payday)

  if (!period) {
    return {
      payday,
      hoursWorked: String(snapshot.settings.defaultHoursWorked),
      hourlyRate: (snapshot.settings.hourlyRatePence / 100).toFixed(2),
      payFrequency: snapshot.settings.payFrequency,
      actualReceived: '',
    }
  }

  const paycheck = snapshot.paychecks.find((candidate) => candidate.payPeriodId === period.id)

  return {
    payday,
    hoursWorked: paycheck ? String(paycheck.hoursWorked) : String(snapshot.settings.defaultHoursWorked),
    hourlyRate: ((paycheck?.hourlyRatePence ?? snapshot.settings.hourlyRatePence) / 100).toFixed(2),
    payFrequency: period.payFrequency ?? inferPayFrequency(period),
    actualReceived:
      paycheck?.actualAmountPence === null || paycheck?.actualAmountPence === undefined
        ? ''
        : (paycheck.actualAmountPence / 100).toFixed(2),
  }
}

function formatSignedPence(amountPence: number): string {
  if (amountPence > 0) {
    return `+${formatPence(amountPence)}`
  }

  if (amountPence < 0) {
    return `-${formatPence(Math.abs(amountPence))}`
  }

  return formatPence(0)
}

function formatPayFrequencyLabel(frequency: PayFrequency): string {
  if (frequency === 'biweekly') {
    return 'Biweekly'
  }

  return frequency.charAt(0).toUpperCase() + frequency.slice(1)
}

function isValidIsoDateInput(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false
  }

  const date = new Date(`${value}T00:00:00.000Z`)

  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value
}

function inferPayFrequency(period: PayPeriod): PayFrequency {
  const daysBetweenPaydays =
    Math.round(
      (new Date(`${period.nextPayday}T00:00:00.000Z`).getTime() -
        new Date(`${period.payday}T00:00:00.000Z`).getTime()) /
        (24 * 60 * 60 * 1000),
    ) || 14

  if (daysBetweenPaydays === 7) {
    return 'weekly'
  }

  if (daysBetweenPaydays >= 28) {
    return 'monthly'
  }

  return 'biweekly'
}
