import { useState, type ReactNode } from 'react'
import { CalendarDays, CheckCircle2, Clock3, WalletCards } from 'lucide-react'

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
