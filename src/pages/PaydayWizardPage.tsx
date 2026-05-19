import { useMemo, useState } from 'react'
import { AlertTriangle, CheckCircle2 } from 'lucide-react'

import {
  calculatePaycheckAmount,
  createNextPayPeriod,
  formatPence,
  getAllocationBalance,
  getRecurringPaymentsDue,
  getTotalPence,
  parsePoundsToPence,
  toIsoDate,
} from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Field, Panel, SelectInput, TextInput } from '../components/ui'
import type { PayFrequency, PayPeriod } from '../types/models'

export function PaydayWizardPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  const initialDraft = getPaydayDraft(snapshot, snapshot.payPeriods[0]?.payday ?? toIsoDate(new Date()))
  const [payday, setPayday] = useState(initialDraft.payday)
  const [hoursWorked, setHoursWorked] = useState(initialDraft.hoursWorked)
  const [hourlyRate, setHourlyRate] = useState(initialDraft.hourlyRate)
  const [payFrequency, setPayFrequency] = useState<PayFrequency>(initialDraft.payFrequency)
  const [actualReceived, setActualReceived] = useState(initialDraft.actualReceived)
  const [allocations, setAllocations] = useState<Record<string, string>>(initialDraft.allocations)
  const [saved, setSaved] = useState(false)

  const activePots = snapshot.pots.filter((pot) => !pot.archived)
  const existingPeriod = snapshot.payPeriods.find((candidate) => candidate.payday === payday) ?? null
  const period = createNextPayPeriod(payday, payFrequency)
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
  const duePayments = useMemo(
    () => getRecurringPaymentsDue(snapshot.recurringPayments, period.startDate, period.endDate),
    [period.endDate, period.startDate, snapshot.recurringPayments],
  )
  const reservedPence = getTotalPence(duePayments)
  const manualAllocationPence = Object.values(allocations).reduce(
    (total, value) => total + parsePoundsToPence(value),
    0,
  )
  const allocationBalance = getAllocationBalance({
    incomePence,
    reservedPence,
    allocationPence: manualAllocationPence,
  })
  const canSubmit = incomePence > 0 && !allocationBalance.isOverAllocated

  function loadPayday(nextPayday: string) {
    const draft = getPaydayDraft(snapshot, nextPayday)

    setPayday(draft.payday)
    setHoursWorked(draft.hoursWorked)
    setHourlyRate(draft.hourlyRate)
    setPayFrequency(draft.payFrequency)
    setActualReceived(draft.actualReceived)
    setAllocations(draft.allocations)
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
      allocations: activePots
        .map((pot) => ({
          potId: pot.id,
          amountPence: parsePoundsToPence(allocations[pot.id] ?? ''),
        }))
        .filter((allocation) => allocation.amountPence > 0),
    })
    setSaved(true)
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[0.85fr_1.15fr]">
      <Panel title="Payday wizard" description="Enter pay, reserve bills, then manually assign the rest.">
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
            <TextInput value={`${period.startDate} to ${period.endDate}`} disabled />
          </Field>
        </div>

        <div className="mt-5 rounded-lg bg-slate-950 p-5 text-white">
          <p className="text-sm text-slate-300">Pay to plan</p>
          <p className="mt-2 text-3xl font-semibold">{formatPence(incomePence)}</p>
          <p className="mt-2 text-xs text-slate-400">Estimate from hours: {formatPence(calculatedPence)}</p>
        </div>
      </Panel>

      <Panel title="Manual allocations" description="Recurring bills are reserved automatically; you assign the rest.">
        <div className="grid gap-3 md:grid-cols-3">
          <div className="rounded-lg bg-blue-50 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-blue-700">Reserved</p>
            <p className="mt-2 text-xl font-semibold text-slate-950">{formatPence(reservedPence)}</p>
          </div>
          <div className="rounded-lg bg-slate-100 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Assigned by you</p>
            <p className="mt-2 text-xl font-semibold text-slate-950">{formatPence(manualAllocationPence)}</p>
          </div>
          <div className="rounded-lg bg-emerald-50 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">Left unassigned</p>
            <p className="mt-2 text-xl font-semibold text-slate-950">{formatPence(allocationBalance.remainingPence)}</p>
          </div>
        </div>

        {allocationBalance.isOverAllocated && (
          <div className="mt-4 flex gap-3 rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">
            <AlertTriangle className="mt-0.5 shrink-0" size={18} />
            Allocations exceed money available after reserved payments.
          </div>
        )}

        <div className="mt-5 grid gap-3 md:grid-cols-2">
          {activePots.map((pot) => (
            <Field key={pot.id} label={pot.name}>
              <TextInput
                inputMode="decimal"
                placeholder="0.00"
                value={allocations[pot.id] ?? ''}
                onChange={(event) => {
                  setAllocations((current) => ({
                    ...current,
                    [pot.id]: event.target.value,
                  }))
                  setSaved(false)
                }}
              />
            </Field>
          ))}
        </div>

        <div className="mt-5 flex flex-wrap items-center gap-3">
          <Button disabled={!canSubmit || saved} onClick={submitPlan}>
            {existingPeriod ? 'Update paycheck plan' : 'Confirm paycheck plan'}
          </Button>
          <span className="rounded-md bg-slate-100 px-3 py-2 text-sm font-medium capitalize text-slate-700">
            {payFrequency} plan
          </span>
          {saved && (
            <span className="inline-flex items-center gap-2 text-sm font-medium text-emerald-700">
              <CheckCircle2 size={18} />
              Saved locally
            </span>
          )}
        </div>

        <div className="mt-5 rounded-lg bg-slate-50 p-4">
          <p className="text-sm font-semibold text-slate-950">Reserved this period</p>
          <div className="mt-3 space-y-2">
            {duePayments.length > 0 ? (
              duePayments.map((payment) => (
                <div key={payment.id} className="flex justify-between text-sm">
                  <span className="text-slate-600">{payment.name}</span>
                  <span className="font-semibold text-slate-950">{formatPence(payment.amountPence)}</span>
                </div>
              ))
            ) : (
              <p className="text-sm text-slate-500">No recurring payments fall inside this pay period.</p>
            )}
          </div>
        </div>
      </Panel>
    </div>
  )
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
      allocations: {},
    }
  }

  const paycheck = snapshot.paychecks.find((candidate) => candidate.payPeriodId === period.id)
  const manualAllocations = snapshot.potAllocations.filter(
    (allocation) => allocation.payPeriodId === period.id && allocation.source !== 'recurring',
  )

  return {
    payday,
    hoursWorked: paycheck ? String(paycheck.hoursWorked) : String(snapshot.settings.defaultHoursWorked),
    hourlyRate: ((paycheck?.hourlyRatePence ?? snapshot.settings.hourlyRatePence) / 100).toFixed(2),
    payFrequency: period.payFrequency ?? inferPayFrequency(period),
    actualReceived:
      paycheck?.actualAmountPence === null || paycheck?.actualAmountPence === undefined
        ? ''
        : (paycheck.actualAmountPence / 100).toFixed(2),
    allocations: Object.fromEntries(
      manualAllocations.map((allocation) => [
        allocation.potId,
        (allocation.amountPence / 100).toFixed(2),
      ]),
    ),
  }
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
