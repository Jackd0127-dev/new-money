import { useState } from 'react'
import { PenLine, Trash2 } from 'lucide-react'

import { formatPence, parsePoundsToPence, toIsoDate } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Field, Panel, SelectInput, TextInput } from '../components/ui'

const quickAmounts = ['3.00', '5.00', '10.00', '20.00', '50.00']

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
  const selectedPot = activePots.find((pot) => pot.id === potId)
  const recentNotes = Array.from(
    new Set(
      snapshot.transactions
        .map((transaction) => transaction.note.trim())
        .filter((candidate) => candidate && candidate !== 'Manual spend'),
    ),
  ).slice(0, 4)
  const parsedAmountPence = parsePoundsToPence(amount)
  const canSubmitSpend = Boolean(potId) && parsedAmountPence > 0

  async function submitTransaction() {
    const amountPence = parsedAmountPence

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
          <Field label="Amount">
            <TextInput inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="12.50" />
          </Field>
          <div className="flex flex-wrap gap-2" aria-label="Quick amounts">
            {quickAmounts.map((quickAmount) => (
              <button
                key={quickAmount}
                type="button"
                onClick={() => setAmount(quickAmount)}
                className="rounded-md border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-50"
              >
                {formatPence(parsePoundsToPence(quickAmount))}
              </button>
            ))}
          </div>
          <Field label="Pot">
            <SelectInput value={potId} onChange={(event) => setPotId(event.target.value)}>
              {activePots.map((pot) => (
                <option key={pot.id} value={pot.id}>
                  {pot.name} · {formatPence(pot.balancePence)}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field label="Date">
            <div className="grid gap-2 sm:grid-cols-[1fr_auto]">
              <TextInput type="date" value={date} onChange={(event) => setDate(event.target.value)} />
              <Button variant="secondary" onClick={() => setDate(toIsoDate(new Date()))}>
                Today
              </Button>
            </div>
          </Field>
          <Field label="Note">
            <TextInput value={note} onChange={(event) => setNote(event.target.value)} placeholder="Groceries" />
          </Field>
          {recentNotes.length > 0 && (
            <div className="flex flex-wrap gap-2" aria-label="Recent spending suggestions">
              {recentNotes.map((recentNote) => (
                <button
                  key={recentNote}
                  type="button"
                  onClick={() => setNote(recentNote)}
                  className="rounded-md bg-slate-100 px-3 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-200"
                >
                  {recentNote}
                </button>
              ))}
            </div>
          )}
          <div className="flex flex-wrap gap-3">
            <Button onClick={submitTransaction} disabled={!canSubmitSpend}>
              {editingTransactionId ? 'Save spending' : 'Log spending'}
            </Button>
            {editingTransactionId && (
              <Button variant="secondary" onClick={resetForm}>
                Cancel
              </Button>
            )}
          </div>
          <div className="sticky bottom-3 z-10 rounded-lg border border-slate-200 bg-white p-3 shadow-lg xl:hidden">
            <div className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-slate-950">
                  {parsedAmountPence > 0 ? formatPence(parsedAmountPence) : 'No amount'} ·{' '}
                  {selectedPot?.name ?? 'Choose pot'}
                </p>
                <p className="text-xs text-slate-500">{date}</p>
              </div>
              <Button onClick={submitTransaction} disabled={!canSubmitSpend}>
                {editingTransactionId ? 'Save' : 'Add'}
              </Button>
            </div>
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
