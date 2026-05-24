import { useMemo, useState } from 'react'
import { ArrowLeft, Check, PenLine, PlusCircle, Trash2, X } from 'lucide-react'

import {
  creditCardDesigns,
  defaultCreditCardDesignId,
  getCreditCardDesign,
  normalizeCreditCardDesignId,
  type CreditCardDesign,
} from '../domain/creditCardDesigns'
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
import {
  Button,
  CalculationDetails,
  Field,
  MoneyMetric,
  Panel,
  SectionGrid,
  SelectInput,
  TextInput,
  type CalculationBreakdown,
} from '../components/ui'
import type { PayPeriod, RecurringPayment, Transaction } from '../types/models'

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
  const [openSummaryMetric, setOpenSummaryMetric] = useState<string | null>(null)
  const [editingCardId, setEditingCardId] = useState<string | null>(null)
  const [cardName, setCardName] = useState('')
  const [cardProvider, setCardProvider] = useState('')
  const [cardLimit, setCardLimit] = useState('')
  const [cardOpeningBalance, setCardOpeningBalance] = useState('')
  const [cardDueDay, setCardDueDay] = useState('1')
  const [cardColor, setCardColor] = useState(cardColors[0])
  const [cardDesignId, setCardDesignId] = useState(defaultCreditCardDesignId)
  const [isCardDesignModalOpen, setIsCardDesignModalOpen] = useState(false)
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
  const selectedCardSummary = selectedCardId
    ? summary.cards.find((cardSummary) => cardSummary.card.id === selectedCardId) ?? null
    : null

  async function submitCard() {
    const limitPence = parsePoundsToPence(cardLimit)
    const openingBalancePence = parsePoundsToPence(cardOpeningBalance)
    const dueDay = Number.parseInt(cardDueDay, 10)

    if (!cardName.trim() || !cardProvider.trim() || limitPence <= 0 || openingBalancePence < 0 || dueDay < 1 || dueDay > 31) {
      return
    }

    const payload = {
      name: cardName.trim(),
      provider: cardProvider.trim(),
      limitPence,
      openingBalancePence,
      designId: cardDesignId,
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
      paymentMethod: nextCardId ? 'credit_card' : transaction.potId ? 'pot' : undefined,
      creditCardId: nextCardId,
    })
  }

  function startEditingCard(cardId: string) {
    const card = snapshot.creditCards.find((candidate) => candidate.id === cardId)

    if (!card) {
      return
    }

    setEditingCardId(card.id)
    setCardName(card.name)
    setCardProvider(card.provider)
    setCardLimit((card.limitPence / 100).toFixed(2))
    setCardOpeningBalance(((card.openingBalancePence ?? 0) / 100).toFixed(2))
    setCardDueDay(String(card.dueDay ?? 1))
    setCardColor(card.color)
    setCardDesignId(normalizeCreditCardDesignId(card.designId))
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
    setCardOpeningBalance('')
    setCardDueDay('1')
    setCardColor(cardColors[0])
    setCardDesignId(defaultCreditCardDesignId)
    setIsCardDesignModalOpen(false)
  }

  function resetRepaymentForm() {
    setEditingRepaymentId(null)
    setRepaymentAmount('')
    setRepaymentNote('')
    setRepaymentDate(toIsoDate(new Date()))
    setRepaymentCardId(activeCards[0]?.id ?? '')
  }

  function renderCardForm(submitLabel: string, showCancel = false) {
    const selectedDesign = getCreditCardDesign(cardDesignId)

    return (
      <div className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Card name">
            <TextInput value={cardName} onChange={(event) => setCardName(event.target.value)} placeholder="Everyday Amex" />
          </Field>
          <Field label="Provider">
            <TextInput value={cardProvider} onChange={(event) => setCardProvider(event.target.value)} placeholder="Amex" />
          </Field>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Limit">
            <TextInput inputMode="decimal" value={cardLimit} onChange={(event) => setCardLimit(event.target.value)} placeholder="1000.00" />
          </Field>
          <Field label="Existing balance" hint="What you already owe on this card before tracking new payments.">
            <TextInput
              aria-label="Existing balance"
              inputMode="decimal"
              value={cardOpeningBalance}
              onChange={(event) => setCardOpeningBalance(event.target.value)}
              placeholder="0.00"
            />
          </Field>
        </div>
        <Field label="Due date" hint="Day of the month this card is due.">
          <TextInput
            aria-label="Due date"
            inputMode="numeric"
            value={cardDueDay}
            onChange={(event) => setCardDueDay(event.target.value)}
          />
        </Field>
        <Field label="Card design">
          <div className="flex flex-col gap-3 rounded-lg border border-slate-200 bg-slate-50 p-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex min-w-0 items-center gap-3">
              <div className={`figma-credit-card credit-card-design-summary__art figma-credit-card--${selectedDesign.id}`} aria-hidden="true">
                <CreditCardArtwork design={selectedDesign} />
              </div>
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-slate-950">{selectedDesign.label}</p>
                <p className="mt-1 text-xs text-slate-500">Selected design</p>
              </div>
            </div>
            <Button variant="secondary" aria-label="Card design" onClick={() => setIsCardDesignModalOpen(true)}>
              Card design
            </Button>
          </div>
        </Field>
        {isCardDesignModalOpen && (
          <CreditCardDesignModal
            selectedDesignId={cardDesignId}
            onClose={() => setIsCardDesignModalOpen(false)}
            onSelect={(designId) => {
              setCardDesignId(designId)
              setIsCardDesignModalOpen(false)
            }}
          />
        )}
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
            {submitLabel}
          </Button>
          {showCancel && (
            <Button variant="secondary" onClick={resetCardForm}>
              Cancel
            </Button>
          )}
        </div>
      </div>
    )
  }

  if (selectedCardSummary) {
    return (
      <>
        <CreditCardOverview
          cardSummary={selectedCardSummary}
          snapshot={snapshot}
          onBack={() => {
            resetCardForm()
            setSelectedCardId(null)
          }}
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
          onEditCard={startEditingCard}
          onEditRepayment={startEditingRepayment}
        />
        {editingCardId && (
          <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/45 p-4">
            <div
              role="dialog"
              aria-modal="true"
              aria-label="Edit credit card"
              className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-lg border border-slate-200 bg-white p-5 shadow-xl"
            >
              <div className="mb-4 flex items-start justify-between gap-4 border-b border-slate-100 pb-4">
                <div>
                  <h2 className="text-base font-semibold text-slate-950">Edit credit card</h2>
                  <p className="mt-1 text-sm text-slate-500">Update the card details without leaving this overview.</p>
                </div>
                <Button variant="ghost" onClick={resetCardForm} aria-label="Close edit card">
                  <X size={18} />
                </Button>
              </div>
              {renderCardForm('Save card', true)}
            </div>
          </div>
        )}
      </>
    )
  }

  return (
    <div className="space-y-6">
      <Panel title="Credit card summary" description="Selected pay, card balances, and linked credit pots." accent="cyan">
        <div className="grid items-start gap-4 md:grid-cols-3">
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
            open={openSummaryMetric === 'selected-pay'}
            onOpenChange={(isOpen) =>
              setOpenSummaryMetric((current) => isOpen ? 'selected-pay' : current === 'selected-pay' ? null : current)
            }
          />
          <MoneyMetric
            label="Credit pots"
            value={formatPence(summary.totalCreditPotsPence)}
            tone={summary.totalCreditPotsPence > 0 ? 'good' : 'neutral'}
            breakdown={getCreditPotsBreakdown(summary.cards)}
            open={openSummaryMetric === 'credit-pots'}
            onOpenChange={(isOpen) =>
              setOpenSummaryMetric((current) => isOpen ? 'credit-pots' : current === 'credit-pots' ? null : current)
            }
          />
          <MoneyMetric
            label="Cards owed"
            value={formatPence(summary.totalOwedPence)}
            tone={summary.totalOwedPence > 0 ? 'warning' : 'neutral'}
            breakdown={getCardsOwedBreakdown(summary.cards)}
            open={openSummaryMetric === 'cards-owed'}
            onOpenChange={(isOpen) =>
              setOpenSummaryMetric((current) => isOpen ? 'cards-owed' : current === 'cards-owed' ? null : current)
            }
          />
        </div>
      </Panel>

      <SectionGrid variant="balanced">
        <Panel
          title="Add credit card"
          description="Cards group linked payments, spending, and repayments."
          accent="blue"
          density="compact"
        >
          {renderCardForm('Add card')}
        </Panel>

        <Panel
          title={editingRepaymentId ? 'Edit card repayment' : 'Record card repayment'}
          description="Repayments reduce the amount shown as owed."
          accent="amber"
          density="compact"
        >
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
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
            </div>
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
      </SectionGrid>

      <Panel title="Credit cards" description="Tap a card for the full editable overview." accent="cyan" density="compact">
        <div className="grid justify-items-center gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {summary.cards.length > 0 ? (
            summary.cards.map((cardSummary) => (
              <CreditCardPreviewButton
                key={cardSummary.card.id}
                cardSummary={cardSummary}
                onClick={() => setSelectedCardId(cardSummary.card.id)}
              />
            ))
          ) : (
            <p className="w-full rounded-lg bg-slate-50 p-4 text-sm text-slate-500 sm:col-span-2 lg:col-span-3">
              No credit cards yet.
            </p>
          )}
        </div>
      </Panel>

      <SectionGrid variant="balanced">
          <Panel
            title="Payment allocation list"
            description="Link payments and card spending into cards by pay period."
            accent="violet"
            density="compact"
          >
            <div className="space-y-3 xl:max-h-[760px] xl:overflow-y-auto xl:pr-1">
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

          <Panel title="Card repayments" description="Edit or delete repayments already recorded." accent="amber" density="compact">
            <div className="space-y-3 xl:max-h-[760px] xl:overflow-y-auto xl:pr-1">
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
      </SectionGrid>
    </div>
  )
}

type CreditCardVisualDetails = {
  limit: string
  owed: string
  available: string
  name: string
  provider: string
  dueDate: string
}

function CreditCardDesignModal({
  selectedDesignId,
  onSelect,
  onClose,
}: {
  selectedDesignId: string
  onSelect: (designId: string) => void
  onClose: () => void
}) {
  return (
    <div className="fixed inset-0 z-[60] grid place-items-center bg-slate-950/45 p-4">
      <div
        role="dialog"
        aria-modal="true"
        aria-label="Card design"
        className="max-h-[90vh] w-full max-w-4xl overflow-y-auto rounded-lg border border-slate-200 bg-white p-5 shadow-xl"
      >
        <div className="mb-4 flex items-start justify-between gap-4 border-b border-slate-100 pb-4">
          <div>
            <h2 className="text-base font-semibold text-slate-950">Card design</h2>
            <p className="mt-1 text-sm text-slate-500">Choose the design shown on this card.</p>
          </div>
          <Button variant="ghost" onClick={onClose} aria-label="Close card design">
            <X size={18} />
          </Button>
        </div>
        <div className="credit-card-design-picker">
          {creditCardDesigns.map((design) => {
            const isSelected = normalizeCreditCardDesignId(selectedDesignId) === design.id

            return (
              <button
                key={design.id}
                type="button"
                aria-pressed={isSelected}
                className="credit-card-design-picker__option"
                onClick={() => onSelect(design.id)}
              >
                <div className={`figma-credit-card credit-card-design-picker__art figma-credit-card--${design.id}`} aria-hidden="true">
                  <CreditCardArtwork design={design} />
                </div>
                <span>{design.label}</span>
                {isSelected && <Check size={16} aria-hidden="true" />}
              </button>
            )
          })}
        </div>
      </div>
    </div>
  )
}

function CreditCardPreviewButton({
  cardSummary,
  onClick,
}: {
  cardSummary: CreditCardAllocationCardSummary
  onClick: () => void
}) {
  const design = getCreditCardDesign(cardSummary.card.designId)

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={`Open ${cardSummary.card.name} card details`}
      className="figma-card-button"
    >
      <FigmaCreditCard details={getCreditCardVisualDetails(cardSummary)} design={design} />
      <div className="figma-card-button__summary">
        <p className="figma-card-button__name">{cardSummary.card.name}</p>
        <p className="figma-card-button__meta">
          <span><strong>{formatPence(cardSummary.owedPence)}</strong> owed</span>
          <span><strong>{formatPence(cardSummary.availableCreditPence)}</strong> available</span>
          <span>{cardSummary.dueLabel}</span>
        </p>
      </div>
    </button>
  )
}

function FigmaCreditCard({ details, design }: { details: CreditCardVisualDetails; design: CreditCardDesign }) {
  return (
    <div
      className={`figma-credit-card figma-credit-card--${design.id}`}
      aria-label={`${details.name} credit card`}
      data-figma-file="IM8pUThhZaULAtixfqj42D"
      data-figma-design={design.id}
      data-node-id={design.nodeId}
    >
      <CreditCardArtwork design={design} />
      <div className="figma-credit-card__content">
        <div className="figma-credit-card__identity">
          <span>{details.provider}</span>
          <strong>{details.name}</strong>
        </div>
        <div className="figma-credit-card__due">
          <span>Due date</span>
          <strong>{details.dueDate}</strong>
        </div>
        <dl className="figma-credit-card__metrics">
          <div>
            <dt>Limit</dt>
            <dd>{details.limit}</dd>
          </div>
          <div>
            <dt>Owed</dt>
            <dd>{details.owed}</dd>
          </div>
          <div>
            <dt>Available</dt>
            <dd>{details.available}</dd>
          </div>
        </dl>
      </div>
      <span className="sr-only">
        {details.name}, due {details.dueDate}, {details.limit} limit, {details.owed} owed after credit pots, {details.available} available.
      </span>
    </div>
  )
}

function CreditCardArtwork({ design }: { design: CreditCardDesign }) {
  const assetPath = design.assetPath

  if (design.id === 'cart-minimal-11') {
    return (
      <div className="figma-credit-card__art" aria-hidden="true">
        <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/mask-vector.svg`} alt="" />
        <div className="figma-credit-card__stripe" />
        <img className="figma-credit-card__layer figma-credit-card__noise" src="/figma-assets/noise.png" alt="" />
        <img className="figma-credit-card__logo figma-credit-card__logo--contactless" src={`${assetPath}/contactless-logo.svg`} alt="" />
        <img className="figma-credit-card__logo figma-credit-card__logo--visa" src={`${assetPath}/visa-logo.svg`} alt="" />
        <img className="figma-credit-card__chip" src={`${assetPath}/chip.svg`} alt="" />
      </div>
    )
  }

  if (design.id === 'cart-minimal-13') {
    return (
      <div className="figma-credit-card__art" aria-hidden="true">
        <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/card-mask.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/contour-lines.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--bottom" src={`${assetPath}/bottom-panel.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__noise" src="/figma-assets/noise.png" alt="" />
        <img className="figma-credit-card__logo figma-credit-card__logo--mastercard" src={`${assetPath}/mastercard-logo.svg`} alt="" />
        <img className="figma-credit-card__chip" src={`${assetPath}/chip.svg`} alt="" />
      </div>
    )
  }

  if (design.id === 'cart-gradient-11' || design.id === 'cart-gradient-12') {
    return (
      <div className="figma-credit-card__art" aria-hidden="true">
        <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/mask-vector.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--oversized" src={`${assetPath}/background-vector.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__noise" src="/figma-assets/noise.png" alt="" />
        <img className="figma-credit-card__logo figma-credit-card__logo--visa" src={`${assetPath}/visa-logo.svg`} alt="" />
        <img className="figma-credit-card__chip" src={`${assetPath}/chip.svg`} alt="" />
      </div>
    )
  }

  if (design.id === 'cart-geometric-11') {
    return (
      <div className="figma-credit-card__art" aria-hidden="true">
        <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/mask-vector.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--circle" src={`${assetPath}/circle.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__noise" src="/figma-assets/noise.png" alt="" />
        <img className="figma-credit-card__logo figma-credit-card__logo--visa" src={`${assetPath}/visa-logo.svg`} alt="" />
        <img className="figma-credit-card__chip" src={`${assetPath}/chip.svg`} alt="" />
      </div>
    )
  }

  if (design.id === 'cart-geometric-1') {
    return (
      <div className="figma-credit-card__art" aria-hidden="true">
        <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/mask-vector.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--geometric-1-circle" src={`${assetPath}/circle.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__noise" src="/figma-assets/noise.png" alt="" />
        <img className="figma-credit-card__logo figma-credit-card__logo--split" src={`${assetPath}/visa-logo.svg`} alt="" />
        <img className="figma-credit-card__chip" src={`${assetPath}/chip.svg`} alt="" />
      </div>
    )
  }

  if (isCartGeometric4Design(design.id)) {
    return (
      <div className="figma-credit-card__art" aria-hidden="true">
        <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/card-mask.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--geometric-4-circle" src={`${assetPath}/circle.svg`} alt="" />
        {design.id === 'cart-geometric-4' && (
          <img className="figma-credit-card__layer figma-credit-card__layer--geometric-4-bottom" src={`${assetPath}/bottom-panel.svg`} alt="" />
        )}
        <img className="figma-credit-card__layer figma-credit-card__noise" src="/figma-assets/noise.png" alt="" />
        <img className="figma-credit-card__logo figma-credit-card__logo--mastercard" src={`${assetPath}/mastercard-logo.svg`} alt="" />
        <img className="figma-credit-card__chip" src={`${assetPath}/chip.svg`} alt="" />
      </div>
    )
  }

  if (design.id === 'cart-geometric-15') {
    return (
      <div className="figma-credit-card__art" aria-hidden="true">
        <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/mask-rectangle.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--left-panel" src={`${assetPath}/green-panel.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--right-panel" src={`${assetPath}/right-panel.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__layer--geometric" src={`${assetPath}/geometric-vector.svg`} alt="" />
        <img className="figma-credit-card__layer figma-credit-card__noise" src="/figma-assets/noise.png" alt="" />
        <img className="figma-credit-card__logo figma-credit-card__logo--visa" src={`${assetPath}/visa-logo.svg`} alt="" />
        <img className="figma-credit-card__chip" src={`${assetPath}/chip.svg`} alt="" />
      </div>
    )
  }

  return (
    <div className="figma-credit-card__art" aria-hidden="true">
      <img className="figma-credit-card__layer figma-credit-card__layer--full" src={`${assetPath}/background-panel.svg`} alt="" />
      <img className="figma-credit-card__layer figma-credit-card__layer--corner-circle" src={`${assetPath}/corner-circle.svg`} alt="" />
      <img className="figma-credit-card__layer figma-credit-card__layer--chevron-back" src={`${assetPath}/chevron-back.svg`} alt="" />
      <img className="figma-credit-card__layer figma-credit-card__layer--chevron-front" src={`${assetPath}/chevron-front.svg`} alt="" />
      <img className="figma-credit-card__layer figma-credit-card__layer--right-panel" src={`${assetPath}/right-panel.svg`} alt="" />
      <img className="figma-credit-card__layer figma-credit-card__noise" src="/figma-assets/noise.png" alt="" />
      <img className="figma-credit-card__logo figma-credit-card__logo--visa" src={`${assetPath}/visa-logo.svg`} alt="" />
      <img className="figma-credit-card__chip" src={`${assetPath}/chip.svg`} alt="" />
    </div>
  )
}

function isCartGeometric4Design(designId: string): boolean {
  return designId === 'cart-geometric-4' || designId.startsWith('cart-geometric-4-')
}

function getCreditCardVisualDetails(cardSummary: CreditCardAllocationCardSummary): CreditCardVisualDetails {
  return {
    limit: formatPence(cardSummary.card.limitPence),
    owed: formatPence(cardSummary.remainingAfterCreditPotsPence),
    available: formatPence(cardSummary.availableCreditPence),
    name: cardSummary.card.name,
    provider: cardSummary.card.provider,
    dueDate: cardSummary.dueLabel,
  }
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

function CreditCardOverview({
  cardSummary,
  snapshot,
  onBack,
  onDeleteCard,
  onDeleteCustomPayment,
  onDeleteRepayment,
  onEditCard,
  onEditRepayment,
}: {
  cardSummary: CreditCardAllocationCardSummary
  snapshot: PlannerSnapshot
  onBack: () => void
  onDeleteCard: (cardId: string, cardName: string) => void
  onDeleteCustomPayment: (paymentId: string, paymentName: string) => void
  onDeleteRepayment: (repaymentId: string) => void
  onEditCard: (cardId: string) => void
  onEditRepayment: (repaymentId: string) => void
}) {
  const design = getCreditCardDesign(cardSummary.card.designId)
  const chargedPence = cardSummary.items
    .filter((item) => item.source !== 'repayment')
    .reduce((total, item) => total + item.amountPence, 0)
  const repaidPence = Math.abs(
    cardSummary.items
      .filter((item) => item.source === 'repayment')
      .reduce((total, item) => total + item.amountPence, 0),
  )

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <Button variant="secondary" onClick={onBack}>
          <ArrowLeft size={18} />
          Back
        </Button>
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

      <div className="grid gap-6 xl:grid-cols-[minmax(320px,0.95fr)_minmax(0,1.05fr)]">
        <div className="space-y-4">
          <div className="max-w-[561px]">
            <FigmaCreditCard details={getCreditCardVisualDetails(cardSummary)} design={design} />
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <CreditCardStat label="Balance" value={formatPence(cardSummary.owedPence)} tone={cardSummary.owedPence > 0 ? 'warning' : 'good'} />
            <CreditCardStat label="Available" value={formatPence(cardSummary.availableCreditPence)} tone="good" />
            <CreditCardStat label="Due" value={cardSummary.dueLabel} tone="neutral" />
            <CreditCardStat
              label="Used"
              value={`${cardSummary.utilisationPercent}%`}
              detail={`${formatPence(cardSummary.card.limitPence)} limit`}
              tone={cardSummary.utilisationPercent >= 80 ? 'bad' : cardSummary.utilisationPercent >= 50 ? 'warning' : 'neutral'}
            />
          </div>
        </div>

        <Panel
          title="Card activity"
          description="Charges and repayments in the selected pay period."
          accent="violet"
          density="compact"
        >
          <div className="mb-4 grid gap-3 sm:grid-cols-2">
            <CreditCardStat label="Charged" value={formatPence(chargedPence)} tone={chargedPence > 0 ? 'bad' : 'neutral'} />
            <CreditCardStat label="Repaid" value={formatPence(repaidPence)} tone={repaidPence > 0 ? 'good' : 'neutral'} />
          </div>
          <div className="space-y-3 xl:max-h-[620px] xl:overflow-y-auto xl:pr-1">
            {cardSummary.items.length > 0 ? (
              cardSummary.items.map((item) => (
                <CreditCardActivityRow
                  key={item.id}
                  item={item}
                  snapshot={snapshot}
                  onDeleteCustomPayment={onDeleteCustomPayment}
                  onDeleteRepayment={onDeleteRepayment}
                  onEditRepayment={onEditRepayment}
                />
              ))
            ) : (
              <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No card activity in this pay period.</p>
            )}
          </div>
        </Panel>
      </div>
    </div>
  )
}

function CreditCardStat({
  label,
  value,
  detail,
  tone = 'neutral',
}: {
  label: string
  value: string
  detail?: string
  tone?: 'neutral' | 'good' | 'warning' | 'bad'
}) {
  return (
    <div className={creditCardStatClass(tone)}>
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 text-xl font-semibold text-slate-950">{value}</p>
      {detail && <p className="mt-1 text-xs text-slate-500">{detail}</p>}
    </div>
  )
}

function creditCardStatClass(tone: 'neutral' | 'good' | 'warning' | 'bad'): string {
  if (tone === 'good') {
    return 'rounded-lg border border-emerald-200 bg-emerald-50 p-4'
  }

  if (tone === 'warning') {
    return 'rounded-lg border border-amber-200 bg-amber-50 p-4'
  }

  if (tone === 'bad') {
    return 'rounded-lg border border-red-200 bg-red-50 p-4'
  }

  return 'rounded-lg border border-slate-200 bg-white p-4'
}

function CreditCardActivityRow({
  item,
  snapshot,
  onDeleteCustomPayment,
  onDeleteRepayment,
  onEditRepayment,
}: {
  item: CreditCardAllocationItem
  snapshot: PlannerSnapshot
  onDeleteCustomPayment: (paymentId: string, paymentName: string) => void
  onDeleteRepayment: (repaymentId: string) => void
  onEditRepayment: (repaymentId: string) => void
}) {
  const isRepayment = item.source === 'repayment'
  const repaymentId = isRepayment ? item.id.replace('repayment-', '') : null
  const customPaymentId = item.source === 'custom' ? item.id.replace('custom-', '') : null
  const amountClassName = item.amountPence < 0 ? 'text-emerald-700' : 'text-red-700'

  return (
    <div className={`grid gap-3 rounded-lg border bg-white p-4 sm:grid-cols-[1fr_auto] ${overviewBorderClass(item.source)}`}>
      <div>
        <div className="flex flex-wrap items-center gap-2">
          <p className="text-sm font-semibold text-slate-950">{item.label}</p>
          <span className={overviewBadgeClass(item.source)}>{overviewSourceLabel(item.source)}</span>
        </div>
        <p className="mt-1 text-xs text-slate-500">
          {item.date} · {whereFromLabel(item, snapshot)}
        </p>
      </div>
      <div className="flex flex-wrap items-center gap-2 sm:justify-end">
        <p className={`text-sm font-semibold ${amountClassName}`}>
          {item.amountPence < 0 ? '-' : ''}
          {formatPence(Math.abs(item.amountPence))}
        </p>
        {customPaymentId && (
          <Button variant="danger" onClick={() => onDeleteCustomPayment(customPaymentId, item.label)} aria-label={`Delete ${item.label}`}>
            <Trash2 size={16} />
          </Button>
        )}
        {repaymentId && (
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

function getCardsOwedBreakdown(cards: CreditCardAllocationCardSummary[]): CalculationBreakdown {
  return {
    formula: 'Cards owed = existing balances + tracked card charges - repayments, up to the selected period end.',
    lines:
      cards.length > 0
        ? [
            ...cards.map((cardSummary) => ({
              label: cardSummary.card.name,
              value: formatPence(cardSummary.owedPence),
              detail: `${formatPence(cardSummary.openingBalancePence)} existing balance · ${cardSummary.balanceItems.length} tracked balance movements.`,
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

function overviewBorderClass(source: CreditCardAllocationItem['source']): string {
  if (source === 'recurring') {
    return 'border-indigo-200 border-l-indigo-500 border-l-4'
  }

  if (source === 'custom') {
    return 'border-amber-200 border-l-amber-500 border-l-4'
  }

  if (source === 'repayment') {
    return 'border-emerald-200 border-l-emerald-500 border-l-4'
  }

  return 'border-rose-200 border-l-rose-500 border-l-4'
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
