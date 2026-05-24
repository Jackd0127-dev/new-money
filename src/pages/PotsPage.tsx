import { useState } from 'react'
import { ChevronDown, PenLine, Trash2, X } from 'lucide-react'

import { formatPence, parsePoundsToPence } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import {
  Button,
  CalculationDetails,
  Field,
  Panel,
  SectionGrid,
  SelectInput,
  TextInput,
  type CalculationBreakdown,
} from '../components/ui'
import type { PotAllocation, PotType, RecurringPayment, Transaction } from '../types/models'

const colors = ['#2563eb', '#16a34a', '#ea580c', '#7c3aed', '#0f766e', '#4338ca', '#475569']
type PotLinkType = 'none' | 'credit_card' | 'debt'

interface PotFormState {
  name: string
  type: PotType
  paycheckAmount: string
  balance: string
  color: string
  linkType: PotLinkType
  linkedEntityId: string
}

const emptyPotForm = (): PotFormState => ({
  name: '',
  type: 'spending',
  paycheckAmount: '',
  balance: '',
  color: colors[0],
  linkType: 'none',
  linkedEntityId: '',
})

export function PotsPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  const [createForm, setCreateForm] = useState<PotFormState>(emptyPotForm)
  const [editForm, setEditForm] = useState<PotFormState | null>(null)
  const [openPotId, setOpenPotId] = useState<string | null>(null)
  const [editingPotId, setEditingPotId] = useState<string | null>(null)
  const activePots = snapshot.pots.filter((pot) => !pot.archived)

  async function submitPot() {
    if (!createForm.name.trim()) {
      return
    }

    await actions.addPot(potFormToPayload(createForm))
    resetCreateForm()
  }

  async function submitEditedPot() {
    if (!editingPotId || !editForm?.name.trim()) {
      return
    }

    await actions.updatePot(editingPotId, potFormToPayload(editForm))
    closeEditModal()
  }

  function startEditingPot(potId: string) {
    const pot = snapshot.pots.find((candidate) => candidate.id === potId)

    if (!pot) {
      return
    }

    setEditingPotId(pot.id)
    setEditForm({
      name: pot.name,
      type: pot.type,
      paycheckAmount: pot.targetPence ? (pot.targetPence / 100).toFixed(2) : '',
      balance: (pot.balancePence / 100).toFixed(2),
      color: pot.color,
      linkType: getPotLinkType(pot),
      linkedEntityId: pot.linkedCreditCardId ?? pot.linkedDebtId ?? '',
    })
  }

  function resetCreateForm() {
    setCreateForm(emptyPotForm())
  }

  function closeEditModal() {
    setEditingPotId(null)
    setEditForm(null)
  }

  return (
    <div className="space-y-6">
      <SectionGrid variant="wideRight">
        <Panel
          title="Create pot"
          description="Add money you already set aside, then linked bills can spend from that pot when due."
          accent="emerald"
          density="compact"
        >
          <div className="space-y-4">
            <PotFormFields form={createForm} snapshot={snapshot} onChange={setCreateForm} />
            <div className="flex flex-wrap gap-3">
              <Button onClick={submitPot}>Add pot</Button>
            </div>
          </div>
        </Panel>

        <Panel
          title="Pots"
          description="Click a pot to see spending, recurring payments, and allocations tied to it."
          accent="blue"
          density="compact"
        >
          <div
            className="grid items-start gap-4 xl:max-h-[760px] xl:overflow-y-auto xl:pr-1"
            style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 220px), 1fr))' }}
          >
          {activePots.map((pot) => {
            const isOpen = openPotId === pot.id
            const activityItems = getPotActivityItems(pot.id, snapshot)
            const linkedRecurringPayments = getPotLinkedRecurringPayments(pot.id, snapshot)
            const linkedTargetLabel = getPotLinkedTargetLabel(pot.id, snapshot)

            return (
              <div key={pot.id} className="rounded-lg border border-slate-200 bg-white p-4">
                <div className="flex items-start justify-between gap-4">
                  <button
                    type="button"
                    onClick={() => setOpenPotId(isOpen ? null : pot.id)}
                    aria-expanded={isOpen}
                    aria-label={`${isOpen ? 'Hide' : 'View'} ${pot.name} activity`}
                    className="min-w-0 flex-1 rounded-md text-left outline-none transition hover:bg-slate-50 focus-visible:ring-4 focus-visible:ring-slate-100"
                  >
                    <div className="grid grid-cols-[auto_1fr_auto] items-start gap-2 p-1">
                      <span className="mt-1 size-3 rounded-full" style={{ backgroundColor: pot.color }} />
                      <div className="min-w-0">
                        <div>
                          <h3 className="break-words text-sm font-semibold leading-5 text-slate-950">{pot.name}</h3>
                        </div>
                        <p className="mt-1 text-xs capitalize text-slate-500">{pot.type}</p>
                        {linkedTargetLabel && (
                          <p className="mt-1 text-xs font-medium text-slate-600">{linkedTargetLabel}</p>
                        )}
                      </div>
                      <ChevronDown
                        size={14}
                        className={`mt-0.5 shrink-0 text-slate-400 transition ${isOpen ? 'rotate-180' : ''}`}
                      />
                    </div>
                    <p className="px-1 pb-1 pt-3 text-2xl font-semibold text-slate-950">{formatPence(pot.balancePence)}</p>
                    {(pot.targetPence ?? 0) > 0 && (
                      <p className="px-1 pb-1 text-sm text-slate-500">
                        Payday top-up {formatPence(pot.targetPence ?? 0)}
                      </p>
                    )}
                  </button>
                  <div className="flex shrink-0 gap-1">
                    <button
                      type="button"
                      className="inline-flex size-6 items-center justify-center rounded-md border border-slate-200 bg-white text-slate-600 transition hover:bg-slate-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400"
                      onClick={() => startEditingPot(pot.id)}
                      aria-label={`Edit ${pot.name}`}
                      title={`Edit ${pot.name}`}
                    >
                      <PenLine size={12} />
                    </button>
                    <button
                      type="button"
                      className="inline-flex size-6 items-center justify-center rounded-md bg-red-600 text-white transition hover:bg-red-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600"
                      onClick={() => {
                        if (window.confirm(`Delete ${pot.name}?`)) {
                          void actions.deletePot(pot.id)
                        }
                      }}
                      aria-label={`Delete ${pot.name}`}
                      title={`Delete ${pot.name}`}
                    >
                      <Trash2 size={12} />
                    </button>
                  </div>
                </div>

                {isOpen && (
                  <div role="region" aria-label={`${pot.name} activity`} className="mt-4 border-t border-slate-100 pt-4">
                    <CalculationDetails breakdown={getPotBalanceBreakdown(pot.id, pot.balancePence, activityItems)} />
                    {activityItems.length > 0 ? (
                      <div className="mt-3 space-y-2">
                        {activityItems.map((item) => (
                          <div
                            key={item.id}
                            className="grid grid-cols-[1fr_auto] items-center gap-3 rounded-lg bg-slate-50 px-3 py-2"
                          >
                            <div className="min-w-0">
                              <p className="truncate text-sm font-semibold text-slate-950">{item.title}</p>
                              <p className="mt-1 text-xs text-slate-500">{item.detail}</p>
                            </div>
                            <p
                              className={`text-sm font-semibold ${
                                item.amountPence < 0 ? 'text-red-700' : 'text-emerald-700'
                              }`}
                            >
                              {formatSignedPence(item.amountPence)}
                            </p>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="rounded-lg bg-slate-50 p-3 text-sm text-slate-500">
                        No activity recorded for this pot yet.
                      </p>
                    )}
                    {linkedRecurringPayments.length > 0 && (
                      <div className="mt-4 rounded-lg border border-slate-200 bg-white">
                        <div className="border-b border-slate-100 px-3 py-2">
                          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Linked recurring payments</p>
                        </div>
                        <div className="divide-y divide-slate-100">
                          {linkedRecurringPayments.map((payment) => (
                            <div key={payment.id} className="grid grid-cols-[1fr_auto] gap-3 px-3 py-2">
                              <div className="min-w-0">
                                <p className="truncate text-sm font-semibold text-slate-950">{payment.name}</p>
                                <p className="mt-1 text-xs text-slate-500">
                                  {payment.frequency} · due day {payment.dueDay ?? 'set date'}
                                </p>
                              </div>
                              <p className="text-sm font-semibold text-slate-950">{formatPence(payment.amountPence)}</p>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            )
          })}
          {activePots.length === 0 && (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500 md:col-span-2 xl:col-span-3">
              No pots yet.
            </p>
          )}
          </div>
        </Panel>
      </SectionGrid>
      {editingPotId && editForm && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/45 p-4">
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Edit pot"
            className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-lg border border-slate-200 bg-white p-5 shadow-xl"
          >
            <div className="mb-4 flex items-start justify-between gap-4 border-b border-slate-100 pb-4">
              <div>
                <h2 className="text-base font-semibold text-slate-950">Edit pot</h2>
                <p className="mt-1 text-sm text-slate-500">Update this pot without replacing the create form.</p>
              </div>
              <Button variant="ghost" onClick={closeEditModal} aria-label="Close edit pot">
                <X size={18} />
              </Button>
            </div>
            <div className="space-y-4">
              <PotFormFields form={editForm} snapshot={snapshot} onChange={setEditForm} />
              <div className="flex flex-wrap gap-3">
                <Button onClick={submitEditedPot}>Save pot</Button>
                <Button variant="secondary" onClick={closeEditModal}>
                  Cancel
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function PotFormFields({
  form,
  snapshot,
  onChange,
}: {
  form: PotFormState
  snapshot: PlannerSnapshot
  onChange: (form: PotFormState) => void
}) {
  const creditCards = snapshot.creditCards.filter(
    (card) => !card.archived || card.id === form.linkedEntityId,
  )
  const debts = snapshot.debts.filter(
    (debt) => debt.status !== 'archived' || debt.id === form.linkedEntityId,
  )

  return (
    <>
      <Field label="Pot name">
        <TextInput
          value={form.name}
          onChange={(event) => onChange({ ...form, name: event.target.value })}
          placeholder="Car insurance"
        />
      </Field>
      <Field label="Type">
        <SelectInput value={form.type} onChange={(event) => onChange({ ...form, type: event.target.value as PotType })}>
          <option value="spending">Spending</option>
          <option value="reserved">Reserved</option>
          <option value="saving">Saving</option>
          <option value="investment">Investment</option>
          <option value="buffer">Buffer</option>
        </SelectInput>
      </Field>
      <Field label="Add each paycheck" hint="This amount is automatically deducted from every confirmed paycheck and added to this pot.">
        <TextInput
          inputMode="decimal"
          value={form.paycheckAmount}
          onChange={(event) => onChange({ ...form, paycheckAmount: event.target.value })}
          placeholder="50.00"
        />
      </Field>
      <Field label="Current balance" hint="Money already set aside in this pot before you started using the app.">
        <TextInput
          inputMode="decimal"
          value={form.balance}
          onChange={(event) => onChange({ ...form, balance: event.target.value })}
          placeholder="0.00"
        />
      </Field>
      <Field label="Link this pot to">
        <SelectInput
          value={form.linkType}
          onChange={(event) =>
            onChange({
              ...form,
              linkType: event.target.value as PotLinkType,
              linkedEntityId: '',
            })
          }
        >
          <option value="none">No link</option>
          <option value="credit_card">Credit card</option>
          <option value="debt">Debt</option>
        </SelectInput>
      </Field>
      {form.linkType === 'credit_card' && (
        <Field label="Credit card">
          <SelectInput
            value={form.linkedEntityId}
            onChange={(event) => onChange({ ...form, linkedEntityId: event.target.value })}
          >
            <option value="">Choose credit card</option>
            {creditCards.map((card) => (
              <option key={card.id} value={card.id}>
                {card.name}
              </option>
            ))}
          </SelectInput>
        </Field>
      )}
      {form.linkType === 'debt' && (
        <Field label="Debt">
          <SelectInput
            value={form.linkedEntityId}
            onChange={(event) => onChange({ ...form, linkedEntityId: event.target.value })}
          >
            <option value="">Choose debt</option>
            {debts.map((debt) => (
              <option key={debt.id} value={debt.id}>
                {debt.name}
              </option>
            ))}
          </SelectInput>
        </Field>
      )}
      <Field label="Colour">
        <div className="flex flex-wrap gap-2">
          {colors.map((option) => (
            <button
              key={option}
              type="button"
              aria-label={`Use colour ${option}`}
              onClick={() => onChange({ ...form, color: option })}
              className="size-8 rounded-full border-2"
              style={{
                backgroundColor: option,
                borderColor: option === form.color ? '#0f172a' : 'white',
                boxShadow: option === form.color ? '0 0 0 2px #cbd5e1' : '0 0 0 1px #e2e8f0',
              }}
            />
          ))}
        </div>
      </Field>
    </>
  )
}

function potFormToPayload(form: PotFormState) {
  return {
    name: form.name.trim(),
    type: form.type,
    balancePence: form.balance ? parsePoundsToPence(form.balance) : 0,
    targetPence: form.paycheckAmount ? parsePoundsToPence(form.paycheckAmount) : null,
    color: form.color,
    linkedCreditCardId: form.linkType === 'credit_card' ? form.linkedEntityId || null : null,
    linkedDebtId: form.linkType === 'debt' ? form.linkedEntityId || null : null,
  }
}

function getPotLinkType(pot: PlannerSnapshot['pots'][number]): PotLinkType {
  if (pot.linkedCreditCardId) {
    return 'credit_card'
  }

  if (pot.linkedDebtId) {
    return 'debt'
  }

  return 'none'
}

function getPotLinkedTargetLabel(potId: string, snapshot: PlannerSnapshot): string | null {
  const pot = snapshot.pots.find((candidate) => candidate.id === potId)

  if (!pot) {
    return null
  }

  if (pot.linkedCreditCardId) {
    const card = snapshot.creditCards.find((candidate) => candidate.id === pot.linkedCreditCardId)
    return `Linked to ${card?.name ?? 'deleted credit card'}`
  }

  if (pot.linkedDebtId) {
    const debt = snapshot.debts.find((candidate) => candidate.id === pot.linkedDebtId)
    return `Linked to ${debt?.name ?? 'deleted debt'}`
  }

  return null
}

interface PotActivityItem {
  id: string
  title: string
  detail: string
  amountPence: number
}

function getPotBalanceBreakdown(
  potId: string,
  balancePence: number,
  activityItems: PotActivityItem[],
): CalculationBreakdown {
  const activityNetPence = activityItems.reduce((total, item) => total + item.amountPence, 0)
  const startingOrImportedPence = balancePence - activityNetPence

  return {
    formula: 'Pot balance = starting/imported balance + recorded activity shown below.',
    lines: [
      {
        label: 'Starting or imported balance',
        value: formatPence(startingOrImportedPence),
        detail: `Balance not represented by the visible activity for this pot (${potId}).`,
        tone: startingOrImportedPence >= 0 ? 'add' : 'subtract',
      },
      ...activityItems.map((item) => ({
        label: item.title,
        value: formatSignedPence(item.amountPence),
        detail: item.detail,
        tone: item.amountPence >= 0 ? ('add' as const) : ('subtract' as const),
      })),
      {
        label: 'Current pot balance',
        value: formatPence(balancePence),
        tone: 'result',
      },
    ],
    note: 'This explains the displayed balance using the pot record plus the activity currently stored for it.',
  }
}

function getPotActivityItems(potId: string, snapshot: PlannerSnapshot): PotActivityItem[] {
  const transactions = snapshot.transactions
    .filter((transaction) => transaction.potId === potId)
    .map((transaction) => transactionToActivityItem(transaction))
  const allocations = snapshot.potAllocations
    .filter((allocation) => allocation.potId === potId)
    .map((allocation) => allocationToActivityItem(allocation, snapshot))

  return [...transactions, ...allocations]
}

function getPotLinkedRecurringPayments(potId: string, snapshot: PlannerSnapshot): RecurringPayment[] {
  return snapshot.recurringPayments
    .filter((payment) => payment.active && payment.potId === potId)
    .sort((a, b) => a.name.localeCompare(b.name))
}

function transactionToActivityItem(transaction: Transaction): PotActivityItem {
  const isSpending = transaction.type === 'spending'

  return {
    id: `transaction-${transaction.id}`,
    title: transaction.note,
    detail: `${transaction.recurringPaymentId ? 'Recurring payment' : formatTransactionType(transaction.type)} · ${transaction.date}`,
    amountPence: isSpending ? -transaction.amountPence : transaction.amountPence,
  }
}

function allocationToActivityItem(allocation: PotAllocation, snapshot: PlannerSnapshot): PotActivityItem {
  const period = snapshot.payPeriods.find((candidate) => candidate.id === allocation.payPeriodId)
  const payment = allocation.recurringPaymentId
    ? snapshot.recurringPayments.find((candidate) => candidate.id === allocation.recurringPaymentId)
    : null

  return {
    id: `allocation-${allocation.id}`,
    title: payment
      ? `Reserved for ${payment.name}`
      : allocation.source === 'pot_auto'
        ? 'Automatic payday top-up'
        : 'Paycheck allocation',
    detail: `Allocation · ${period?.payday ?? allocation.createdAt.slice(0, 10)}`,
    amountPence: allocation.amountPence,
  }
}

function formatTransactionType(type: Transaction['type']): string {
  if (type === 'spending') {
    return 'Spending'
  }

  return type.charAt(0).toUpperCase() + type.slice(1)
}

function formatSignedPence(amountPence: number): string {
  if (amountPence > 0) {
    return `+${formatPence(amountPence)}`
  }

  return formatPence(amountPence)
}
