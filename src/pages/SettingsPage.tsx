import { useState } from 'react'
import { CheckCircle2 } from 'lucide-react'

import { formatPence, parsePoundsToPence } from '../domain/money'
import { CloudSyncPanel } from '../components/CloudSyncPanel'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import type { CloudSyncController } from '../hooks/useCloudSync'
import type { FirebaseAuthController } from '../hooks/useFirebaseAuth'
import { Button, Field, Panel, SelectInput, TextInput } from '../components/ui'
import type { PayFrequency } from '../types/models'

export function SettingsPage({
  snapshot,
  actions,
  auth,
  sync,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
  auth?: FirebaseAuthController
  sync?: CloudSyncController
}) {
  const [hourlyRate, setHourlyRate] = useState((snapshot.settings.hourlyRatePence / 100).toFixed(2))
  const [defaultHoursWorked, setDefaultHoursWorked] = useState(String(snapshot.settings.defaultHoursWorked))
  const [payFrequency, setPayFrequency] = useState<PayFrequency>(snapshot.settings.payFrequency)
  const [saved, setSaved] = useState(false)

  async function saveSettings() {
    await actions.updateSettings({
      defaultHoursWorked: Number.parseFloat(defaultHoursWorked) || 0,
      hourlyRatePence: parsePoundsToPence(hourlyRate),
      payFrequency,
    })
    setSaved(true)
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[0.85fr_1.15fr]">
      <Panel title="Pay defaults" description="These defaults speed up each payday plan.">
        <div className="space-y-4">
          <Field label="Currency">
            <TextInput value={snapshot.settings.currency} disabled />
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
          <Field label="Default hours worked">
            <TextInput
              inputMode="decimal"
              value={defaultHoursWorked}
              onChange={(event) => {
                setDefaultHoursWorked(event.target.value)
                setSaved(false)
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
          <div className="flex flex-wrap items-center gap-3">
            <Button onClick={saveSettings} disabled={saved}>
              Save settings
            </Button>
            {saved && (
              <span className="inline-flex items-center gap-2 text-sm font-medium text-emerald-700">
                <CheckCircle2 size={18} />
                Settings saved
              </span>
            )}
          </div>
        </div>
      </Panel>

      {auth && sync && <CloudSyncPanel auth={auth} sync={sync} />}

      <Panel title="Planner data" description="Signed-in data syncs automatically with Firebase in the background.">
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
      </Panel>
    </div>
  )
}
