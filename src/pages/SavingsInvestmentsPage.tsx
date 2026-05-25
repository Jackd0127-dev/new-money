import { useMemo, useState } from 'react'
import { PiggyBank, TrendingUp } from 'lucide-react'

import { formatPence, parsePoundsToPence } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Field, MoneyMetric, Panel, SelectInput, TextInput } from '../components/ui'
import type { PayPeriod, Pot } from '../types/models'

export function SavingsInvestmentsPage({
  snapshot,
  actions,
  selectedPayPeriod,
}: {
  snapshot: PlannerSnapshot
  actions: Pick<PlannerActions, 'upsertPaycheckPotAllocation'>
  selectedPayPeriod?: PayPeriod | null
}) {
  const [selectedPotId, setSelectedPotId] = useState('')
  const [amount, setAmount] = useState('')
  const eligiblePots = useMemo(
    () =>
      snapshot.pots
        .filter((pot) => !pot.archived && isSavingsOrInvestmentPot(pot))
        .sort((a, b) => a.name.localeCompare(b.name)),
    [snapshot.pots],
  )
  const selectedPot = eligiblePots.find((pot) => pot.id === selectedPotId) ?? null
  const amountPence = parsePoundsToPence(amount)
  const existingAllocationPence =
    selectedPayPeriod && selectedPot
      ? snapshot.potAllocations.find((allocation) => allocation.id === getSavingsInvestmentAllocationId(selectedPayPeriod.id, selectedPot.id))?.amountPence ?? 0
      : 0
  const totalSavedPence = eligiblePots.reduce((total, pot) => total + Math.max(0, pot.balancePence), 0)
  const targetPence = eligiblePots.reduce((total, pot) => total + Math.max(0, pot.targetPence ?? 0), 0)
  const selectedPeriodAllocationPence = selectedPayPeriod
    ? snapshot.potAllocations
        .filter((allocation) => allocation.payPeriodId === selectedPayPeriod.id && eligiblePots.some((pot) => pot.id === allocation.potId))
        .reduce((total, allocation) => total + Math.max(0, allocation.amountPence), 0)
    : 0
  const canSubmit = Boolean(selectedPayPeriod && selectedPot && amountPence > 0)

  async function submitAllocation() {
    if (!selectedPayPeriod || !selectedPot || amountPence <= 0) {
      return
    }

    await actions.upsertPaycheckPotAllocation({
      id: getSavingsInvestmentAllocationId(selectedPayPeriod.id, selectedPot.id),
      payPeriodId: selectedPayPeriod.id,
      potId: selectedPot.id,
      amountPence: existingAllocationPence + amountPence,
    })

    setAmount('')
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-3">
        <MoneyMetric label="Saved so far" value={formatPence(totalSavedPence)} tone="good" />
        <MoneyMetric label="This paycheck" value={formatPence(selectedPeriodAllocationPence)} tone="primary" />
        <MoneyMetric label="Targets" value={targetPence > 0 ? formatPence(targetPence) : 'Not set'} />
      </div>

      <Panel
        title="Savings & Investments"
        description={selectedPayPeriod ? `Set money aside from ${selectedPayPeriod.payday} pay.` : 'Create or select a paycheck first.'}
        accent="emerald"
        density="compact"
      >
        <div className="grid gap-3 md:grid-cols-[minmax(0,1fr)_10rem_auto]">
          <Field label="Savings or investment pot">
            <SelectInput value={selectedPotId} onChange={(event) => setSelectedPotId(event.target.value)}>
              <option value="">Choose pot</option>
              {eligiblePots.map((pot) => (
                <option key={pot.id} value={pot.id}>
                  {pot.name}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field label="Amount to set aside">
            <TextInput
              inputMode="decimal"
              value={amount}
              onChange={(event) => setAmount(event.target.value)}
              placeholder="50.00"
            />
          </Field>
          <div className="flex items-end">
            <Button onClick={submitAllocation} disabled={!canSubmit}>
              <PiggyBank size={18} />
              Set aside money
            </Button>
          </div>
        </div>
      </Panel>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {eligiblePots.map((pot) => (
          <SavingsPotCard key={pot.id} pot={pot} />
        ))}
        {eligiblePots.length === 0 && (
          <Panel title="No savings pots yet" accent="slate" density="compact">
            <p className="text-sm text-slate-500">Create a Saving or Investment pot first, then it will appear here.</p>
          </Panel>
        )}
      </div>
    </div>
  )
}

function SavingsPotCard({ pot }: { pot: Pot }) {
  const targetPence = Math.max(0, pot.targetPence ?? 0)
  const progressPercent = targetPence > 0
    ? Math.round((Math.max(0, pot.balancePence) / targetPence) * 100)
    : 0
  const progressWidth = `${Math.min(100, Math.max(0, progressPercent))}%`

  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate text-base font-semibold text-slate-950">{pot.name}</p>
          <p className="mt-1 text-sm text-slate-500">{pot.type === 'investment' ? 'Investment' : 'Savings'}</p>
        </div>
        <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-emerald-50 text-emerald-700">
          <TrendingUp size={18} />
        </span>
      </div>
      <p className="mt-5 text-2xl font-semibold text-slate-950">{formatPence(pot.balancePence)}</p>
      <div className="mt-4 h-1.5 overflow-hidden rounded-full bg-slate-100">
        <div className="h-full rounded-full bg-emerald-500" style={{ width: targetPence > 0 ? progressWidth : '0%' }} />
      </div>
      <div className="mt-3 flex items-center justify-between gap-3 text-sm">
        <span className="font-semibold text-emerald-700">{targetPence > 0 ? `${progressPercent}%` : 'No target'}</span>
        <span className="text-slate-500">{targetPence > 0 ? `Target ${formatPence(targetPence)}` : 'Set a target in Pots'}</span>
      </div>
    </div>
  )
}

function isSavingsOrInvestmentPot(pot: Pot): boolean {
  return pot.type === 'saving' || pot.type === 'investment'
}

function getSavingsInvestmentAllocationId(payPeriodId: string, potId: string): string {
  return `savings-investments-${payPeriodId}-${potId}`
}
