import { useMemo, useState } from 'react'
import { ArrowLeft, CreditCard as CreditCardIcon, PenLine, PlusCircle, Trash2 } from 'lucide-react'

import {
  findPayPeriodForDate,
  formatPence,
  getCreditCardAllocationSummary,
  parsePoundsToPence,
  toIsoDate,
  type CreditCardAllocationCardSummary,
  type CreditCardAllocationItem,
} from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, CalculationDetails, Field, MoneyMetric, Panel, SelectInput, TextInput, type CalculationBreakdown } from '../components/ui'
import type { CreditCardPotSource, PayPeriod, RecurringPayment, Transaction } from '../types/models'

const cardColors = ['#2563eb', '#16a34a', '#ea580c', '#7c3aed', '#0f766e', '#4338ca', '#475569']

export function AllocatingPaymentsPage({
  snapshot,
  actions,
  selectedPayPeriod,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
  selectedPayPeriod?: PayPeriod | null
}) {
  const activeCards = snapshot.creditCards.filter((card) => !card.archived)
  const viewedPeriod = selectedPayPeriod ?? null
  const summary = getCreditCardAllocationSummary({
    creditCards: snapshot.creditCards,
    recurringPayments: snapshot.recurringPayments,
    customPayments: snapshot.customPayments,
    transactions: snapshot.transactions,
    repayments: snapshot.creditCardRepayments,
    creditCardPots: snapshot.creditCardPots,
    payPeriod: viewedPeriod,
  })
  const [selectedCardId, setSelectedCardId] = useState<string | null>(null)
  const [editingCardId, setEditingCardId] = useState<string | null>(null)
  const [cardName, setCardName] = useState('')
  const [cardProvider, setCardProvider] = useState('')
  const [cardLimit, setCardLimit] = useState('')
  const [cardDueDay, setCardDueDay] = useState('1')
  const [cardColor, setCardColor] = useState(cardColors[0])
  const [editingCreditCardPotId, setEditingCreditCardPotId] = useState<string | null>(null)
  const [creditPotCardId, setCreditPotCardId] = useState(activeCards[0]?.id ?? '')
  const [creditPotName, setCreditPotName] = useState('')
  const [creditPotAmount, setCreditPotAmount] = useState('')
  const [creditPotSource, setCreditPotSource] = useState<CreditCardPotSource>('paycheck')
  const [creditPotNote, setCreditPotNote] = useState('')
  const [editingRepaymentId, setEditingRepaymentId] = useState<string | null>(null)
  const [repaymentCardId, setRepaymentCardId] = useState(activeCards[0]?.id ?? '')
  const [repaymentAmount, setRepaymentAmount] = useState('')
  const [repaymentDate, setRepaymentDate] = useState(toIsoDate(new Date()))
  const [repaymentNote, setRepaymentNote] = useState('')
  const paymentRows = useMemo(() => getPaymentRows(snapshot), [snapshot])
  const paymentGroups = useMemo(
    () => groupPaymentRowsByPeriod(paymentRows, snapshot, viewedPeriod),
    [paymentRows, snapshot, viewedPeriod],
  )
  const activeCreditCardPots = snapshot.creditCardPots.filter((creditCardPot) => creditCardPot.status === 'active')
  const selectedCardSummary = selectedCardId
    ? summary.cards.find((cardSummary) => cardSummary.card.id === selectedCardId) ?? null
    : null

  async function submitCard() {
    const limitPence = parsePoundsToPence(cardLimit)
    const dueDay = Number.parseInt(cardDueDay, 10)

    if (!cardName.trim() || !cardProvider.trim() || limitPence <= 0 || dueDay < 1 || dueDay > 31) {
      return
    }

    const payload = {
      name: cardName.trim(),
      provider: cardProvider.trim(),
      limitPence,
      dueDay,
      dueDate: null,
      color: cardColor,
    }

    if (editingCardId) {
      await actions.updateCreditCard(editingCardId, payload)
      resetCardForm()
      return
    }

    await actions.addCreditCard(payload)
    resetCardForm()
  }

  async function submitCreditCardPot() {
    const amountPence = parsePoundsToPence(creditPotAmount)
    const linkedCard = activeCards.find((card) => card.id === creditPotCardId) ?? activeCards[0]

    if (!linkedCard || amountPence <= 0 || (creditPotSource === 'paycheck' && !viewedPeriod)) {
      return
    }

    const payload = {
      creditCardId: linkedCard.id,
      payPeriodId: creditPotSource === 'paycheck' ? viewedPeriod?.id ?? null : null,
      payday: creditPotSource === 'paycheck' ? viewedPeriod?.payday ?? null : null,
      periodStartDate: creditPotSource === 'paycheck' ? viewedPeriod?.startDate ?? null : null,
      periodEndDate: creditPotSource === 'paycheck' ? viewedPeriod?.endDate ?? null : null,
      name: creditPotName.trim() || `${linkedCard.name} credit pot`,
      amountPence,
      source: creditPotSource,
      note: creditPotNote.trim(),
    }

    if (editingCreditCardPotId) {
      await actions.updateCreditCardPot(editingCreditCardPotId, payload)
      resetCreditCardPotForm()
      return
    }

    await actions.addCreditCardPot(payload)
    resetCreditCardPotForm()
  }

  async function submitRepayment() {
    const amountPence = parsePoundsToPence(repaymentAmount)

    if (!repaymentCardId || amountPence <= 0) {
      return
    }

    const payload = {
      creditCardId: repaymentCardId,
      amountPence,
      date: repaymentDate,
      note: repaymentNote.trim(),
    }

    if (editingRepaymentId) {
      await actions.updateCreditCardRepayment(editingRepaymentId, payload)
      resetRepaymentForm()
      return
    }

    await actions.addCreditCardRepayment(payload)
    resetRepaymentForm()
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
      potId: nextCardId ? null : transaction.potId ?? null,
      amountPence: transaction.amountPence,
      date: transaction.date,
      note: transaction.note,
      paymentMethod: nextCardId || transaction.paymentMethod === 'credit_card' ? 'credit_card' : 'pot',
      creditCardId: nextCardId,
    })
  }

  function startEditingCard(cardId: string) {
    const card = snapshot.creditCards.find((candidate) => candidate.id === cardId)

    if (!card) {
      return
    }

    setSelectedCardId(null)
    setEditingCardId(card.id)
    setCardName(card.name)
    setCardProvider(card.provider)
    setCardLimit((card.limitPence / 100).toFixed(2))
    setCardDueDay(String(card.dueDay ?? 1))
    setCardColor(card.color)
  }

  function startEditingCreditCardPot(creditCardPotId: string) {
    const creditCardPot = snapshot.creditCardPots.find((candidate) => candidate.id === creditCardPotId)

    if (!creditCardPot) {
      return
    }

    setSelectedCardId(null)
    setEditingCreditCardPotId(creditCardPot.id)
    setCreditPotCardId(creditCardPot.creditCardId)
    setCreditPotName(creditCardPot.name)
    setCreditPotAmount((creditCardPot.amountPence / 100).toFixed(2))
    setCreditPotSource(creditCardPot.source)
    setCreditPotNote(creditCardPot.note)
  }

  function startEditingRepayment(repaymentId: string) {
    const repayment = snapshot.creditCardRepayments.find((candidate) => candidate.id === repaymentId)

    if (!repayment) {
      return
    }

    setSelectedCardId(null)
    setEditingRepaymentId(repayment.id)
    setRepaymentCardId(repayment.creditCardId)
    setRepaymentAmount((repayment.amountPence / 100).toFixed(2))
    setRepaymentDate(repayment.date)
    setRepaymentNote(repayment.note)
  }

  function resetCardForm() {
    setEditingCardId(null)
    setCardName('')
    setCardProvider('')
    setCardLimit('')
    setCardDueDay('1')
    setCardColor(cardColors[0])
  }

  function resetCreditCardPotForm() {
    setEditingCreditCardPotId(null)
    setCreditPotCardId(activeCards[0]?.id ?? '')
    setCreditPotName('')
    setCreditPotAmount('')
    setCreditPotSource('paycheck')
    setCreditPotNote('')
  }

  function resetRepaymentForm() {
    setEditingRepaymentId(null)
    setRepaymentAmount('')
    setRepaymentNote('')
    setRepaymentDate(toIsoDate(new Date()))
    setRepaymentCardId(activeCards[0]?.id ?? '')
  }

  if (selectedCardSummary) {
    return (
      <CreditCardOverview
        activeCards={activeCards}
        cardSummary={selectedCardSummary}
        snapshot={snapshot}
        payPeriod={viewedPeriod}
        onBack={() => setSelectedCardId(null)}
        onDeleteCard={(cardId, cardNameToDelete) => {
          if (window.confirm(`Delete ${cardNameToDelete}?`)) {
            void actions.archiveCreditCard(cardId)
          }
        }}
        onDeleteCustomPayment={(paymentId, paymentName) => {
          if (window.confirm(`Delete ${paymentName}?`)) {
            void actions.deleteCustomPayment(paymentId)
          }
        }}
        onDeleteRepayment={(repaymentId) => {
          if (window.confirm('Delete this card repayment?')) {
            void actions.deleteCreditCardRepayment(repaymentId)
          }
        }}
        onDeleteCreditCardPot={(creditCardPotId, creditCardPotName) => {
          if (window.confirm(`Delete ${creditCardPotName}?`)) {
            void actions.deleteCreditCardPot(creditCardPotId)
          }
        }}
        onApplyCreditCardPot={(creditCardPotId, creditCardPotName) => {
          if (window.confirm(`Apply ${creditCardPotName} as a card repayment?`)) {
            void actions.applyCreditCardPot(creditCardPotId, {
              date: toIsoDate(new Date()),
              note: creditCardPotName,
            })
          }
        }}
        onEditCard={startEditingCard}
        onEditCreditCardPot={startEditingCreditCardPot}
        onEditRepayment={startEditingRepayment}
        onLinkPayment={linkPayment}
      />
    )
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <MoneyMetric
          label="Selected pay"
          value={formatPence(summary.payReceivedPence)}
          breakdown={{
            formula: 'Selected pay is the income saved on the pay period currently selected on the dashboard.',
            lines: [
              {
                label: viewedPeriod ? 'Selected pay period' : 'No selected pay period',
                value: formatPence(summary.payReceivedPence),
                detail: viewedPeriod ? `${viewedPeriod.startDate} to ${viewedPeriod.endDate}` : undefined,
                tone: 'result',
              },
            ],
          }}
        />
        <MoneyMetric
          label="Cards owed"
          value={formatPence(summary.totalOwedPence)}
          tone={summary.totalOwedPence > 0 ? 'warning' : 'neutral'}
          breakdown={getCardsOwedBreakdown(summary.cards)}
        />
        <MoneyMetric
          label="Credit pots"
          value={formatPence(summary.totalCreditPotsPence)}
          tone={summary.totalCreditPotsPence > 0 ? 'good' : 'neutral'}
          breakdown={getCreditPotsBreakdown(summary.cards)}
        />
        <MoneyMetric
          label="Pay left after cards"
          value={formatPence(summary.paycheckRemainingAfterCardsPence)}
          tone={summary.paycheckRemainingAfterCardsPence < 0 ? 'bad' : 'good'}
          breakdown={{
            formula: 'Pay left after cards = selected pay - cards owed - paycheck-funded credit pots.',
            lines: [
              { label: 'Selected pay', value: formatPence(summary.payReceivedPence), tone: 'add' },
              { label: 'Cards owed', value: `-${formatPence(summary.totalOwedPence)}`, tone: 'subtract' },
              { label: 'Paycheck credit pots', value: `-${formatPence(summary.totalPaycheckCreditPotsPence)}`, tone: 'subtract' },
              {
                label: 'Pay left after cards',
                value: formatPence(summary.paycheckRemainingAfterCardsPence),
                tone: 'result',
              },
            ],
          }}
        />
      </div>

      <div className="grid gap-6 xl:grid-cols-[0.72fr_1.28fr]">
        <div className="space-y-6">
          <Panel
            title={editingCardId ? 'Edit credit card' : 'Add credit card'}
            description="Cards are used to group linked payments, spending, and repayments."
          >
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
              <div className="flex flex-wrap gap-3">
                <Button onClick={submitCard}>
                  <PlusCircle size={18} />
                  {editingCardId ? 'Save card' : 'Add card'}
                </Button>
                {editingCardId && (
                  <Button variant="secondary" onClick={resetCardForm}>
                    Cancel
                  </Button>
                )}
              </div>
            </div>
          </Panel>

          <Panel
            title="Credit Pots"
            description="Set money aside for a credit card without marking the card as paid."
          >
            <div className="space-y-5">
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Credit card">
                  <SelectInput value={creditPotCardId} onChange={(event) => setCreditPotCardId(event.target.value)}>
                    {activeCards.map((card) => (
                      <option key={card.id} value={card.id}>
                        {card.name} ({card.provider})
                      </option>
                    ))}
                  </SelectInput>
                </Field>
                <Field label="Amount">
                  <TextInput inputMode="decimal" value={creditPotAmount} onChange={(event) => setCreditPotAmount(event.target.value)} placeholder="200.00" />
                </Field>
              </div>
              <Field label="Name">
                <TextInput value={creditPotName} onChange={(event) => setCreditPotName(event.target.value)} placeholder="Barclays payoff pot" />
              </Field>
              <Field label="Funding source">
                <SelectInput value={creditPotSource} onChange={(event) => setCreditPotSource(event.target.value as CreditCardPotSource)}>
                  <option value="paycheck">Take from selected paycheck</option>
                  <option value="external">External money, do not touch paycheck</option>
                </SelectInput>
              </Field>
              {creditPotSource === 'paycheck' ? (
                <p className="rounded-lg bg-slate-50 p-3 text-sm text-slate-600">
                  {viewedPeriod
                    ? `This will reduce dashboard money left for ${viewedPeriod.startDate} to ${viewedPeriod.endDate}.`
                    : 'Choose a pay period on the dashboard before taking this from a paycheck.'}
                </p>
              ) : (
                <p className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-700">
                  External money is tracked against the card, but it will not reduce dashboard money left.
                </p>
              )}
              <Field label="Note">
                <TextInput value={creditPotNote} onChange={(event) => setCreditPotNote(event.target.value)} placeholder="Money from this paycheck or elsewhere" />
              </Field>
              <div className="flex flex-wrap gap-3">
                <Button onClick={submitCreditCardPot} disabled={activeCards.length === 0 || (creditPotSource === 'paycheck' && !viewedPeriod)}>
                  {editingCreditCardPotId ? 'Save credit pot' : 'Add credit pot'}
                </Button>
                {editingCreditCardPotId && (
                  <Button variant="secondary" onClick={resetCreditCardPotForm}>
                    Cancel
                  </Button>
                )}
              </div>
            </div>
          </Panel>

          <Panel
            title={editingRepaymentId ? 'Edit card repayment' : 'Record card repayment'}
            description="Repayments reduce the amount shown as owed."
          >
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
              <div className="flex flex-wrap gap-3">
                <Button onClick={submitRepayment} disabled={activeCards.length === 0}>
                  {editingRepaymentId ? 'Save repayment' : 'Record repayment'}
                </Button>
                {editingRepaymentId && (
                  <Button variant="secondary" onClick={resetRepaymentForm}>
                    Cancel
                  </Button>
                )}
              </div>
            </div>
          </Panel>
        </div>

        <div className="space-y-6">
          <Panel title="Credit pots" description="Paycheck pots reduce dashboard money left; external pots are tracked only against the card.">
            <div className="space-y-3">
              {activeCreditCardPots.length > 0 ? (
                activeCreditCardPots.map((creditCardPot) => {
                  const card = snapshot.creditCards.find((candidate) => candidate.id === creditCardPot.creditCardId)

                  return (
                    <CreditCardPotRow
                      key={creditCardPot.id}
                      creditCardPot={creditCardPot}
                      cardName={card?.name ?? 'Archived card'}
                      onApply={(creditCardPotId, creditCardPotName) => {
                        if (window.confirm(`Apply ${creditCardPotName} as a card repayment?`)) {
                          void actions.applyCreditCardPot(creditCardPotId, {
                            date: toIsoDate(new Date()),
                            note: creditCardPotName,
                          })
                        }
                      }}
                      onDelete={(creditCardPotId, creditCardPotName) => {
                        if (window.confirm(`Delete ${creditCardPotName}?`)) {
                          void actions.deleteCreditCardPot(creditCardPotId)
                        }
                      }}
                      onEdit={startEditingCreditCardPot}
                    />
                  )
                })
              ) : (
                <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No credit pots yet.</p>
              )}
            </div>
          </Panel>

          <Panel title="Credit cards" description="Tap a card for the full editable overview.">
            <div className="grid gap-4 lg:grid-cols-2">
              {summary.cards.length > 0 ? (
                summary.cards.map((cardSummary) => (
                  <button
                    key={cardSummary.card.id}
                    type="button"
                    onClick={() => setSelectedCardId(cardSummary.card.id)}
                    className="rounded-lg border border-slate-200 bg-white p-4 text-left transition hover:-translate-y-0.5 hover:border-slate-300 hover:shadow-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-slate-950"
                  >
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
                      <CreditCardIcon size={20} className="text-slate-400" />
                    </div>
                    <div className="mt-5 grid gap-3 sm:grid-cols-2">
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Owed</p>
                        <p className="mt-1 text-2xl font-semibold text-slate-950">{formatPence(cardSummary.owedPence)}</p>
                      </div>
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Available</p>
                        <p className="mt-1 text-2xl font-semibold text-slate-950">{formatPence(cardSummary.availableCreditPence)}</p>
                      </div>
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">In credit pots</p>
                        <p className="mt-1 text-2xl font-semibold text-emerald-700">{formatPence(cardSummary.creditPotPence)}</p>
                      </div>
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Left after pots</p>
                        <p className="mt-1 text-2xl font-semibold text-slate-950">{formatPence(cardSummary.remainingAfterCreditPotsPence)}</p>
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
                      <div className="mt-3 flex flex-wrap gap-2">
                        <span className="rounded-md bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-600">
                          {cardSummary.utilisationPercent}% of {formatPence(cardSummary.card.limitPence)}
                        </span>
                        <span className="rounded-md bg-blue-50 px-2 py-1 text-xs font-semibold text-blue-700">
                          {cardSummary.items.length} linked items
                        </span>
                      </div>
                    </div>
                  </button>
                ))
              ) : (
                <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No credit cards yet.</p>
              )}
            </div>
          </Panel>

          <Panel title="Payment allocation list" description="Link payments and card spending into cards by pay period.">
            <div className="space-y-3">
              {paymentGroups.length > 0 ? (
                paymentGroups.map((group, index) => (
                  <details
                    key={group.id}
                    open={group.isSelected || (!viewedPeriod && index === 0)}
                    className={
                      group.isSelected
                        ? 'rounded-lg border border-slate-950 bg-white shadow-sm'
                        : 'rounded-lg border border-slate-200 bg-white'
                    }
                  >
                    <summary className="cursor-pointer list-none px-4 py-3">
                      <div className="flex items-center justify-between gap-3">
                        <div>
                          <div className="flex flex-wrap items-center gap-2">
                            <p className="text-sm font-semibold text-slate-950">{group.label}</p>
                            {group.isSelected && (
                              <span className="rounded-md bg-slate-950 px-2 py-1 text-xs font-semibold text-white">
                                Viewing
                              </span>
                            )}
                          </div>
                          <p className="mt-1 text-xs text-slate-500">{group.rows.length} payments</p>
                        </div>
                        <p className="text-sm font-semibold text-slate-950">{formatPence(group.totalPence)}</p>
                      </div>
                    </summary>
                    <div className="space-y-3 border-t border-slate-100 p-3">
                      <CalculationDetails breakdown={getPaymentGroupBreakdown(group)} />
                      {group.rows.map((row) => (
                        <PaymentAllocationRow
                          key={row.id}
                          activeCards={activeCards}
                          row={row}
                          onDeleteCustomPayment={(paymentId, paymentName) => {
                            if (window.confirm(`Delete ${paymentName}?`)) {
                              void actions.deleteCustomPayment(paymentId)
                            }
                          }}
                          onLinkPayment={linkPayment}
                        />
                      ))}
                    </div>
                  </details>
                ))
              ) : (
                <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">
                  No payments or card spending are available to allocate yet.
                </p>
              )}
            </div>
          </Panel>

          <Panel title="Card repayments" description="Edit or delete repayments already recorded.">
            <div className="space-y-3">
              {snapshot.creditCardRepayments.length > 0 ? (
                snapshot.creditCardRepayments.map((repayment) => {
                  const card = snapshot.creditCards.find((candidate) => candidate.id === repayment.creditCardId)

                  return (
                    <div
                      key={repayment.id}
                      className="flex flex-col gap-3 rounded-lg bg-slate-50 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
                    >
                      <div>
                        <p className="text-sm font-semibold text-slate-950">{repayment.note || 'Card repayment'}</p>
                        <p className="mt-1 text-xs text-slate-500">
                          {repayment.date} · {card?.name ?? 'Archived card'}
                        </p>
                      </div>
                      <div className="flex items-center gap-3">
                        <p className="text-sm font-semibold text-emerald-700">-{formatPence(repayment.amountPence)}</p>
                        <Button variant="secondary" onClick={() => startEditingRepayment(repayment.id)} aria-label={`Edit repayment ${repayment.note || repayment.date}`}>
                          <PenLine size={16} />
                        </Button>
                        <Button
                          variant="danger"
                          onClick={() => {
                            if (window.confirm('Delete this card repayment?')) {
                              void actions.deleteCreditCardRepayment(repayment.id)
                            }
                          }}
                          aria-label={`Delete repayment ${repayment.note || repayment.date}`}
                        >
                          <Trash2 size={16} />
                        </Button>
                      </div>
                    </div>
                  )
                })
              ) : (
                <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No repayments recorded yet.</p>
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

interface PaymentGroup {
  id: string
  label: string
  rows: PaymentRow[]
  totalPence: number
  isSelected: boolean
  sortDate: string
}

function getPaymentGroupBreakdown(group: PaymentGroup): CalculationBreakdown {
  return {
    formula: 'Payment group total = every row listed in this pay-period dropdown.',
    lines:
      group.rows.length > 0
        ? [
            ...group.rows.map((row) => ({
              label: row.label,
              value: formatPence(row.amountPence),
              detail: `${row.date} · ${row.sourceLabel}`,
              tone: 'add' as const,
            })),
            {
              label: 'Payment group total',
              value: formatPence(group.totalPence),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No rows', value: formatPence(0), tone: 'result' }],
  }
}

function PaymentAllocationRow({
  activeCards,
  row,
  onDeleteCustomPayment,
  onLinkPayment,
}: {
  activeCards: PlannerSnapshot['creditCards']
  row: PaymentRow
  onDeleteCustomPayment: (paymentId: string, paymentName: string) => void
  onLinkPayment: (row: PaymentRow, creditCardId: string) => Promise<void>
}) {
  return (
    <div className="grid gap-3 rounded-lg border border-slate-200 bg-white p-4 md:grid-cols-[1fr_180px_auto]">
      <div>
        <div className="flex flex-wrap items-center gap-2">
          <p className="text-sm font-semibold text-slate-950">{row.label}</p>
          <span className={sourceBadgeClass(row.source)}>{row.sourceLabel}</span>
        </div>
        <p className="mt-1 text-xs text-slate-500">
          {row.date} · {formatPence(row.amountPence)}
        </p>
      </div>
      <SelectInput value={row.creditCardId ?? ''} onChange={(event) => void onLinkPayment(row, event.target.value)}>
        <option value="">Unlinked</option>
        {activeCards.map((card) => (
          <option key={card.id} value={card.id}>
            {card.name} ({card.provider})
          </option>
        ))}
      </SelectInput>
      <div className="flex gap-2">
        {row.source === 'custom' && (
          <Button variant="danger" onClick={() => onDeleteCustomPayment(row.entityId, row.label)} aria-label={`Delete ${row.label}`}>
            <Trash2 size={16} />
          </Button>
        )}
      </div>
    </div>
  )
}

function CreditCardPotRow({
  creditCardPot,
  cardName,
  onApply,
  onDelete,
  onEdit,
}: {
  creditCardPot: PlannerSnapshot['creditCardPots'][number]
  cardName: string
  onApply: (creditCardPotId: string, creditCardPotName: string) => void
  onDelete: (creditCardPotId: string, creditCardPotName: string) => void
  onEdit: (creditCardPotId: string) => void
}) {
  return (
    <div className="grid gap-3 rounded-lg border border-slate-200 bg-white p-4 md:grid-cols-[1fr_auto] md:items-center">
      <div>
        <div className="flex flex-wrap items-center gap-2">
          <p className="text-sm font-semibold text-slate-950">{creditCardPot.name}</p>
          <span className={creditPotSourceBadgeClass(creditCardPot.source)}>
            {creditCardPot.source === 'paycheck' ? 'Paycheck' : 'External'}
          </span>
        </div>
        <p className="mt-1 text-xs text-slate-500">
          {cardName} · {creditCardPot.source === 'paycheck' && creditCardPot.periodStartDate && creditCardPot.periodEndDate
            ? `${creditCardPot.periodStartDate} to ${creditCardPot.periodEndDate}`
            : 'Not deducted from paycheck'}
        </p>
        {creditCardPot.note && <p className="mt-2 text-xs text-slate-500">{creditCardPot.note}</p>}
      </div>
      <div className="flex flex-wrap items-center gap-2 md:justify-end">
        <p className="mr-1 text-sm font-semibold text-emerald-700">{formatPence(creditCardPot.amountPence)}</p>
        <Button variant="secondary" onClick={() => onEdit(creditCardPot.id)} aria-label={`Edit ${creditCardPot.name}`}>
          <PenLine size={16} />
        </Button>
        <Button variant="secondary" onClick={() => onApply(creditCardPot.id, creditCardPot.name)}>
          Apply payment
        </Button>
        <Button variant="danger" onClick={() => onDelete(creditCardPot.id, creditCardPot.name)} aria-label={`Delete ${creditCardPot.name}`}>
          <Trash2 size={16} />
        </Button>
      </div>
    </div>
  )
}

function CreditCardOverview({
  activeCards,
  cardSummary,
  snapshot,
  payPeriod,
  onBack,
  onDeleteCard,
  onDeleteCustomPayment,
  onDeleteRepayment,
  onDeleteCreditCardPot,
  onApplyCreditCardPot,
  onEditCard,
  onEditCreditCardPot,
  onEditRepayment,
  onLinkPayment,
}: {
  activeCards: PlannerSnapshot['creditCards']
  cardSummary: CreditCardAllocationCardSummary
  snapshot: PlannerSnapshot
  payPeriod: PayPeriod | null
  onBack: () => void
  onDeleteCard: (cardId: string, cardName: string) => void
  onDeleteCustomPayment: (paymentId: string, paymentName: string) => void
  onDeleteRepayment: (repaymentId: string) => void
  onDeleteCreditCardPot: (creditCardPotId: string, creditCardPotName: string) => void
  onApplyCreditCardPot: (creditCardPotId: string, creditCardPotName: string) => void
  onEditCard: (cardId: string) => void
  onEditCreditCardPot: (creditCardPotId: string) => void
  onEditRepayment: (repaymentId: string) => void
  onLinkPayment: (row: PaymentRow, creditCardId: string) => Promise<void>
}) {
  const chargedPence = cardSummary.items
    .filter((item) => item.source !== 'repayment')
    .reduce((total, item) => total + item.amountPence, 0)
  const repaidPence = Math.abs(
    cardSummary.items
      .filter((item) => item.source === 'repayment')
      .reduce((total, item) => total + item.amountPence, 0),
  )
  const cardCreditPots = snapshot.creditCardPots.filter(
    (creditCardPot) =>
      creditCardPot.creditCardId === cardSummary.card.id &&
      creditCardPot.status === 'active' &&
      isCreditCardPotVisibleInPeriod(creditCardPot, payPeriod),
  )

  return (
    <div className="space-y-6">
      <Panel>
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <Button variant="secondary" onClick={onBack}>
              <ArrowLeft size={18} />
              Back
            </Button>
            <div className="mt-5 flex items-center gap-3">
              <span className="size-4 rounded-full" style={{ backgroundColor: cardSummary.card.color }} />
              <div>
                <h2 className="text-2xl font-semibold text-slate-950">{cardSummary.card.name}</h2>
                <p className="mt-1 text-sm text-slate-500">
                  {cardSummary.card.provider} · due {cardSummary.dueLabel}
                </p>
              </div>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button variant="secondary" onClick={() => onEditCard(cardSummary.card.id)}>
              <PenLine size={16} />
              Edit card
            </Button>
            <Button variant="danger" onClick={() => onDeleteCard(cardSummary.card.id, cardSummary.card.name)}>
              <Trash2 size={16} />
              Delete card
            </Button>
          </div>
        </div>
      </Panel>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <MoneyMetric
          label="Owed now"
          value={formatPence(cardSummary.owedPence)}
          tone={cardSummary.owedPence > 0 ? 'warning' : 'good'}
          breakdown={getCardOwedBreakdown(cardSummary, chargedPence, repaidPence)}
        />
        <MoneyMetric
          label="Left on card"
          value={formatPence(cardSummary.availableCreditPence)}
          breakdown={{
            formula: 'Left on card = card limit - owed now.',
            lines: [
              { label: 'Card limit', value: formatPence(cardSummary.card.limitPence), tone: 'add' },
              { label: 'Owed now', value: `-${formatPence(cardSummary.owedPence)}`, tone: 'subtract' },
              { label: 'Left on card', value: formatPence(cardSummary.availableCreditPence), tone: 'result' },
            ],
          }}
        />
        <MoneyMetric
          label="In credit pots"
          value={formatPence(cardSummary.creditPotPence)}
          tone={cardSummary.creditPotPence > 0 ? 'good' : 'neutral'}
          breakdown={getSingleCardCreditPotsBreakdown(cardSummary, cardCreditPots)}
        />
        <MoneyMetric
          label="Taken this period"
          value={formatPence(chargedPence)}
          tone={chargedPence > 0 ? 'warning' : 'neutral'}
          breakdown={getCardChargesBreakdown(cardSummary)}
        />
        <MoneyMetric
          label="Repaid this period"
          value={formatPence(repaidPence)}
          tone={repaidPence > 0 ? 'good' : 'neutral'}
          breakdown={getCardRepaymentsBreakdown(cardSummary, repaidPence)}
        />
      </div>

      <Panel title="Credit pots for this card" description="Set-aside money is separate from real repayments until you apply it.">
        <div className="space-y-3">
          {cardCreditPots.length > 0 ? (
            cardCreditPots.map((creditCardPot) => (
              <CreditCardPotRow
                key={creditCardPot.id}
                creditCardPot={creditCardPot}
                cardName={cardSummary.card.name}
                onApply={onApplyCreditCardPot}
                onDelete={onDeleteCreditCardPot}
                onEdit={onEditCreditCardPot}
              />
            ))
          ) : (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No credit pots set aside for this card.</p>
          )}
        </div>
      </Panel>

      <Panel title="What changed this card" description="Every linked charge and repayment in the selected pay period.">
        <div className="space-y-3">
          {cardSummary.items.length > 0 ? (
            cardSummary.items.map((item) => (
              <CreditCardOverviewItem
                key={item.id}
                activeCards={activeCards}
                item={item}
                snapshot={snapshot}
                onDeleteCustomPayment={onDeleteCustomPayment}
                onDeleteRepayment={onDeleteRepayment}
                onEditRepayment={onEditRepayment}
                onLinkPayment={onLinkPayment}
              />
            ))
          ) : (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No linked charges in this pay period.</p>
          )}
        </div>
      </Panel>
    </div>
  )
}

function getCardsOwedBreakdown(cards: CreditCardAllocationCardSummary[]): CalculationBreakdown {
  return {
    formula: 'Cards owed = the sum of each active card balance for this pay period.',
    lines:
      cards.length > 0
        ? [
            ...cards.map((cardSummary) => ({
              label: cardSummary.card.name,
              value: formatPence(cardSummary.owedPence),
              detail: `${cardSummary.items.length} linked items after repayments.`,
              tone: cardSummary.owedPence > 0 ? ('add' as const) : ('muted' as const),
            })),
            {
              label: 'Cards owed',
              value: formatPence(cards.reduce((total, cardSummary) => total + cardSummary.owedPence, 0)),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No active cards', value: formatPence(0), tone: 'result' }],
    note: 'Each card balance is floored at zero so overpayments do not create negative owed amounts.',
  }
}

function getCreditPotsBreakdown(cards: CreditCardAllocationCardSummary[]): CalculationBreakdown {
  const totalCreditPotsPence = cards.reduce((total, cardSummary) => total + cardSummary.creditPotPence, 0)

  return {
    formula: 'Credit pots = active set-asides linked to cards. Paycheck pots reduce dashboard money left; external pots do not.',
    lines:
      cards.length > 0
        ? [
            ...cards.map((cardSummary) => ({
              label: cardSummary.card.name,
              value: formatPence(cardSummary.creditPotPence),
              detail: `${formatPence(cardSummary.paycheckCreditPotPence)} from paychecks · ${formatPence(cardSummary.externalCreditPotPence)} external.`,
              tone: cardSummary.creditPotPence > 0 ? ('add' as const) : ('muted' as const),
            })),
            {
              label: 'Credit pots',
              value: formatPence(totalCreditPotsPence),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No active cards', value: formatPence(0), tone: 'result' }],
    note: 'These do not reduce card owed until you apply or record an actual card repayment.',
  }
}

function getSingleCardCreditPotsBreakdown(
  cardSummary: CreditCardAllocationCardSummary,
  creditCardPots: PlannerSnapshot['creditCardPots'],
): CalculationBreakdown {
  return {
    formula: 'In credit pots = active set-aside money linked to this card.',
    lines:
      creditCardPots.length > 0
        ? [
            ...creditCardPots.map((creditCardPot) => ({
              label: creditCardPot.name,
              value: formatPence(creditCardPot.amountPence),
              detail:
                creditCardPot.source === 'paycheck'
                  ? `Deducted from paycheck${creditCardPot.payday ? ` on ${creditCardPot.payday}` : ''}.`
                  : 'External money, not deducted from paycheck.',
              tone: 'add' as const,
            })),
            {
              label: 'In credit pots',
              value: formatPence(cardSummary.creditPotPence),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No active credit pots', value: formatPence(0), tone: 'result' }],
    note: `${formatPence(cardSummary.remainingAfterCreditPotsPence)} would remain after applying these pots to the card balance shown here.`,
  }
}

function getCardOwedBreakdown(
  cardSummary: CreditCardAllocationCardSummary,
  chargedPence: number,
  repaidPence: number,
): CalculationBreakdown {
  return {
    formula: 'Owed now = linked charges - repayments, never below zero.',
    lines: [
      {
        label: 'Linked charges',
        value: formatPence(chargedPence),
        detail: 'Recurring, saved payments, and credit-card spending linked to this card.',
        tone: 'add',
      },
      {
        label: 'Repayments',
        value: `-${formatPence(repaidPence)}`,
        detail: 'Repayments recorded against this card in the selected pay period.',
        tone: 'subtract',
      },
      {
        label: 'Owed now',
        value: formatPence(cardSummary.owedPence),
        tone: 'result',
      },
    ],
  }
}

function getCardChargesBreakdown(cardSummary: CreditCardAllocationCardSummary): CalculationBreakdown {
  const chargeItems = cardSummary.items.filter((item) => item.source !== 'repayment')
  const chargedPence = chargeItems.reduce((total, item) => total + item.amountPence, 0)

  return {
    formula: 'Taken this period = every non-repayment item linked to this card.',
    lines:
      chargeItems.length > 0
        ? [
            ...chargeItems.map((item) => ({
              label: item.label,
              value: formatPence(item.amountPence),
              detail: `${item.date} · ${overviewSourceLabel(item.source)}`,
              tone: 'add' as const,
            })),
            {
              label: 'Taken this period',
              value: formatPence(chargedPence),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No linked charges', value: formatPence(0), tone: 'result' }],
  }
}

function getCardRepaymentsBreakdown(
  cardSummary: CreditCardAllocationCardSummary,
  repaidPence: number,
): CalculationBreakdown {
  const repaymentItems = cardSummary.items.filter((item) => item.source === 'repayment')

  return {
    formula: 'Repaid this period = repayments recorded against this card.',
    lines:
      repaymentItems.length > 0
        ? [
            ...repaymentItems.map((item) => ({
              label: item.label,
              value: formatPence(Math.abs(item.amountPence)),
              detail: item.date,
              tone: 'subtract' as const,
            })),
            {
              label: 'Repaid this period',
              value: formatPence(repaidPence),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No repayments', value: formatPence(0), tone: 'result' }],
  }
}

function CreditCardOverviewItem({
  activeCards,
  item,
  snapshot,
  onDeleteCustomPayment,
  onDeleteRepayment,
  onEditRepayment,
  onLinkPayment,
}: {
  activeCards: PlannerSnapshot['creditCards']
  item: CreditCardAllocationItem
  snapshot: PlannerSnapshot
  onDeleteCustomPayment: (paymentId: string, paymentName: string) => void
  onDeleteRepayment: (repaymentId: string) => void
  onEditRepayment: (repaymentId: string) => void
  onLinkPayment: (row: PaymentRow, creditCardId: string) => Promise<void>
}) {
  const row = creditCardItemToPaymentRow(item)
  const isRepayment = item.source === 'repayment'
  const repaymentId = isRepayment ? item.id.replace('repayment-', '') : null
  const amountClassName = item.amountPence < 0 ? 'text-emerald-700' : 'text-red-700'

  return (
    <div className="grid gap-3 rounded-lg border border-slate-200 bg-white p-4 lg:grid-cols-[1fr_180px_auto]">
      <div>
        <div className="flex flex-wrap items-center gap-2">
          <p className="text-sm font-semibold text-slate-950">{item.label}</p>
          <span className={overviewBadgeClass(item.source)}>{overviewSourceLabel(item.source)}</span>
        </div>
        <p className="mt-1 text-xs text-slate-500">
          {item.date} · {whereFromLabel(item, snapshot)}
        </p>
      </div>
      <p className={`self-center text-sm font-semibold ${amountClassName}`}>
        {item.amountPence < 0 ? '-' : ''}
        {formatPence(Math.abs(item.amountPence))}
      </p>
      <div className="flex flex-wrap gap-2">
        {row && (
          <SelectInput value={row.creditCardId ?? ''} onChange={(event) => void onLinkPayment(row, event.target.value)}>
            <option value="">Unlinked</option>
            {activeCards.map((card) => (
              <option key={card.id} value={card.id}>
                {card.name} ({card.provider})
              </option>
            ))}
          </SelectInput>
        )}
        {item.source === 'custom' && row && (
          <Button variant="danger" onClick={() => onDeleteCustomPayment(row.entityId, item.label)} aria-label={`Delete ${item.label}`}>
            <Trash2 size={16} />
          </Button>
        )}
        {isRepayment && repaymentId && (
          <>
            <Button variant="secondary" onClick={() => onEditRepayment(repaymentId)} aria-label={`Edit ${item.label}`}>
              <PenLine size={16} />
            </Button>
            <Button variant="danger" onClick={() => onDeleteRepayment(repaymentId)} aria-label={`Delete ${item.label}`}>
              <Trash2 size={16} />
            </Button>
          </>
        )}
      </div>
    </div>
  )
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
        sourceLabel: 'Saved payment',
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

function groupPaymentRowsByPeriod(
  rows: PaymentRow[],
  snapshot: PlannerSnapshot,
  selectedPayPeriod: PayPeriod | null,
): PaymentGroup[] {
  const groups = new Map<string, PaymentGroup>()

  if (selectedPayPeriod) {
    groups.set(selectedPayPeriod.id, {
      id: selectedPayPeriod.id,
      label: `${selectedPayPeriod.payday} pay period · ${selectedPayPeriod.startDate} to ${selectedPayPeriod.endDate}`,
      rows: [],
      totalPence: 0,
      isSelected: true,
      sortDate: selectedPayPeriod.startDate,
    })
  }

  for (const row of rows) {
    const period = isIsoDate(row.date) ? findPayPeriodForDate(snapshot.payPeriods, row.date) : null
    const id = period?.id ?? (isIsoDate(row.date) ? 'outside-periods' : 'recurring-templates')
    const label = period
      ? `${period.payday} pay period · ${period.startDate} to ${period.endDate}`
      : isIsoDate(row.date)
        ? 'Outside saved pay periods'
        : 'Recurring templates'
    const existingGroup =
      groups.get(id) ??
      {
        id,
        label,
        rows: [],
        totalPence: 0,
        isSelected: period?.id === selectedPayPeriod?.id,
        sortDate: period?.startDate ?? (isIsoDate(row.date) ? row.date : '9999-12-31'),
      }

    existingGroup.rows.push(row)
    existingGroup.totalPence += row.amountPence
    groups.set(id, existingGroup)
  }

  return [...groups.values()].sort((a, b) => {
    if (a.isSelected !== b.isSelected) {
      return a.isSelected ? -1 : 1
    }

    return b.sortDate.localeCompare(a.sortDate)
  })
}

function recurringPaymentToRow(payment: RecurringPayment): PaymentRow {
  return {
    id: `recurring-${payment.id}`,
    entityId: payment.id,
    source: 'recurring',
    sourceLabel: 'Recurring',
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

function creditCardItemToPaymentRow(item: CreditCardAllocationItem): PaymentRow | null {
  if (item.source === 'repayment') {
    return null
  }

  if (item.source === 'recurring') {
    const entityId = item.id.slice('recurring-'.length, -11)

    return {
      id: `recurring-${entityId}`,
      entityId,
      source: 'recurring',
      sourceLabel: 'Recurring',
      label: item.label,
      amountPence: item.amountPence,
      date: item.date,
      creditCardId: item.creditCardId ?? null,
    }
  }

  if (item.source === 'custom') {
    const entityId = item.id.replace('custom-', '')

    return {
      id: `custom-${entityId}`,
      entityId,
      source: 'custom',
      sourceLabel: 'Saved payment',
      label: item.label,
      amountPence: item.amountPence,
      date: item.date,
      creditCardId: item.creditCardId ?? null,
    }
  }

  const entityId = item.id.replace('transaction-', '')

  return {
    id: `transaction-${entityId}`,
    entityId,
    source: 'transaction',
    sourceLabel: 'Spending',
    label: item.label,
    amountPence: item.amountPence,
    date: item.date,
    creditCardId: item.creditCardId ?? null,
  }
}

function whereFromLabel(item: CreditCardAllocationItem, snapshot: PlannerSnapshot): string {
  if (item.source === 'repayment') {
    return 'Card repayment'
  }

  if (item.potId) {
    return snapshot.pots.find((pot) => pot.id === item.potId)?.name ?? 'Archived pot'
  }

  if (item.creditCardId) {
    return snapshot.creditCards.find((card) => card.id === item.creditCardId)?.name ?? 'Archived card'
  }

  return 'Unlinked'
}

function sourceBadgeClass(source: PaymentRowSource): string {
  if (source === 'recurring') {
    return 'rounded-md bg-indigo-50 px-2 py-1 text-xs font-semibold text-indigo-700'
  }

  if (source === 'custom') {
    return 'rounded-md bg-amber-50 px-2 py-1 text-xs font-semibold text-amber-700'
  }

  return 'rounded-md bg-rose-50 px-2 py-1 text-xs font-semibold text-rose-700'
}

function creditPotSourceBadgeClass(source: CreditCardPotSource): string {
  if (source === 'paycheck') {
    return 'rounded-md bg-slate-950 px-2 py-1 text-xs font-semibold text-white'
  }

  return 'rounded-md bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-700'
}

function isCreditCardPotVisibleInPeriod(
  creditCardPot: PlannerSnapshot['creditCardPots'][number],
  payPeriod: PayPeriod | null,
): boolean {
  if (!payPeriod || creditCardPot.source === 'external') {
    return true
  }

  if (creditCardPot.payPeriodId) {
    return creditCardPot.payPeriodId === payPeriod.id
  }

  return creditCardPot.periodStartDate === payPeriod.startDate && creditCardPot.periodEndDate === payPeriod.endDate
}

function overviewBadgeClass(source: CreditCardAllocationItem['source']): string {
  if (source === 'recurring') {
    return 'rounded-md bg-indigo-50 px-2 py-1 text-xs font-semibold text-indigo-700'
  }

  if (source === 'custom') {
    return 'rounded-md bg-amber-50 px-2 py-1 text-xs font-semibold text-amber-700'
  }

  if (source === 'repayment') {
    return 'rounded-md bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-700'
  }

  return 'rounded-md bg-rose-50 px-2 py-1 text-xs font-semibold text-rose-700'
}

function overviewSourceLabel(source: CreditCardAllocationItem['source']): string {
  if (source === 'recurring') {
    return 'Recurring'
  }

  if (source === 'custom') {
    return 'Saved payment'
  }

  if (source === 'repayment') {
    return 'Repayment'
  }

  return 'Spending'
}

function isIsoDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value)
}
