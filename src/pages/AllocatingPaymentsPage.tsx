import { useMemo, useState } from 'react'
import { CreditCard, PlusCircle } from 'lucide-react'

import {
  formatPence,
  getCreditCardAllocationSummary,
  parsePoundsToPence,
  toIsoDate,
} from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Field, MoneyMetric, Panel, SelectInput, TextInput } from '../components/ui'
import type { RecurringPayment, Transaction } from '../types/models'

const cardColors = ['#2563eb', '#16a34a', '#ea580c', '#7c3aed', '#0f766e', '#4338ca', '#475569']

export function AllocatingPaymentsPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  const activeCards = snapshot.creditCards.filter((card) => !card.archived)
  const latestPeriod = snapshot.payPeriods[0] ?? null
  const summary = getCreditCardAllocationSummary({
    creditCards: snapshot.creditCards,
    recurringPayments: snapshot.recurringPayments,
    customPayments: snapshot.customPayments,
    transactions: snapshot.transactions,
    repayments: snapshot.creditCardRepayments,
    payPeriod: latestPeriod,
  })
  const [cardName, setCardName] = useState('')
  const [cardProvider, setCardProvider] = useState('')
  const [cardLimit, setCardLimit] = useState('')
  const [cardDueDay, setCardDueDay] = useState('1')
  const [cardColor, setCardColor] = useState(cardColors[0])
  const [customName, setCustomName] = useState('')
  const [customAmount, setCustomAmount] = useState('')
  const [customDueDate, setCustomDueDate] = useState(toIsoDate(new Date()))
  const [customCreditCardId, setCustomCreditCardId] = useState(activeCards[0]?.id ?? '')
  const [repaymentCardId, setRepaymentCardId] = useState(activeCards[0]?.id ?? '')
  const [repaymentAmount, setRepaymentAmount] = useState('')
  const [repaymentDate, setRepaymentDate] = useState(toIsoDate(new Date()))
  const [repaymentNote, setRepaymentNote] = useState('')
  const paymentRows = useMemo(() => getPaymentRows(snapshot), [snapshot])

  async function submitCard() {
    const limitPence = parsePoundsToPence(cardLimit)
    const dueDay = Number.parseInt(cardDueDay, 10)

    if (!cardName.trim() || !cardProvider.trim() || limitPence <= 0 || dueDay < 1 || dueDay > 31) {
      return
    }

    await actions.addCreditCard({
      name: cardName.trim(),
      provider: cardProvider.trim(),
      limitPence,
      dueDay,
      dueDate: null,
      color: cardColor,
    })
    setCardName('')
    setCardProvider('')
    setCardLimit('')
    setCardDueDay('1')
  }

  async function submitCustomPayment() {
    const amountPence = parsePoundsToPence(customAmount)

    if (!customName.trim() || amountPence <= 0 || !customDueDate) {
      return
    }

    await actions.addCustomPayment({
      name: customName.trim(),
      amountPence,
      dueDate: customDueDate,
      creditCardId: customCreditCardId || null,
    })
    setCustomName('')
    setCustomAmount('')
    setCustomDueDate(toIsoDate(new Date()))
  }

  async function submitRepayment() {
    const amountPence = parsePoundsToPence(repaymentAmount)

    if (!repaymentCardId || amountPence <= 0) {
      return
    }

    await actions.addCreditCardRepayment({
      creditCardId: repaymentCardId,
      amountPence,
      date: repaymentDate,
      note: repaymentNote.trim(),
    })
    setRepaymentAmount('')
    setRepaymentNote('')
    setRepaymentDate(toIsoDate(new Date()))
  }

  async function linkPayment(row: PaymentRow, creditCardId: string) {
    const nextCardId = creditCardId || null

    if (row.source === 'recurring') {
      const payment = snapshot.recurringPayments.find((candidate) => candidate.id === row.entityId)

      if (!payment) {
        return
      }

      await actions.updateRecurringPayment(payment.id, {
        name: payment.name,
        amountPence: payment.amountPence,
        dueDay: payment.dueDay ?? 1,
        frequency: payment.frequency,
        potId: payment.potId,
        creditCardId: nextCardId,
        priority: payment.priority,
      })
      return
    }

    if (row.source === 'custom') {
      const payment = snapshot.customPayments.find((candidate) => candidate.id === row.entityId)

      if (!payment) {
        return
      }

      await actions.updateCustomPayment(payment.id, {
        name: payment.name,
        amountPence: payment.amountPence,
        dueDate: payment.dueDate,
        creditCardId: nextCardId,
        status: payment.status,
      })
      return
    }

    const transaction = snapshot.transactions.find((candidate) => candidate.id === row.entityId)

    if (!transaction) {
      return
    }

    await actions.updateTransaction(transaction.id, {
      potId: transaction.potId,
      amountPence: transaction.amountPence,
      date: transaction.date,
      note: transaction.note,
      paymentMethod: nextCardId ? 'credit_card' : 'pot',
      creditCardId: nextCardId,
    })
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-3">
        <MoneyMetric label="Latest pay" value={formatPence(summary.payReceivedPence)} />
        <MoneyMetric label="Cards owed" value={formatPence(summary.totalOwedPence)} tone={summary.totalOwedPence > 0 ? 'warning' : 'neutral'} />
        <MoneyMetric
          label="Remaining after cards"
          value={formatPence(summary.paycheckRemainingAfterCardsPence)}
          tone={summary.paycheckRemainingAfterCardsPence < 0 ? 'bad' : 'good'}
        />
      </div>

      <div className="grid gap-6 xl:grid-cols-[0.75fr_1.25fr]">
        <div className="space-y-6">
          <Panel title="Add credit card" description="Create cards that payments can be linked to.">
            <div className="space-y-4">
              <Field label="Card name">
                <TextInput value={cardName} onChange={(event) => setCardName(event.target.value)} placeholder="Everyday Amex" />
              </Field>
              <Field label="Provider">
                <TextInput value={cardProvider} onChange={(event) => setCardProvider(event.target.value)} placeholder="Amex" />
              </Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Limit">
                  <TextInput inputMode="decimal" value={cardLimit} onChange={(event) => setCardLimit(event.target.value)} placeholder="1000.00" />
                </Field>
                <Field label="Due day">
                  <TextInput inputMode="numeric" value={cardDueDay} onChange={(event) => setCardDueDay(event.target.value)} />
                </Field>
              </div>
              <Field label="Colour">
                <div className="flex flex-wrap gap-2">
                  {cardColors.map((option) => (
                    <button
                      key={option}
                      type="button"
                      aria-label={`Use card colour ${option}`}
                      onClick={() => setCardColor(option)}
                      className="size-8 rounded-full border-2"
                      style={{
                        backgroundColor: option,
                        borderColor: option === cardColor ? '#0f172a' : 'white',
                        boxShadow: option === cardColor ? '0 0 0 2px #cbd5e1' : '0 0 0 1px #e2e8f0',
                      }}
                    />
                  ))}
                </div>
              </Field>
              <Button onClick={submitCard}>
                <PlusCircle size={18} />
                Add card
              </Button>
            </div>
          </Panel>

          <Panel title="Add custom payment" description="One-off payments can be linked to a card or left unlinked.">
            <div className="space-y-4">
              <Field label="Payment name">
                <TextInput value={customName} onChange={(event) => setCustomName(event.target.value)} placeholder="Tyres" />
              </Field>
              <Field label="Amount">
                <TextInput inputMode="decimal" value={customAmount} onChange={(event) => setCustomAmount(event.target.value)} placeholder="30.00" />
              </Field>
              <Field label="Due date">
                <TextInput type="date" value={customDueDate} onChange={(event) => setCustomDueDate(event.target.value)} />
              </Field>
              <Field label="Credit card">
                <SelectInput value={customCreditCardId} onChange={(event) => setCustomCreditCardId(event.target.value)}>
                  <option value="">Unlinked</option>
                  {activeCards.map((card) => (
                    <option key={card.id} value={card.id}>
                      {card.name} ({card.provider})
                    </option>
                  ))}
                </SelectInput>
              </Field>
              <Button onClick={submitCustomPayment}>Add payment</Button>
            </div>
          </Panel>

          <Panel title="Record card repayment" description="Repayments reduce the amount shown as owed.">
            <div className="space-y-4">
              <Field label="Credit card">
                <SelectInput value={repaymentCardId} onChange={(event) => setRepaymentCardId(event.target.value)}>
                  {activeCards.map((card) => (
                    <option key={card.id} value={card.id}>
                      {card.name} ({card.provider})
                    </option>
                  ))}
                </SelectInput>
              </Field>
              <Field label="Amount">
                <TextInput inputMode="decimal" value={repaymentAmount} onChange={(event) => setRepaymentAmount(event.target.value)} placeholder="100.00" />
              </Field>
              <Field label="Date">
                <TextInput type="date" value={repaymentDate} onChange={(event) => setRepaymentDate(event.target.value)} />
              </Field>
              <Field label="Note">
                <TextInput value={repaymentNote} onChange={(event) => setRepaymentNote(event.target.value)} placeholder="Statement payment" />
              </Field>
              <Button onClick={submitRepayment} disabled={activeCards.length === 0}>
                Record repayment
              </Button>
            </div>
          </Panel>
        </div>

        <div className="space-y-6">
          <Panel title="Credit cards" description="Owed amounts are calculated from linked payments in the current pay period.">
            <div className="grid gap-4 lg:grid-cols-2">
              {summary.cards.length > 0 ? (
                summary.cards.map((cardSummary) => (
                  <div key={cardSummary.card.id} className="rounded-lg border border-slate-200 bg-white p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="size-3 rounded-full" style={{ backgroundColor: cardSummary.card.color }} />
                          <h3 className="truncate text-sm font-semibold text-slate-950">{cardSummary.card.name}</h3>
                        </div>
                        <p className="mt-1 text-xs text-slate-500">
                          {cardSummary.card.provider} · due {cardSummary.dueLabel}
                        </p>
                      </div>
                      <CreditCard size={20} className="text-slate-400" />
                    </div>
                    <div className="mt-5 grid gap-3 sm:grid-cols-2">
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Owed</p>
                        <p className="mt-1 text-2xl font-semibold text-slate-950">
                          {formatPence(cardSummary.owedPence)} owed
                        </p>
                      </div>
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Available</p>
                        <p className="mt-1 text-2xl font-semibold text-slate-950">{formatPence(cardSummary.availableCreditPence)}</p>
                      </div>
                    </div>
                    <div className="mt-4">
                      <div className="h-2 overflow-hidden rounded-full bg-slate-100">
                        <div
                          className="h-full rounded-full"
                          style={{
                            width: `${Math.min(100, cardSummary.utilisationPercent)}%`,
                            backgroundColor: cardSummary.card.color,
                          }}
                        />
                      </div>
                      <p className="mt-2 text-xs text-slate-500">
                        {cardSummary.utilisationPercent}% of {formatPence(cardSummary.card.limitPence)} limit
                      </p>
                    </div>
                  </div>
                ))
              ) : (
                <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No credit cards yet.</p>
              )}
            </div>
          </Panel>

          <Panel title="Payment allocation list" description="Link or unlink payments and card spending.">
            <div className="space-y-3">
              {paymentRows.length > 0 ? (
                paymentRows.map((row) => (
                  <div
                    key={row.id}
                    className="grid gap-3 rounded-lg border border-slate-200 bg-white p-4 md:grid-cols-[1fr_180px]"
                  >
                    <div>
                      <p className="text-sm font-semibold text-slate-950">{row.label}</p>
                      <p className="mt-1 text-xs text-slate-500">
                        {row.sourceLabel} · {row.date} · {formatPence(row.amountPence)}
                      </p>
                    </div>
                    <SelectInput value={row.creditCardId ?? ''} onChange={(event) => void linkPayment(row, event.target.value)}>
                      <option value="">Unlinked</option>
                      {activeCards.map((card) => (
                        <option key={card.id} value={card.id}>
                          {card.name} ({card.provider})
                        </option>
                      ))}
                    </SelectInput>
                  </div>
                ))
              ) : (
                <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">
                  No payments or card spending are available to allocate yet.
                </p>
              )}
            </div>
          </Panel>
        </div>
      </div>
    </div>
  )
}

type PaymentRowSource = 'recurring' | 'custom' | 'transaction'

interface PaymentRow {
  id: string
  entityId: string
  source: PaymentRowSource
  sourceLabel: string
  label: string
  amountPence: number
  date: string
  creditCardId: string | null
}

function getPaymentRows(snapshot: PlannerSnapshot): PaymentRow[] {
  return [
    ...snapshot.recurringPayments.map((payment) => recurringPaymentToRow(payment)),
    ...snapshot.customPayments
      .filter((payment) => payment.status !== 'archived')
      .map((payment) => ({
        id: `custom-${payment.id}`,
        entityId: payment.id,
        source: 'custom' as const,
        sourceLabel: 'Custom payment',
        label: payment.name,
        amountPence: payment.amountPence,
        date: payment.dueDate,
        creditCardId: payment.creditCardId ?? null,
      })),
    ...snapshot.transactions
      .filter((transaction) => transaction.type === 'spending')
      .map((transaction) => transactionToRow(transaction)),
  ].sort((a, b) => b.date.localeCompare(a.date))
}

function recurringPaymentToRow(payment: RecurringPayment): PaymentRow {
  return {
    id: `recurring-${payment.id}`,
    entityId: payment.id,
    source: 'recurring',
    sourceLabel: 'Recurring payment',
    label: payment.name,
    amountPence: payment.amountPence,
    date: payment.dueDate ?? `Day ${payment.dueDay ?? 1}`,
    creditCardId: payment.creditCardId ?? null,
  }
}

function transactionToRow(transaction: Transaction): PaymentRow {
  return {
    id: `transaction-${transaction.id}`,
    entityId: transaction.id,
    source: 'transaction',
    sourceLabel: 'Spending',
    label: transaction.note,
    amountPence: transaction.amountPence,
    date: transaction.date,
    creditCardId: transaction.creditCardId ?? null,
  }
}
