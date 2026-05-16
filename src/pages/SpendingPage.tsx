import { useState } from 'react'
import { PenLine, Trash2 } from 'lucide-react'

import { formatPence, parsePoundsToPence, toIsoDate } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Field, Panel, SelectInput, TextInput } from '../components/ui'

export function SpendingPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  const activePots = snapshot.pots.filter((pot) => !pot.archived)
  const latestPeriod = snapshot.payPeriods[0] ?? null
  const [potId, setPotId] = useState(activePots[0]?.id ?? '')
  const [amount, setAmount] = useState('')
  const [date, setDate] = useState(toIsoDate(new Date()))
  const [note, setNote] = useState('')
  const [editingTransactionId, setEditingTransactionId] = useState<string | null>(null)

  async function submitTransaction() {
    const amountPence = parsePoundsToPence(amount)

    if (!potId || amountPence <= 0) {
      return
    }

    if (editingTransactionId) {
      await actions.updateTransaction(editingTransactionId, {
        potId,
        amountPence,
        date,
        note: note.trim() || 'Manual spend',
      })
      resetForm()
      return
    }

    await actions.addTransaction({
      potId,
      amountPence,
      type: 'spending',
      date,
      note: note.trim() || 'Manual spend',
      payPeriodId: latestPeriod?.id ?? null,
    })
    resetForm()
  }

  function startEditingTransaction(transactionId: string) {
    const transaction = snapshot.transactions.find((candidate) => candidate.id === transactionId)

    if (!transaction) {
      return
    }

    setEditingTransactionId(transaction.id)
    setPotId(transaction.potId)
    setAmount((transaction.amountPence / 100).toFixed(2))
    setDate(transaction.date)
    setNote(transaction.note)
  }

  function resetForm() {
    setEditingTransactionId(null)
    setPotId(activePots[0]?.id ?? '')
    setAmount('')
    setDate(toIsoDate(new Date()))
    setNote('')
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[0.7fr_1.3fr]">
      <Panel
        title={editingTransactionId ? 'Edit spending entry' : 'Quick spend'}
        description="Choose the pot the money came from."
      >
        <div className="space-y-4">
          <Field label="Pot">
            <SelectInput value={potId} onChange={(event) => setPotId(event.target.value)}>
              {activePots.map((pot) => (
                <option key={pot.id} value={pot.id}>
                  {pot.name} · {formatPence(pot.balancePence)}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field label="Amount">
            <TextInput inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="12.50" />
          </Field>
          <Field label="Date">
            <TextInput type="date" value={date} onChange={(event) => setDate(event.target.value)} />
          </Field>
          <Field label="Note">
            <TextInput value={note} onChange={(event) => setNote(event.target.value)} placeholder="Groceries" />
          </Field>
          <div className="flex flex-wrap gap-3">
            <Button onClick={submitTransaction}>{editingTransactionId ? 'Save spending' : 'Log spending'}</Button>
            {editingTransactionId && (
              <Button variant="secondary" onClick={resetForm}>
                Cancel
              </Button>
            )}
          </div>
        </div>
      </Panel>

      <Panel title="Recent spending" description="Manual entries reduce the selected pot immediately.">
        <div className="space-y-3">
          {snapshot.transactions.length > 0 ? (
            snapshot.transactions.slice(0, 12).map((transaction) => {
              const pot = snapshot.pots.find((candidate) => candidate.id === transaction.potId)

              return (
                <div key={transaction.id} className="flex items-center justify-between gap-4 rounded-lg bg-slate-50 px-4 py-3">
                  <div>
                    <p className="text-sm font-semibold text-slate-950">{transaction.note}</p>
                    <p className="text-xs text-slate-500">
                      {transaction.date} · {pot?.name ?? 'Archived pot'}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <p className="text-sm font-semibold text-red-700">-{formatPence(transaction.amountPence)}</p>
                    <Button
                      variant="secondary"
                      onClick={() => startEditingTransaction(transaction.id)}
                      aria-label={`Edit ${transaction.note}`}
                    >
                      <PenLine size={16} />
                    </Button>
                    <Button
                      variant="danger"
                      onClick={() => {
                        if (window.confirm(`Delete ${transaction.note}?`)) {
                          void actions.deleteTransaction(transaction.id)
                        }
                      }}
                      aria-label={`Delete ${transaction.note}`}
                    >
                      <Trash2 size={16} />
                    </Button>
                  </div>
                </div>
              )
            })
          ) : (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No spending entries yet.</p>
          )}
        </div>
      </Panel>
    </div>
  )
}
