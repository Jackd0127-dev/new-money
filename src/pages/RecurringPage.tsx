import { useState } from 'react'
import { PauseCircle, PenLine, PlayCircle, Trash2, X } from 'lucide-react'

import {
  createNextPayPeriod,
  formatPence,
  getPayPeriodCostSummary,
  parsePoundsToPence,
  type PayPeriodCostSummary,
} from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import {
  Button,
  Field,
  MoneyMetric,
  Panel,
  SectionGrid,
  SelectInput,
  TextInput,
  type CalculationBreakdown,
} from '../components/ui'
import type { PayFrequency, PayPeriod, PotAllocation, RecurringFrequency, RecurringPriority } from '../types/models'

interface RecurringFormState {
  name: string
  amount: string
  dueDay: string
  frequency: RecurringFrequency
  priority: RecurringPriority
  potId: string
  creditCardId: string
}

export function RecurringPage({
  snapshot,
  actions,
  selectedPayPeriod,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
  selectedPayPeriod?: PayPeriod | null
}) {
  const activePots = snapshot.pots.filter((pot) => !pot.archived)
  const activeCards = snapshot.creditCards.filter((card) => !card.archived)
  const [createForm, setCreateForm] = useState<RecurringFormState>(() =>
    createEmptyRecurringForm(activePots[0]?.id ?? ''),
  )
  const [editingPaymentId, setEditingPaymentId] = useState<string | null>(null)
  const [editForm, setEditForm] = useState<RecurringFormState | null>(null)
  const viewedPeriod = selectedPayPeriod ?? null
  const nextPaydayPeriod = viewedPeriod
    ? getNextPaydayPeriod(viewedPeriod, viewedPeriod.payFrequency ?? snapshot.settings.payFrequency)
    : null
  const nextPaydaySummary = getPayPeriodCostSummary({
    payPeriod: nextPaydayPeriod,
    recurringPayments: snapshot.recurringPayments,
    customPayments: snapshot.customPayments,
    transactions: snapshot.transactions,
    debts: snapshot.debts,
    creditCardRepayments: snapshot.creditCardRepayments,
    creditCardPots: snapshot.creditCardPots,
    debtReserves: snapshot.debtReserves,
    pots: snapshot.pots,
    potAllocations: [
      ...snapshot.potAllocations,
      ...(nextPaydayPeriod ? getPreviewPotTopUps(snapshot, nextPaydayPeriod) : []),
    ],
  })

  async function submitPayment(form: RecurringFormState, mode: 'create' | 'edit') {
    const amountPence = parsePoundsToPence(form.amount)
    const dueDayNumber = Number.parseInt(form.dueDay, 10)

    if (!form.name.trim() || amountPence <= 0 || dueDayNumber < 1 || dueDayNumber > 31) {
      return
    }

    if (mode === 'edit' && editingPaymentId) {
      const currentPayment = snapshot.recurringPayments.find((candidate) => candidate.id === editingPaymentId)
      const updateInput = {
        name: form.name.trim(),
        amountPence,
        dueDay: dueDayNumber,
        frequency: form.frequency,
        potId: form.potId || null,
        priority: form.priority,
        ...(form.creditCardId || currentPayment?.creditCardId
          ? {
              creditCardId: form.creditCardId || null,
            }
          : {}),
      }

      await actions.updateRecurringPayment(editingPaymentId, updateInput)
      closeEditModal()
      return
    }

    const addInput = {
      name: form.name.trim(),
      amountPence,
      dueDay: dueDayNumber,
      frequency: form.frequency,
      potId: form.potId || null,
      priority: form.priority,
      ...(form.creditCardId
        ? {
            creditCardId: form.creditCardId,
          }
        : {}),
    }

    await actions.addRecurringPayment(addInput)
    resetCreateForm()
  }

  function startEditingPayment(paymentId: string) {
    const payment = snapshot.recurringPayments.find((candidate) => candidate.id === paymentId)

    if (!payment) {
      return
    }

    setEditingPaymentId(payment.id)
    setEditForm({
      name: payment.name,
      amount: (payment.amountPence / 100).toFixed(2),
      dueDay: String(payment.dueDay ?? 1),
      frequency: payment.frequency,
      priority: payment.priority,
      potId: payment.potId ?? '',
      creditCardId: payment.creditCardId ?? '',
    })
  }

  function resetCreateForm() {
    setCreateForm(createEmptyRecurringForm(activePots[0]?.id ?? ''))
  }

  function closeEditModal() {
    setEditingPaymentId(null)
    setEditForm(null)
  }

  return (
    <div className="space-y-6">
      <SectionGrid variant="wideRight">
        <Panel
          title="Add recurring payment"
          description="Bills use the linked pot balance on their due date."
          accent="violet"
          density="compact"
        >
          <div className="space-y-4">
            <RecurringPaymentFormFields
              form={createForm}
              activePots={activePots}
              activeCards={activeCards}
              onChange={setCreateForm}
            />
            <div className="flex flex-wrap gap-3">
              <Button onClick={() => void submitPayment(createForm, 'create')}>Add recurring payment</Button>
            </div>
          </div>
        </Panel>

        <Panel
          title="Recurring payments"
          description="Inactive payments are ignored by payday planning."
          accent="blue"
          density="compact"
        >
        <div className="space-y-3 xl:max-h-[680px] xl:overflow-y-auto xl:pr-1">
          {snapshot.recurringPayments.length > 0 ? (
            snapshot.recurringPayments.map((payment) => {
              const pot = snapshot.pots.find((candidate) => candidate.id === payment.potId)
              const card = snapshot.creditCards.find((candidate) => candidate.id === payment.creditCardId)

              return (
                <div key={payment.id} className="flex flex-col gap-3 rounded-lg border border-slate-200 bg-white p-4 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className={payment.active ? 'size-2 rounded-full bg-emerald-500' : 'size-2 rounded-full bg-slate-300'} />
                      <h3 className="text-sm font-semibold text-slate-950">{payment.name}</h3>
                    </div>
                    <p className="mt-1 text-xs text-slate-500">
                      Due day {payment.dueDay} · {payment.frequency} · {payment.potId ? `paid from ${pot?.name ?? 'Archived pot'}` : 'no pot linked'}
                      {card ? ` · ${card.name}` : ''}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <p className="text-sm font-semibold text-slate-950">{formatPence(payment.amountPence)}</p>
                    <button
                      type="button"
                      onClick={() => actions.toggleRecurringPayment(payment)}
                      aria-label={`${payment.active ? 'Pause' : 'Resume'} ${payment.name}`}
                      title={`${payment.active ? 'Pause' : 'Resume'} ${payment.name}`}
                      className="inline-flex size-8 items-center justify-center rounded-md border border-slate-200 bg-white text-slate-600 transition hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400"
                    >
                      {payment.active ? <PauseCircle size={16} /> : <PlayCircle size={16} />}
                    </button>
                    <button
                      type="button"
                      onClick={() => startEditingPayment(payment.id)}
                      aria-label={`Edit ${payment.name}`}
                      title={`Edit ${payment.name}`}
                      className="inline-flex size-8 items-center justify-center rounded-md border border-slate-200 bg-white text-slate-600 transition hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400"
                    >
                      <PenLine size={15} />
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        if (window.confirm(`Delete ${payment.name}?`)) {
                          void actions.deleteRecurringPayment(payment.id)
                        }
                      }}
                      aria-label={`Delete ${payment.name}`}
                      title={`Delete ${payment.name}`}
                      className="inline-flex size-8 items-center justify-center rounded-md bg-red-600 text-white transition hover:bg-red-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>
              )
            })
          ) : (
            <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">No recurring payments yet.</p>
          )}
        </div>
        </Panel>
      </SectionGrid>

      <NextPaydayOwedPanel period={nextPaydayPeriod} summary={nextPaydaySummary} />

      {editingPaymentId && editForm && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/45 p-4">
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Edit recurring payment"
            className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-lg border border-slate-200 bg-white p-5 shadow-xl"
          >
            <div className="mb-4 flex items-start justify-between gap-4 border-b border-slate-100 pb-4">
              <div>
                <h2 className="text-base font-semibold text-slate-950">Edit recurring payment</h2>
                <p className="mt-1 text-sm text-slate-500">Update this bill without changing the add-payment form.</p>
              </div>
              <Button variant="ghost" onClick={closeEditModal} aria-label="Close edit recurring payment">
                <X size={18} />
              </Button>
            </div>
            <div className="space-y-4">
              <RecurringPaymentFormFields
                form={editForm}
                activePots={activePots}
                activeCards={activeCards}
                onChange={setEditForm}
              />
              <div className="flex flex-wrap gap-3">
                <Button onClick={() => void submitPayment(editForm, 'edit')}>Save recurring payment</Button>
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

function createEmptyRecurringForm(defaultPotId: string): RecurringFormState {
  return {
    name: '',
    amount: '',
    dueDay: '1',
    frequency: 'monthly',
    priority: 'essential',
    potId: defaultPotId,
    creditCardId: '',
  }
}

function RecurringPaymentFormFields({
  form,
  activePots,
  activeCards,
  onChange,
}: {
  form: RecurringFormState
  activePots: PlannerSnapshot['pots']
  activeCards: PlannerSnapshot['creditCards']
  onChange: (form: RecurringFormState) => void
}) {
  return (
    <>
      <Field label="Name">
        <TextInput
          value={form.name}
          onChange={(event) => onChange({ ...form, name: event.target.value })}
          placeholder="Phone bill"
        />
      </Field>
      <Field label="Amount">
        <TextInput
          inputMode="decimal"
          value={form.amount}
          onChange={(event) => onChange({ ...form, amount: event.target.value })}
          placeholder="22.00"
        />
      </Field>
      <div className="grid gap-4 md:grid-cols-2">
        <Field label="Due day">
          <TextInput
            inputMode="numeric"
            value={form.dueDay}
            onChange={(event) => onChange({ ...form, dueDay: event.target.value })}
          />
        </Field>
        <Field label="Frequency">
          <SelectInput
            value={form.frequency}
            onChange={(event) => onChange({ ...form, frequency: event.target.value as RecurringFrequency })}
          >
            <option value="weekly">Weekly</option>
            <option value="biweekly">Biweekly</option>
            <option value="monthly">Monthly</option>
            <option value="yearly">Yearly</option>
          </SelectInput>
        </Field>
      </div>
      <Field label="Paid from pot">
        <SelectInput value={form.potId} onChange={(event) => onChange({ ...form, potId: event.target.value })}>
          <option value="">No pot</option>
          {activePots.map((pot) => (
            <option key={pot.id} value={pot.id}>
              {pot.name}
            </option>
          ))}
        </SelectInput>
      </Field>
      <Field label="Paid on credit card">
        <SelectInput
          value={form.creditCardId}
          onChange={(event) => onChange({ ...form, creditCardId: event.target.value })}
        >
          <option value="">Unlinked</option>
          {activeCards.map((card) => (
            <option key={card.id} value={card.id}>
              {card.name} ({card.provider})
            </option>
          ))}
        </SelectInput>
      </Field>
      <Field label="Priority">
        <SelectInput
          value={form.priority}
          onChange={(event) => onChange({ ...form, priority: event.target.value as RecurringPriority })}
        >
          <option value="essential">Essential</option>
          <option value="important">Important</option>
          <option value="optional">Optional</option>
        </SelectInput>
      </Field>
    </>
  )
}

function NextPaydayOwedPanel({
  period,
  summary,
}: {
  period: PayPeriod | null
  summary: PayPeriodCostSummary
}) {
  return (
    <Panel
      title="What you owe next payday"
      accent="amber"
      density="compact"
      description={
        period
          ? `${period.startDate} to ${period.endDate}`
          : 'Create a paycheck plan to preview the next payday period.'
      }
    >
      {period ? (
        <div className="space-y-4">
          <div className="grid gap-4 lg:grid-cols-[1.1fr_0.9fr_0.9fr]">
            <MoneyMetric
              label="Total owed next payday"
              value={formatPence(summary.totalCostsPence)}
              tone={summary.totalCostsPence > 0 ? 'warning' : 'neutral'}
              breakdown={getNextPaydayOwedBreakdown(summary, period)}
            />
            <MoneyMetric
              label="Debt due"
              value={formatPence(summary.debtMinimumsPence)}
              tone={summary.debtMinimumsPence > 0 ? 'warning' : 'neutral'}
              breakdown={{
                formula: 'Debt due = outstanding balances due by the end of this next pay period after planned reserves.',
                lines: [
                  {
                    label: 'Debt due',
                    value: formatPence(summary.debtMinimumsPence),
                    detail: `Due by ${period.endDate}, after accepted debt reserves are subtracted.`,
                    tone: 'result',
                  },
                ],
              }}
            />
            <MoneyMetric
              label="Money left estimate"
              value={formatPence(summary.moneyLeftPence)}
              tone={summary.moneyLeftPence < 0 ? 'bad' : 'good'}
              breakdown={{
                formula: 'Money left estimate = last saved pay - next payday costs.',
                lines: [
                  { label: 'Last saved pay', value: formatPence(summary.payReceivedPence), tone: 'add' },
                  { label: 'Next payday costs', value: `-${formatPence(summary.totalCostsPence)}`, tone: 'subtract' },
                  { label: 'Money left estimate', value: formatPence(summary.moneyLeftPence), tone: 'result' },
                ],
                note: 'This preview uses the last paycheck amount until you save the next payday plan.',
              }}
            />
          </div>

          <details className="rounded-lg border border-slate-200 bg-slate-50">
            <summary className="cursor-pointer list-none px-4 py-3">
              <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
                <p className="text-sm font-semibold text-slate-950">Dated items in this preview</p>
                <p className="text-xs font-semibold text-slate-500">{summary.items.length} items</p>
              </div>
            </summary>
            <div className="space-y-2 border-t border-slate-200 p-3">
              {summary.items.length > 0 ? (
                summary.items.map((item) => (
                  <div
                    key={item.id}
                    className="grid gap-2 rounded-md bg-white px-3 py-2 text-sm sm:grid-cols-[1fr_auto]"
                  >
                    <div>
                      <p className="font-medium text-slate-800">{item.label}</p>
                      <p className="mt-0.5 text-xs text-slate-500">
                        {item.date} · {formatCostSource(item.source)}
                      </p>
                    </div>
                    <p className={item.amountPence < 0 ? 'font-semibold text-emerald-700' : 'font-semibold text-slate-950'}>
                      {item.amountPence < 0 ? '-' : ''}
                      {formatPence(Math.abs(item.amountPence))}
                    </p>
                  </div>
                ))
              ) : (
                <p className="rounded-md bg-white px-3 py-2 text-sm text-slate-500">
                  Nothing is dated inside the next payday period yet.
                </p>
              )}
            </div>
          </details>
        </div>
      ) : (
        <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500">
          No payday plan is available to build a next-period preview.
        </p>
      )}
    </Panel>
  )
}

function getNextPaydayOwedBreakdown(
  summary: PayPeriodCostSummary,
  period: PayPeriod,
): CalculationBreakdown {
  return {
    formula: 'Total owed next payday = recurring + saved payments + manual spending + pot top-ups + debt reserves + debt due + credit pots + credit-card net.',
    lines: [
      {
        label: 'Recurring not on cards',
        value: formatPence(summary.directRecurringPence),
        detail: `Due from ${period.startDate} to ${period.endDate}.`,
        tone: 'add',
      },
      {
        label: 'Saved payments not on cards',
        value: formatPence(summary.savedPaymentsPence),
        detail: 'One-off saved payments due in this next pay period.',
        tone: 'add',
      },
      {
        label: 'Manual spending not on cards',
        value: formatPence(summary.manualSpendingPence),
        detail: 'Manual spending already dated inside this next pay period.',
        tone: 'add',
      },
      {
        label: 'Pot payday top-ups',
        value: formatPence(summary.potAllocationsPence),
        detail: 'Automatic pot money already planned for this next period.',
        tone: 'add',
      },
      {
        label: 'Debt reserves',
        value: formatPence(summary.debtReservesPence),
        detail: 'Accepted set-asides already planned for this next period.',
        tone: 'add',
      },
      {
        label: 'Debt due',
        value: formatPence(summary.debtMinimumsPence),
        detail: 'Remaining outstanding balances overdue or due by this next period end.',
        tone: 'add',
      },
      {
        label: 'Credit card pots',
        value: formatPence(summary.creditCardPotsPence),
        detail: 'Paycheck-funded credit pots planned inside this next pay period.',
        tone: 'add',
      },
      {
        label: 'Credit-card charges',
        value: formatPence(summary.creditCardChargesPence),
        detail: 'Recurring, saved, and manual spends linked to cards.',
        tone: 'add',
      },
      {
        label: 'Card repayments',
        value: `-${formatPence(summary.creditCardRepaymentsPence)}`,
        detail: 'Repayments dated inside this next pay period.',
        tone: 'subtract',
      },
      {
        label: 'Credit-card net used',
        value: formatPence(summary.creditCardNetPence),
        detail: 'Card charges minus repayments, never below zero.',
        tone: 'result',
      },
      {
        label: 'Total owed next payday',
        value: formatPence(summary.totalCostsPence),
        tone: 'result',
      },
    ],
    note: `${summary.items.length} dated items feed this next-payday preview.`,
  }
}

function getNextPaydayPeriod(currentPeriod: PayPeriod, frequency: PayFrequency): PayPeriod {
  const nextDates = createNextPayPeriod(currentPeriod.nextPayday, frequency)

  return {
    id: 'next-payday-preview',
    startDate: nextDates.startDate,
    endDate: nextDates.endDate,
    payday: currentPeriod.nextPayday,
    nextPayday: nextDates.nextPayday,
    payFrequency: frequency,
    incomePence: currentPeriod.incomePence,
    status: 'planned',
    createdAt: currentPeriod.updatedAt,
    updatedAt: currentPeriod.updatedAt,
  }
}

function getPreviewPotTopUps(snapshot: PlannerSnapshot, period: PayPeriod): PotAllocation[] {
  const existingAutoPotIds = new Set(
    snapshot.potAllocations
      .filter((allocation) => allocation.payPeriodId === period.id && allocation.source === 'pot_auto')
      .map((allocation) => allocation.potId),
  )

  return snapshot.pots
    .filter((pot) => !pot.archived && (pot.targetPence ?? 0) > 0 && !existingAutoPotIds.has(pot.id))
    .map((pot) => ({
      id: `preview-pot-${period.id}-${pot.id}`,
      payPeriodId: period.id,
      potId: pot.id,
      amountPence: pot.targetPence ?? 0,
      source: 'pot_auto' as const,
      recurringPaymentId: null,
      createdAt: period.createdAt,
      updatedAt: period.updatedAt,
    }))
}

function formatCostSource(source: PayPeriodCostSummary['items'][number]['source']): string {
  if (source === 'recurring') {
    return 'Recurring'
  }

  if (source === 'saved_payment') {
    return 'Saved payment'
  }

  if (source === 'manual_spend') {
    return 'Manual spend'
  }

  if (source === 'pot_allocation') {
    return 'Pot top-up'
  }

  if (source === 'debt_minimum') {
    return 'Debt due'
  }

  if (source === 'debt_reserve') {
    return 'Debt reserve'
  }

  if (source === 'credit_card_pot') {
    return 'Credit pot'
  }

  return 'Card repayment'
}
