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

interface PotFormState {
  name: string
  type: PotType
  paycheckAmount: string
  balance: string
  color: string
}

const emptyPotForm = (): PotFormState => ({
  name: '',
  type: 'spending',
  paycheckAmount: '',
  balance: '',
  color: colors[0],
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
          description="Pots carry balances forward until you spend or move the money."
          accent="emerald"
          density="compact"
        >
          <div className="space-y-4">
            <PotFormFields form={createForm} onChange={setCreateForm} />
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
          <div className="grid items-start gap-4 md:grid-cols-2 xl:max-h-[760px] xl:grid-cols-3 xl:overflow-y-auto xl:pr-1">
          {activePots.map((pot) => {
            const isOpen = openPotId === pot.id
            const activityItems = getPotActivityItems(pot.id, snapshot)

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
                    <div className="flex items-start justify-between gap-3 p-1">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="size-3 rounded-full" style={{ backgroundColor: pot.color }} />
                          <h3 className="truncate text-sm font-semibold text-slate-950">{pot.name}</h3>
                        </div>
                        <p className="mt-1 text-xs capitalize text-slate-500">{pot.type}</p>
                      </div>
                      <ChevronDown
                        size={18}
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
                  <div className="flex shrink-0 gap-2">
                    <Button
                      variant="secondary"
                      onClick={() => startEditingPot(pot.id)}
                      aria-label={`Edit ${pot.name}`}
                    >
                      <PenLine size={16} />
                    </Button>
                    <Button
                      variant="danger"
                      onClick={() => {
                        if (window.confirm(`Delete ${pot.name}?`)) {
                          void actions.deletePot(pot.id)
                        }
                      }}
                      aria-label={`Delete ${pot.name}`}
                    >
                      <Trash2 size={16} />
                    </Button>
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
              <PotFormFields form={editForm} onChange={setEditForm} />
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
  onChange,
}: {
  form: PotFormState
  onChange: (form: PotFormState) => void
}) {
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
      <Field label="Current balance" hint="Money already inside this pot before the next paycheck top-up.">
        <TextInput
          inputMode="decimal"
          value={form.balance}
          onChange={(event) => onChange({ ...form, balance: event.target.value })}
          placeholder="0.00"
        />
      </Field>
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
  }
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
  const recurringPayments = snapshot.recurringPayments
    .filter((payment) => payment.potId === potId)
    .map((payment) => recurringPaymentToActivityItem(payment))

  return [...transactions, ...allocations, ...recurringPayments]
}

function transactionToActivityItem(transaction: Transaction): PotActivityItem {
  const isSpending = transaction.type === 'spending'

  return {
    id: `transaction-${transaction.id}`,
    title: transaction.note,
    detail: `${formatTransactionType(transaction.type)} · ${transaction.date}`,
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

function recurringPaymentToActivityItem(payment: RecurringPayment): PotActivityItem {
  return {
    id: `recurring-${payment.id}`,
    title: payment.name,
    detail: `Recurring · ${payment.frequency} · day ${payment.dueDay ?? 'set date'}`,
    amountPence: -payment.amountPence,
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
