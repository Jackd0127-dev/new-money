import { useState } from 'react'
import { Trash2 } from 'lucide-react'

import { formatPence, parsePoundsToPence } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Field, Panel, SelectInput, TextInput } from '../components/ui'
import type { RecurringFrequency, RecurringPriority } from '../types/models'

export function RecurringPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  const activePots = snapshot.pots.filter((pot) => !pot.archived)
  const [name, setName] = useState('')
  const [amount, setAmount] = useState('')
  const [dueDay, setDueDay] = useState('1')
  const [frequency, setFrequency] = useState<RecurringFrequency>('monthly')
  const [priority, setPriority] = useState<RecurringPriority>('essential')
  const [potId, setPotId] = useState(activePots[0]?.id ?? '')

  async function submitPayment() {
    const amountPence = parsePoundsToPence(amount)
    const dueDayNumber = Number.parseInt(dueDay, 10)

    if (!name.trim() || !potId || amountPence <= 0 || dueDayNumber < 1 || dueDayNumber > 31) {
      return
    }

    await actions.addRecurringPayment({
      name: name.trim(),
      amountPence,
      dueDay: dueDayNumber,
      frequency,
      potId,
      priority,
    })
    setName('')
    setAmount('')
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[0.7fr_1.3fr]">
      <Panel
        title="Add recurring payment"
        description="Bills reserve during the pay period that contains their due day."
      >
        <div className="space-y-4">
          <Field label="Name">
            <TextInput value={name} onChange={(event) => setName(event.target.value)} placeholder="Phone bill" />
          </Field>
          <Field label="Amount">
            <TextInput inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="22.00" />
          </Field>
          <div className="grid gap-4 md:grid-cols-2">
            <Field label="Due day">
              <TextInput inputMode="numeric" value={dueDay} onChange={(event) => setDueDay(event.target.value)} />
            </Field>
            <Field label="Frequency">
              <SelectInput value={frequency} onChange={(event) => setFrequency(event.target.value as RecurringFrequency)}>
                <option value="weekly">Weekly</option>
                <option value="biweekly">Biweekly</option>
                <option value="monthly">Monthly</option>
                <option value="yearly">Yearly</option>
              </SelectInput>
            </Field>
          </div>
          <Field label="Reserve into pot">
            <SelectInput value={potId} onChange={(event) => setPotId(event.target.value)}>
              {activePots.map((pot) => (
                <option key={pot.id} value={pot.id}>
                  {pot.name}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field label="Priority">
            <SelectInput value={priority} onChange={(event) => setPriority(event.target.value as RecurringPriority)}>
              <option value="essential">Essential</option>
              <option value="important">Important</option>
              <option value="optional">Optional</option>
            </SelectInput>
          </Field>
          <Button onClick={submitPayment}>Add recurring payment</Button>
        </div>
      </Panel>

      <Panel title="Recurring payments" description="Inactive payments are ignored by payday planning.">
        <div className="space-y-3">
          {snapshot.recurringPayments.length > 0 ? (
            snapshot.recurringPayments.map((payment) => {
              const pot = snapshot.pots.find((candidate) => candidate.id === payment.potId)

              return (
                <div key={payment.id} className="flex flex-col gap-3 rounded-lg border border-slate-200 bg-white p-4 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className={payment.active ? 'size-2 rounded-full bg-emerald-500' : 'size-2 rounded-full bg-slate-300'} />
                      <h3 className="text-sm font-semibold text-slate-950">{payment.name}</h3>
                    </div>
                    <p className="mt-1 text-xs text-slate-500">
                      Due day {payment.dueDay} · {payment.frequency} · {pot?.name ?? 'Archived pot'}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <p className="text-sm font-semibold text-slate-950">{formatPence(payment.amountPence)}</p>
                    <Button variant="secondary" onClick={() => actions.toggleRecurringPayment(payment)}>
                      {payment.active ? 'Pause' : 'Resume'}
                    </Button>
                    <Button
                      variant="danger"
                      onClick={() => {
                        if (window.confirm(`Delete ${payment.name}?`)) {
                          void actions.deleteRecurringPayment(payment.id)
                        }
                      }}
                      aria-label={`Delete ${payment.name}`}
                    >
                      <Trash2 size={16} />
                    </Button>
                  </div>
                </div>
              )
            })
          ) : (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No recurring payments yet.</p>
          )}
        </div>
      </Panel>
    </div>
  )
}
