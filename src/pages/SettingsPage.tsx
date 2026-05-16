import { useState } from 'react'

import { formatPence, parsePoundsToPence } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Field, Panel, SelectInput, TextInput } from '../components/ui'
import type { PayFrequency } from '../types/models'

export function SettingsPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  const [hourlyRate, setHourlyRate] = useState((snapshot.settings.hourlyRatePence / 100).toFixed(2))
  const [payFrequency, setPayFrequency] = useState<PayFrequency>(snapshot.settings.payFrequency)

  async function saveSettings() {
    await actions.updateSettings({
      hourlyRatePence: parsePoundsToPence(hourlyRate),
      payFrequency,
    })
  }

  async function resetData() {
    const confirmed = window.confirm('Reset all local planner data in this browser?')

    if (confirmed) {
      await actions.resetPlannerData()
    }
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[0.85fr_1.15fr]">
      <Panel title="Pay defaults" description="These defaults speed up each payday plan.">
        <div className="space-y-4">
          <Field label="Currency">
            <TextInput value={snapshot.settings.currency} disabled />
          </Field>
          <Field label="Hourly rate">
            <TextInput inputMode="decimal" value={hourlyRate} onChange={(event) => setHourlyRate(event.target.value)} />
          </Field>
          <Field label="Pay frequency">
            <SelectInput value={payFrequency} onChange={(event) => setPayFrequency(event.target.value as PayFrequency)}>
              <option value="weekly">Weekly</option>
              <option value="biweekly">Biweekly</option>
              <option value="monthly">Monthly</option>
              <option value="custom">Custom</option>
            </SelectInput>
          </Field>
          <Button onClick={saveSettings}>Save settings</Button>
        </div>
      </Panel>

      <Panel title="Local data" description="V1 stores data privately in this browser using IndexedDB.">
        <div className="grid gap-4 md:grid-cols-3">
          <div className="rounded-lg bg-slate-50 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Pots</p>
            <p className="mt-2 text-2xl font-semibold text-slate-950">{snapshot.pots.length}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Recurring</p>
            <p className="mt-2 text-2xl font-semibold text-slate-950">{snapshot.recurringPayments.length}</p>
          </div>
          <div className="rounded-lg bg-slate-50 p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Total pot balance</p>
            <p className="mt-2 text-2xl font-semibold text-slate-950">
              {formatPence(snapshot.pots.reduce((total, pot) => total + pot.balancePence, 0))}
            </p>
          </div>
        </div>
        <div className="mt-6 rounded-lg border border-amber-200 bg-amber-50 p-4">
          <p className="text-sm font-semibold text-amber-900">Reset path</p>
          <p className="mt-1 text-sm leading-6 text-amber-800">
            This clears local data and restores starter pots. It does not affect any external account because v1 has no backend.
          </p>
          <Button className="mt-4" variant="danger" onClick={resetData}>
            Reset local data
          </Button>
        </div>
      </Panel>
    </div>
  )
}
