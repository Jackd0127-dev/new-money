import { useState } from 'react'
import { Archive } from 'lucide-react'

import { formatPence, parsePoundsToPence } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Field, Panel, SelectInput, TextInput } from '../components/ui'
import type { PotType } from '../types/models'

const colors = ['#2563eb', '#16a34a', '#ea580c', '#7c3aed', '#0f766e', '#4338ca', '#475569']

export function PotsPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  const [name, setName] = useState('')
  const [type, setType] = useState<PotType>('spending')
  const [amount, setAmount] = useState('')
  const [color, setColor] = useState(colors[0])
  const activePots = snapshot.pots.filter((pot) => !pot.archived)

  async function submitPot() {
    if (!name.trim()) {
      return
    }

    await actions.addPot({
      name: name.trim(),
      type,
      balancePence: amount ? parsePoundsToPence(amount) : 0,
      color,
    })
    setName('')
    setAmount('')
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[0.7fr_1.3fr]">
      <Panel title="Create pot" description="Pots carry balances forward until you spend or move the money.">
        <div className="space-y-4">
          <Field label="Pot name">
            <TextInput value={name} onChange={(event) => setName(event.target.value)} placeholder="Car insurance" />
          </Field>
          <Field label="Type">
            <SelectInput value={type} onChange={(event) => setType(event.target.value as PotType)}>
              <option value="spending">Spending</option>
              <option value="reserved">Reserved</option>
              <option value="saving">Saving</option>
              <option value="investment">Investment</option>
              <option value="buffer">Buffer</option>
            </SelectInput>
          </Field>
          <Field label="Amount" hint="Optional starting balance for this pot.">
            <TextInput inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="0.00" />
          </Field>
          <Field label="Colour">
            <div className="flex flex-wrap gap-2">
              {colors.map((option) => (
                <button
                  key={option}
                  type="button"
                  aria-label={`Use colour ${option}`}
                  onClick={() => setColor(option)}
                  className="size-8 rounded-full border-2"
                  style={{
                    backgroundColor: option,
                    borderColor: option === color ? '#0f172a' : 'white',
                    boxShadow: option === color ? '0 0 0 2px #cbd5e1' : '0 0 0 1px #e2e8f0',
                  }}
                />
              ))}
            </div>
          </Field>
          <Button onClick={submitPot}>Add pot</Button>
        </div>
      </Panel>

      <Panel title="Pots" description="Reserved and savings pots are separated from everyday spendable money.">
        <div className="grid gap-4 md:grid-cols-2">
          {activePots.map((pot) => (
            <div key={pot.id} className="rounded-lg border border-slate-200 bg-white p-4">
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="size-3 rounded-full" style={{ backgroundColor: pot.color }} />
                    <h3 className="truncate text-sm font-semibold text-slate-950">{pot.name}</h3>
                  </div>
                  <p className="mt-1 text-xs capitalize text-slate-500">{pot.type}</p>
                </div>
                <Button variant="ghost" onClick={() => actions.archivePot(pot.id)} aria-label={`Archive ${pot.name}`}>
                  <Archive size={16} />
                </Button>
              </div>
              <p className="mt-4 text-2xl font-semibold text-slate-950">{formatPence(pot.balancePence)}</p>
              {pot.targetPence && <p className="mt-1 text-sm text-slate-500">Amount {formatPence(pot.targetPence)}</p>}
            </div>
          ))}
        </div>
      </Panel>
    </div>
  )
}
