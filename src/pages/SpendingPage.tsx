import { useState, type ReactNode } from 'react'
import {
  CalendarDays,
  ChevronDown,
  CreditCard,
  PenLine,
  ReceiptText,
  Sparkles,
  Trash2,
  WalletCards,
} from 'lucide-react'

import { findPayPeriodForDate, formatPence, getAppTodayIso, parsePoundsToPence } from '../domain/money'
import type {
  PlannerActions,
  PlannerSnapshot,
  TransactionInput,
  TransactionUpdateInput,
} from '../hooks/usePlannerData'
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
import type { PaymentMethod, PayPeriod } from '../types/models'

const quickAmounts = ['3.00', '5.00', '10.00', '20.00', '50.00']
type QuickSpendLinkMethod = PaymentMethod | 'unlinked'

export function SpendingPage({
  snapshot,
  actions,
  selectedPayPeriod,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
  selectedPayPeriod?: PayPeriod | null
}) {
  const today = getAppTodayIso(snapshot.settings)
  const activePots = snapshot.pots.filter((pot) => !pot.archived)
  const activeCards = snapshot.creditCards.filter((card) => !card.archived)
  const [potId, setPotId] = useState('')
  const [paymentMethod, setPaymentMethod] = useState<QuickSpendLinkMethod>('unlinked')
  const [creditCardId, setCreditCardId] = useState('')
  const [amount, setAmount] = useState('')
  const [date, setDate] = useState(today)
  const [note, setNote] = useState('')
  const [editingTransactionId, setEditingTransactionId] = useState<string | null>(null)
  const selectedPot = activePots.find((pot) => pot.id === potId)
  const selectedCard = activeCards.find((card) => card.id === creditCardId)
  const recentNotes = Array.from(
    new Set(
      snapshot.transactions
        .map((transaction) => transaction.note.trim())
        .filter((candidate) => candidate && candidate !== 'Manual spend'),
    ),
  ).slice(0, 4)
  const parsedAmountPence = parsePoundsToPence(amount)
  const canSubmitSpend = parsedAmountPence > 0 && Boolean(date)
  const groupedTransactions = groupTransactionsByPeriod(snapshot.transactions, snapshot, selectedPayPeriod ?? null)
  const selectedTransactionGroup = selectedPayPeriod
    ? groupedTransactions.find((group) => group.id === selectedPayPeriod.id) ?? null
    : groupedTransactions[0] ?? null
  const selectedPeriodSpendPence = selectedTransactionGroup?.totalPence ?? 0
  const todaySpendPence = snapshot.transactions
    .filter((transaction) => transaction.date === today)
    .reduce((totalPence, transaction) => totalPence + transaction.amountPence, 0)
  const linkedCardSpendPence = snapshot.transactions
    .filter((transaction) => transaction.paymentMethod === 'credit_card' || transaction.creditCardId)
    .reduce((totalPence, transaction) => totalPence + transaction.amountPence, 0)
  const potLinkedSpendPence = snapshot.transactions
    .filter((transaction) => transaction.potId && transaction.paymentMethod !== 'credit_card' && !transaction.creditCardId)
    .reduce((totalPence, transaction) => totalPence + transaction.amountPence, 0)
  const unlinkedSpendPence = snapshot.transactions
    .filter((transaction) => !transaction.potId && !transaction.creditCardId && transaction.paymentMethod !== 'credit_card')
    .reduce((totalPence, transaction) => totalPence + transaction.amountPence, 0)
  const recentTransactions = [...snapshot.transactions]
    .sort((left, right) => right.date.localeCompare(left.date))
    .slice(0, 3)

  async function submitTransaction() {
    const amountPence = parsedAmountPence

    if (amountPence <= 0 || !date) {
      return
    }

    const linkFields = getQuickSpendLinkFields(paymentMethod, potId, creditCardId, activePots)

    if (editingTransactionId) {
      const updateInput: TransactionUpdateInput = {
        amountPence,
        date,
        note: note.trim() || 'Manual spend',
        ...linkFields,
      }

      await actions.updateTransaction(editingTransactionId, updateInput)
      resetForm()
      return
    }

    const addInput: TransactionInput = {
      amountPence,
      type: 'spending',
      date,
      note: note.trim() || 'Manual spend',
      payPeriodId: findPayPeriodForDate(snapshot.payPeriods, date)?.id ?? null,
      ...linkFields,
    }

    await actions.addTransaction(addInput)
    resetForm()
  }

  function startEditingTransaction(transactionId: string) {
    const transaction = snapshot.transactions.find((candidate) => candidate.id === transactionId)

    if (!transaction) {
      return
    }

    setEditingTransactionId(transaction.id)
    setPotId(transaction.potId ?? '')
    setPaymentMethod(getTransactionLinkMethod(transaction))
    setCreditCardId(transaction.creditCardId ?? '')
    setAmount((transaction.amountPence / 100).toFixed(2))
    setDate(transaction.date)
    setNote(transaction.note)
  }

  function resetForm() {
    setEditingTransactionId(null)
    setPotId('')
    setPaymentMethod('unlinked')
    setCreditCardId('')
    setAmount('')
    setDate(today)
    setNote('')
  }

  function changePaymentMethod(nextMethod: QuickSpendLinkMethod) {
    setPaymentMethod(nextMethod)

    if (nextMethod === 'pot' && !potId) {
      setPotId(activePots[0]?.id ?? '')
    }

    if (nextMethod === 'credit_card' && !creditCardId) {
      setCreditCardId(activeCards[0]?.id ?? '')
    }
  }

  return (
    <div className="space-y-6">
      <SpendingCommandCenter
        today={today}
        selectedPayPeriod={selectedPayPeriod ?? null}
        selectedPeriodSpendPence={selectedPeriodSpendPence}
        selectedPeriodEntryCount={selectedTransactionGroup?.transactions.length ?? 0}
        todaySpendPence={todaySpendPence}
        linkedCardSpendPence={linkedCardSpendPence}
        potLinkedSpendPence={potLinkedSpendPence}
        unlinkedSpendPence={unlinkedSpendPence}
        recentTransactions={recentTransactions}
        snapshot={snapshot}
      />

      <div className="grid gap-3 md:grid-cols-3">
        <MoneyMetric
          label="Today logged"
          value={formatSpendTotal(todaySpendPence)}
          tone={todaySpendPence > 0 ? 'bad' : 'neutral'}
          breakdown={getSpendingMetricBreakdown('Today logged', snapshot.transactions.filter((transaction) => transaction.date === today), snapshot)}
        />
        <MoneyMetric
          label={selectedPayPeriod ? 'Selected paycheck' : 'Latest paycheck'}
          value={formatSpendTotal(selectedPeriodSpendPence)}
          tone={selectedPeriodSpendPence > 0 ? 'warning' : 'neutral'}
        />
        <MoneyMetric
          label="Card-linked spend"
          value={formatSpendTotal(linkedCardSpendPence)}
          tone={linkedCardSpendPence > 0 ? 'primary' : 'neutral'}
        />
      </div>
      <SectionGrid variant="wideRight">
        <Panel
          title={editingTransactionId ? 'Edit spending entry' : 'Quick spend'}
          description="Log money quickly, with an optional pot or credit card link."
          accent="blue"
          density="compact"
        >
          <div className="space-y-4">
            <SpendPreviewCard
              amountPence={parsedAmountPence}
              date={date}
              note={note}
              linkLabel={getSelectedSpendLinkLabel(paymentMethod, selectedPot?.name, selectedCard?.name)}
              paymentMethod={paymentMethod}
              isEditing={Boolean(editingTransactionId)}
            />
            <Field label="Amount">
              <TextInput inputMode="decimal" value={amount} onChange={(event) => setAmount(event.target.value)} placeholder="12.50" />
            </Field>
            <div className="flex flex-wrap gap-2" aria-label="Quick amounts">
              {quickAmounts.map((quickAmount) => (
                <button
                  key={quickAmount}
                  type="button"
                  onClick={() => setAmount(quickAmount)}
                  className="rounded-lg border border-slate-200/90 bg-white/95 px-3 py-2 text-sm font-semibold text-slate-700 shadow-sm shadow-slate-200/60 transition hover:-translate-y-0.5 hover:border-blue-200 hover:bg-white"
                >
                  {formatPence(parsePoundsToPence(quickAmount))}
                </button>
              ))}
            </div>
            <Field label="Link spend to">
              <SelectInput value={paymentMethod} onChange={(event) => changePaymentMethod(event.target.value as QuickSpendLinkMethod)}>
                <option value="unlinked">Unlinked</option>
                <option value="pot">Pot</option>
                <option value="credit_card" disabled={activeCards.length === 0}>
                  Credit card
                </option>
              </SelectInput>
            </Field>
            {paymentMethod === 'pot' && (
              <Field
                label="Pot"
                hint={
                  selectedPot?.linkedCreditCardId
                    ? 'This logs card spend and adds the cover to the linked card pot checklist.'
                    : 'Spending from a normal pot deducts its balance now.'
                }
              >
                <SelectInput aria-label="Pot" value={potId} onChange={(event) => setPotId(event.target.value)}>
                  <option value="">No pot linked</option>
                  {activePots.map((pot) => (
                    <option key={pot.id} value={pot.id}>
                      {pot.name} · {formatPence(pot.balancePence)}
                      {pot.linkedCreditCardId ? ' · card cover' : ''}
                    </option>
                  ))}
                </SelectInput>
              </Field>
            )}
            {paymentMethod === 'credit_card' && (
              <Field label="Credit card" hint="Optional. Choose no card to keep this spend unlinked.">
                <SelectInput aria-label="Credit card" value={creditCardId} onChange={(event) => setCreditCardId(event.target.value)}>
                  <option value="">No credit card linked</option>
                  {activeCards.map((card) => (
                    <option key={card.id} value={card.id}>
                      {card.name} ({card.provider})
                    </option>
                  ))}
                </SelectInput>
              </Field>
            )}
            <Field label="Date">
              <div className="grid gap-2 sm:grid-cols-[1fr_auto]">
                <TextInput type="date" value={date} onChange={(event) => setDate(event.target.value)} />
                <Button variant="secondary" onClick={() => setDate(today)}>
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
                    className="rounded-lg border border-slate-200/70 bg-white/[0.85] px-3 py-2 text-sm font-medium text-slate-700 shadow-sm shadow-slate-200/50 transition hover:-translate-y-0.5 hover:border-blue-200 hover:bg-white"
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
            <div className="sticky bottom-3 z-10 rounded-lg border border-slate-200/90 bg-white/95 p-3 shadow-[0_18px_45px_rgba(15,23,42,0.13)] backdrop-blur xl:hidden">
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="truncate text-sm font-semibold text-slate-950">
                    {parsedAmountPence > 0 ? formatPence(parsedAmountPence) : 'No amount'} · {getSelectedSpendLinkLabel(paymentMethod, selectedPot?.name, selectedCard?.name)}
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

        <Panel
          title="Spending by pay period"
          description="Manual spending is grouped into the pay period containing its date."
          accent="rose"
          density="compact"
        >
          <div className="space-y-3 xl:max-h-[720px] xl:overflow-y-auto xl:pr-1">
            {groupedTransactions.length > 0 ? (
              groupedTransactions.map((group, index) => (
                <details
                  key={group.id}
                  open={group.isSelected || (!selectedPayPeriod && index === 0)}
                  className={
                    group.isSelected
                      ? 'group rounded-lg border border-slate-950 bg-white/95 shadow-[0_14px_35px_rgba(15,23,42,0.08)]'
                      : 'group rounded-lg border border-slate-200/90 bg-white/95 shadow-sm shadow-slate-200/60'
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
                        <p className="mt-1 text-xs text-slate-500">{group.transactions.length} entries</p>
                      </div>
                      <div className="flex items-center gap-2">
                        <p className="text-sm font-semibold text-red-700">-{formatPence(group.totalPence)}</p>
                        <ChevronDown size={17} className="shrink-0 text-slate-400 transition group-open:rotate-180" />
                      </div>
                    </div>
                  </summary>
                  <div className="border-t border-slate-100 p-3">
                    <CalculationDetails breakdown={getSpendingGroupBreakdown(group, snapshot)} />
                  </div>
                  <div className="divide-y divide-slate-100">
                    {group.transactions.map((transaction) => {
                      return (
                        <div key={transaction.id} className="flex items-center justify-between gap-4 px-4 py-3">
                          <div>
                            <p className="text-sm font-semibold text-slate-950">{transaction.note}</p>
                            <p className="text-xs text-slate-500">
                              {transaction.date} · {getTransactionLinkLabel(transaction, snapshot)}
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
                    })}
                  </div>
                </details>
              ))
            ) : (
              <p className="rounded-lg border border-dashed border-slate-200/90 bg-slate-50/80 p-4 text-sm text-slate-500">No spending entries yet.</p>
            )}
          </div>
        </Panel>
      </SectionGrid>
    </div>
  )
}

function SpendingCommandCenter({
  today,
  selectedPayPeriod,
  selectedPeriodSpendPence,
  selectedPeriodEntryCount,
  todaySpendPence,
  linkedCardSpendPence,
  potLinkedSpendPence,
  unlinkedSpendPence,
  recentTransactions,
  snapshot,
}: {
  today: string
  selectedPayPeriod: PayPeriod | null
  selectedPeriodSpendPence: number
  selectedPeriodEntryCount: number
  todaySpendPence: number
  linkedCardSpendPence: number
  potLinkedSpendPence: number
  unlinkedSpendPence: number
  recentTransactions: PlannerSnapshot['transactions']
  snapshot: PlannerSnapshot
}) {
  const routedSpendPence = linkedCardSpendPence + potLinkedSpendPence
  const allSpendPence = routedSpendPence + unlinkedSpendPence
  const routedPercent = allSpendPence > 0 ? Math.round((routedSpendPence / allSpendPence) * 100) : 0
  const cardWidth = allSpendPence > 0 ? `${Math.min(100, Math.round((linkedCardSpendPence / allSpendPence) * 100))}%` : '0%'
  const potWidth = allSpendPence > 0 ? `${Math.min(100, Math.round((potLinkedSpendPence / allSpendPence) * 100))}%` : '0%'
  const unlinkedWidth = allSpendPence > 0 ? `${Math.min(100, Math.round((unlinkedSpendPence / allSpendPence) * 100))}%` : '0%'
  const periodLabel = selectedPayPeriod
    ? `${selectedPayPeriod.startDate} to ${selectedPayPeriod.endDate}`
    : 'No paycheck selected'

  return (
    <section className="overflow-hidden rounded-2xl border border-slate-900 bg-[linear-gradient(135deg,#020617_0%,#111827_48%,#3a1830_100%)] text-white shadow-[0_24px_70px_rgba(15,23,42,0.24)]">
      <div className="grid gap-5 p-5 lg:grid-cols-[minmax(0,1fr)_minmax(300px,0.44fr)]">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-3">
            <span className="flex size-10 items-center justify-center rounded-2xl border border-rose-300/25 bg-rose-300/10 text-rose-100 shadow-inner shadow-white/10">
              <ReceiptText size={20} />
            </span>
            <div className="min-w-0">
              <h2 className="text-xl font-semibold text-white">Spending command desk</h2>
              <p className="mt-1 text-sm leading-5 text-slate-300">{periodLabel}</p>
            </div>
          </div>

          <div className="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <SpendCommandMetric
              icon={<CalendarDays size={17} />}
              label="Today"
              value={formatSpendTotal(todaySpendPence)}
              detail={today}
            />
            <SpendCommandMetric
              icon={<WalletCards size={17} />}
              label="Paycheck spend"
              value={formatSpendTotal(selectedPeriodSpendPence)}
              detail={`${selectedPeriodEntryCount} entr${selectedPeriodEntryCount === 1 ? 'y' : 'ies'} in view`}
              tone="amber"
            />
            <SpendCommandMetric
              icon={<CreditCard size={17} />}
              label="Card route"
              value={formatSpendTotal(linkedCardSpendPence)}
              detail="Feeds card cover and future direct debits"
              tone="cyan"
            />
            <SpendCommandMetric
              icon={<Sparkles size={17} />}
              label="Routed"
              value={`${routedPercent}%`}
              detail={`${formatSpendTotal(routedSpendPence)} linked to cards or pots`}
              tone="emerald"
            />
          </div>

          <div className="mt-5 rounded-2xl border border-white/10 bg-white/[0.06] p-4">
            <div className="flex flex-wrap items-center justify-between gap-2 text-xs font-semibold uppercase tracking-wide text-slate-300">
              <span>Spend routing</span>
              <span>{formatSpendTotal(allSpendPence)} total logged</span>
            </div>
            <div className="mt-4 overflow-hidden rounded-full bg-slate-950/50 p-1 shadow-inner shadow-slate-950">
              <div className="flex h-3 overflow-hidden rounded-full bg-white/10">
                <div className="bg-cyan-300" style={{ width: cardWidth }} />
                <div className="bg-emerald-300" style={{ width: potWidth }} />
                <div className="bg-rose-300" style={{ width: unlinkedWidth }} />
              </div>
            </div>
            <div className="mt-3 grid gap-2 text-xs font-semibold text-slate-300 sm:grid-cols-3">
              <SpendRouteLabel colorClass="bg-cyan-300" label="Cards" value={formatSpendTotal(linkedCardSpendPence)} />
              <SpendRouteLabel colorClass="bg-emerald-300" label="Pots" value={formatSpendTotal(potLinkedSpendPence)} />
              <SpendRouteLabel colorClass="bg-rose-300" label="Unlinked" value={formatSpendTotal(unlinkedSpendPence)} />
            </div>
          </div>
        </div>

        <div className="min-w-0 rounded-2xl border border-white/10 bg-white/[0.07] p-4 shadow-inner shadow-white/10">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-semibold uppercase tracking-wide text-rose-100/80">Recent trail</p>
              <p className="mt-2 text-3xl font-semibold text-white">{recentTransactions.length}</p>
            </div>
            <span className="rounded-xl border border-white/10 bg-white/10 px-3 py-2 text-xs font-semibold text-rose-50">
              Latest entries
            </span>
          </div>
          <div className="mt-5 space-y-3">
            {recentTransactions.length > 0 ? (
              recentTransactions.map((transaction) => (
                <div key={transaction.id} className="rounded-xl border border-white/10 bg-slate-950/25 p-3">
                  <div className="flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold text-white">{transaction.note}</p>
                      <p className="mt-0.5 text-xs text-slate-400">{transaction.date} · {getTransactionLinkLabel(transaction, snapshot)}</p>
                    </div>
                    <p className="text-sm font-semibold text-rose-100">{formatSpendTotal(transaction.amountPence)}</p>
                  </div>
                </div>
              ))
            ) : (
              <div className="rounded-xl border border-dashed border-white/15 bg-slate-950/25 p-4 text-sm text-slate-300">
                Log spend to build a recent trail.
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  )
}

function SpendCommandMetric({
  icon,
  label,
  value,
  detail,
  tone = 'rose',
}: {
  icon: ReactNode
  label: string
  value: string
  detail: string
  tone?: 'rose' | 'amber' | 'cyan' | 'emerald'
}) {
  const toneClassName =
    tone === 'amber'
      ? 'border-amber-300/20 bg-amber-300/10 text-amber-100'
      : tone === 'cyan'
        ? 'border-cyan-300/20 bg-cyan-300/10 text-cyan-100'
        : tone === 'emerald'
          ? 'border-emerald-300/20 bg-emerald-300/10 text-emerald-100'
          : 'border-rose-300/20 bg-rose-300/10 text-rose-100'

  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.07] p-3 shadow-inner shadow-white/10 sm:p-4">
      <div className={`mb-3 flex size-8 items-center justify-center rounded-xl sm:size-9 ${toneClassName}`}>
        {icon}
      </div>
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">{label}</p>
      <p className="mt-1 text-xl font-semibold text-white sm:text-2xl">{value}</p>
      <p className="mt-2 text-[11px] leading-5 text-slate-400 sm:text-xs">{detail}</p>
    </div>
  )
}

function SpendRouteLabel({ colorClass, label, value }: { colorClass: string; label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-2 rounded-xl border border-white/10 bg-slate-950/25 px-3 py-2">
      <span className="flex items-center gap-2">
        <span className={`size-2 rounded-full ${colorClass}`} />
        {label}
      </span>
      <span className="text-white">{value}</span>
    </div>
  )
}

function SpendPreviewCard({
  amountPence,
  date,
  note,
  linkLabel,
  paymentMethod,
  isEditing,
}: {
  amountPence: number
  date: string
  note: string
  linkLabel: string
  paymentMethod: QuickSpendLinkMethod
  isEditing: boolean
}) {
  const icon =
    paymentMethod === 'credit_card' ? <CreditCard size={17} /> : paymentMethod === 'pot' ? <WalletCards size={17} /> : <ReceiptText size={17} />
  const amountLabel = amountPence > 0 ? formatPence(amountPence) : '£0.00'
  const noteLabel = note.trim() || 'Manual spend'

  return (
    <div className="overflow-hidden rounded-2xl border border-blue-200/90 bg-[linear-gradient(135deg,#020617,#071526_54%,#0f2d36)] text-white shadow-[0_18px_55px_rgba(15,23,42,0.16)]">
      <div className="flex items-start justify-between gap-3 p-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-cyan-200">
            <Sparkles size={15} />
            {isEditing ? 'Editing spend' : 'Ready to log'}
          </div>
          <p className="mt-3 text-3xl font-semibold tracking-[-0.03em] text-white">
            {amountPence > 0 ? '-' : ''}{amountLabel}
          </p>
          <p className="mt-1 truncate text-sm text-slate-300">{noteLabel}</p>
        </div>
        <div className="flex size-11 shrink-0 items-center justify-center rounded-2xl border border-white/10 bg-white/10 text-cyan-100 shadow-inner shadow-white/10">
          {icon}
        </div>
      </div>
      <div className="grid gap-2 border-t border-white/10 bg-white/[0.06] p-3 sm:grid-cols-2">
        <div className="rounded-lg border border-white/10 bg-white/[0.08] px-3 py-2">
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-400">
            <CalendarDays size={14} />
            Date
          </div>
          <p className="mt-1 truncate text-sm font-semibold text-white">{date}</p>
        </div>
        <div className="rounded-lg border border-white/10 bg-white/[0.08] px-3 py-2">
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-400">
            {icon}
            Link
          </div>
          <p className="mt-1 truncate text-sm font-semibold text-white">{linkLabel}</p>
        </div>
      </div>
    </div>
  )
}

interface TransactionGroup {
  id: string
  label: string
  transactions: PlannerSnapshot['transactions']
  totalPence: number
  isSelected: boolean
  sortDate: string
}

function getSpendingGroupBreakdown(group: TransactionGroup, snapshot: PlannerSnapshot): CalculationBreakdown {
  return {
    formula: 'Period spending total = every manual spending entry in this dropdown.',
    lines:
      group.transactions.length > 0
        ? [
            ...group.transactions.map((transaction) => ({
              label: transaction.note,
              value: formatPence(transaction.amountPence),
              detail: `${transaction.date} · ${getTransactionLinkLabel(transaction, snapshot)}`,
              tone: 'add' as const,
            })),
            {
              label: 'Period spending total',
              value: formatPence(group.totalPence),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No spending entries', value: formatPence(0), tone: 'result' }],
  }
}

function getSpendingMetricBreakdown(
  label: string,
  transactions: PlannerSnapshot['transactions'],
  snapshot: PlannerSnapshot,
): CalculationBreakdown {
  const totalPence = transactions.reduce((sum, transaction) => sum + transaction.amountPence, 0)

  return {
    formula: `${label} = manual spending entries in this view.`,
    lines:
      transactions.length > 0
        ? [
            ...transactions.map((transaction) => ({
              label: transaction.note,
              value: formatPence(transaction.amountPence),
              detail: `${transaction.date} · ${getTransactionLinkLabel(transaction, snapshot)}`,
              tone: 'add' as const,
            })),
            {
              label,
              value: formatPence(totalPence),
              tone: 'result' as const,
            },
          ]
        : [{ label: 'No spending entries', value: formatPence(0), tone: 'result' }],
  }
}

function groupTransactionsByPeriod(
  transactions: PlannerSnapshot['transactions'],
  snapshot: PlannerSnapshot,
  selectedPayPeriod: PayPeriod | null,
): TransactionGroup[] {
  const groups = new Map<string, TransactionGroup>()
  const periodsById = new Map(snapshot.payPeriods.map((period) => [period.id, period]))

  if (selectedPayPeriod) {
    groups.set(selectedPayPeriod.id, {
      id: selectedPayPeriod.id,
      label: `${selectedPayPeriod.payday} pay period · ${selectedPayPeriod.startDate} to ${selectedPayPeriod.endDate}`,
      transactions: [],
      totalPence: 0,
      isSelected: true,
      sortDate: selectedPayPeriod.startDate,
    })
  }

  for (const transaction of transactions) {
    const period =
      (transaction.payPeriodId ? periodsById.get(transaction.payPeriodId) : null) ??
      findPayPeriodForDate(snapshot.payPeriods, transaction.date)
    const id = period?.id ?? 'outside-periods'
    const label = period
      ? `${period.payday} pay period · ${period.startDate} to ${period.endDate}`
      : 'Outside saved pay periods'
    const existingGroup =
      groups.get(id) ??
      {
        id,
        label,
        transactions: [],
        totalPence: 0,
        isSelected: period?.id === selectedPayPeriod?.id,
        sortDate: period?.startDate ?? transaction.date,
      }

    existingGroup.transactions.push(transaction)
    existingGroup.totalPence += transaction.amountPence
    groups.set(id, existingGroup)
  }

  return [...groups.values()]
    .map((group) => ({
      ...group,
      transactions: group.transactions.sort((a, b) => b.date.localeCompare(a.date)),
    }))
    .sort((a, b) => {
      if (a.isSelected !== b.isSelected) {
        return a.isSelected ? -1 : 1
      }

      return b.sortDate.localeCompare(a.sortDate)
    })
}

function formatSpendTotal(amountPence: number): string {
  return amountPence > 0 ? `-${formatPence(amountPence)}` : formatPence(0)
}

function getQuickSpendLinkFields(
  paymentMethod: QuickSpendLinkMethod,
  potId: string,
  creditCardId: string,
  activePots: PlannerSnapshot['pots'],
): Pick<TransactionInput, 'potId' | 'paymentMethod' | 'creditCardId'> {
  if (paymentMethod === 'pot' && potId) {
    const selectedPot = activePots.find((pot) => pot.id === potId)

    if (selectedPot?.linkedCreditCardId) {
      return {
        potId: null,
        paymentMethod: 'credit_card',
        creditCardId: selectedPot.linkedCreditCardId,
      }
    }

    return {
      potId,
      paymentMethod: 'pot',
      creditCardId: null,
    }
  }

  if (paymentMethod === 'credit_card' && creditCardId) {
    return {
      potId: null,
      paymentMethod: 'credit_card',
      creditCardId,
    }
  }

  return {
    potId: null,
    creditCardId: null,
  }
}

function getTransactionLinkMethod(transaction: TransactionInput): QuickSpendLinkMethod {
  if (transaction.paymentMethod === 'credit_card' || transaction.creditCardId) {
    return 'credit_card'
  }

  if (transaction.paymentMethod === 'pot' || transaction.potId) {
    return transaction.potId ? 'pot' : 'unlinked'
  }

  return 'unlinked'
}

function getSelectedSpendLinkLabel(
  paymentMethod: QuickSpendLinkMethod,
  potName?: string,
  cardName?: string,
): string {
  if (paymentMethod === 'pot') {
    return potName ?? 'No pot linked'
  }

  if (paymentMethod === 'credit_card') {
    return cardName ?? 'No credit card linked'
  }

  return 'Unlinked'
}

function getTransactionLinkLabel(transaction: TransactionInput, snapshot: PlannerSnapshot): string {
  if (transaction.paymentMethod === 'credit_card' || transaction.creditCardId) {
    if (!transaction.creditCardId) {
      return 'No credit card linked'
    }

    return snapshot.creditCards.find((candidate) => candidate.id === transaction.creditCardId)?.name ?? 'Archived card'
  }

  if (transaction.potId) {
    return snapshot.pots.find((candidate) => candidate.id === transaction.potId)?.name ?? 'Archived pot'
  }

  if (transaction.paymentMethod === 'pot') {
    return 'No pot linked'
  }

  return 'Unlinked'
}
