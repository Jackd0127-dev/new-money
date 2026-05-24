import { useState } from 'react'

import {
  filterPayPeriodCostSummary,
  formatPence,
  getPayPeriodCostSummary,
  type PeriodCostItem,
  type PayPeriodCostSummary,
} from '../domain/money'
import type { PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, MoneyMetric, Panel, SelectInput, type CalculationBreakdown } from '../components/ui'
import type { PayPeriod } from '../types/models'
import type { ViewKey } from '../types/navigation'

const dashboardTodoStorageKey = 'new-money.dashboard-todos.v1'
const dashboardIgnoredPaymentsStorageKey = 'new-money.dashboard-ignored-payments.v1'

interface PaycheckTodoItem {
  id: string
  ignoreId: string
  ignoreLabel: string
  label: string
  detail: string
  amountPence: number
}

export function DashboardPage({
  snapshot,
  selectedPayPeriod,
  onPayPeriodChange,
  onViewChange,
}: {
  snapshot: PlannerSnapshot
  selectedPayPeriod?: PayPeriod | null
  onPayPeriodChange?: (payPeriodId: string | null) => void
  onViewChange: (view: ViewKey) => void
}) {
  const [openMetric, setOpenMetric] = useState<string | null>(null)
  const [completedTodosByPeriod, setCompletedTodosByPeriod] = useState<Record<string, string[]>>(
    () => readCompletedTodos(),
  )
  const [ignoredPaymentsByPeriod, setIgnoredPaymentsByPeriod] = useState<Record<string, string[]>>(
    () => readIgnoredPayments(),
  )
  const viewedPeriod = selectedPayPeriod ?? null
  const baseSummary = getPayPeriodCostSummary({
    payPeriod: viewedPeriod,
    creditCards: snapshot.creditCards,
    recurringPayments: snapshot.recurringPayments,
    customPayments: snapshot.customPayments,
    transactions: snapshot.transactions,
    debts: snapshot.debts,
    creditCardRepayments: snapshot.creditCardRepayments,
    creditCardPots: snapshot.creditCardPots,
    debtReserves: snapshot.debtReserves,
    pots: snapshot.pots,
    potAllocations: snapshot.potAllocations,
  })
  const ignoredPaymentIds = new Set(viewedPeriod ? ignoredPaymentsByPeriod[viewedPeriod.id] ?? [] : [])
  const summary = filterPayPeriodCostSummary(baseSummary, ignoredPaymentIds)
  const todoItems = viewedPeriod ? getPaycheckTodoItems(snapshot, viewedPeriod, baseSummary) : []
  const completedTodoIds = new Set(viewedPeriod ? completedTodosByPeriod[viewedPeriod.id] ?? [] : [])
  const activeTodoItems = todoItems.filter((item) => !ignoredPaymentIds.has(item.ignoreId))
  const completedTodoCount = activeTodoItems.filter((item) => completedTodoIds.has(item.id)).length
  const ignoredTodoCount = todoItems.length - activeTodoItems.length

  function toggleTodo(itemId: string, done: boolean) {
    if (!viewedPeriod) {
      return
    }

    setCompletedTodosByPeriod((current) => {
      const currentIds = new Set(current[viewedPeriod.id] ?? [])

      if (done) {
        currentIds.add(itemId)
      } else {
        currentIds.delete(itemId)
      }

      const next = {
        ...current,
        [viewedPeriod.id]: [...currentIds],
      }

      writeCompletedTodos(next)
      return next
    })
  }

  function toggleIgnoredPayment(item: PaycheckTodoItem, ignored: boolean) {
    if (!viewedPeriod) {
      return
    }

    setIgnoredPaymentsByPeriod((current) => {
      const currentIds = new Set(current[viewedPeriod.id] ?? [])

      if (ignored) {
        currentIds.add(item.ignoreId)
      } else {
        currentIds.delete(item.ignoreId)
      }

      const next = {
        ...current,
        [viewedPeriod.id]: [...currentIds],
      }

      writeIgnoredPayments(next)
      return next
    })

    if (ignored) {
      setCompletedTodosByPeriod((current) => {
        const currentIds = new Set(current[viewedPeriod.id] ?? [])

        if (!currentIds.delete(item.id)) {
          return current
        }

        const next = {
          ...current,
          [viewedPeriod.id]: [...currentIds],
        }

        writeCompletedTodos(next)
        return next
      })
    }
  }

  return (
    <div className="space-y-6">
      <Panel
        title="Selected pay period"
        accent="blue"
        description={
          viewedPeriod
            ? `Paid ${formatShortDateWithOrdinal(viewedPeriod.payday)} · ${formatShortDateWithOrdinal(viewedPeriod.startDate)} to ${formatShortDateWithOrdinal(viewedPeriod.endDate)}`
            : snapshot.payPeriods.length > 0
              ? 'No saved pay period contains today. Choose a saved period to view its numbers.'
              : 'Create your first paycheck plan to see your pay, payments due, and money left.'
        }
        action={
          <div className="flex flex-col gap-2 sm:min-w-80 sm:flex-row sm:items-end">
            {snapshot.payPeriods.length > 0 && (
              <label className="block min-w-0 flex-1">
                <span className="text-xs font-semibold uppercase tracking-wide text-slate-500">Viewing</span>
                <SelectInput
                  aria-label="Viewing pay period"
                  className="mt-1"
                  value={viewedPeriod?.id ?? ''}
                  onChange={(event) => onPayPeriodChange?.(event.target.value || null)}
                >
                  {!viewedPeriod && <option value="">Choose a pay period</option>}
                  {snapshot.payPeriods.map((period) => (
                    <option key={period.id} value={period.id}>
                      {formatPayPeriodOption(period)}
                    </option>
                  ))}
                </SelectInput>
              </label>
            )}
            <Button onClick={() => onViewChange('payday')}>{viewedPeriod ? 'Update pay' : 'Plan pay'}</Button>
          </div>
        }
      >
        {viewedPeriod ? (
          <div className="grid items-start gap-4 lg:grid-cols-3">
            <MoneyMetric
              label="Total pay"
              value={formatPence(summary.payReceivedPence)}
              tone="primary"
              breakdown={getTotalPayBreakdown(summary, viewedPeriod.startDate, viewedPeriod.endDate)}
              open={openMetric === 'total-pay'}
              onOpenChange={(isOpen) =>
                setOpenMetric((current) => isOpen ? 'total-pay' : current === 'total-pay' ? null : current)
              }
            />
            <MoneyMetric
              label="Total costs"
              value={formatPence(summary.totalCostsPence)}
              tone="warning"
              breakdown={getTotalCostsBreakdown(summary)}
              open={openMetric === 'total-costs'}
              onOpenChange={(isOpen) =>
                setOpenMetric((current) => isOpen ? 'total-costs' : current === 'total-costs' ? null : current)
              }
            />
            <MoneyMetric
              label="Money left"
              value={formatPence(summary.moneyLeftPence)}
              tone={summary.moneyLeftPence < 0 ? 'bad' : 'good'}
              breakdown={getMoneyLeftBreakdown(summary)}
              open={openMetric === 'money-left'}
              onOpenChange={(isOpen) =>
                setOpenMetric((current) => isOpen ? 'money-left' : current === 'money-left' ? null : current)
              }
            />
          </div>
        ) : (
          <div className="rounded-lg border border-dashed border-slate-300 bg-slate-50 p-8 text-center">
            <p className="text-base font-semibold text-slate-950">
              {snapshot.payPeriods.length > 0 ? 'No active pay period selected' : 'No paycheck plan yet'}
            </p>
            <p className="mx-auto mt-2 max-w-lg text-sm leading-6 text-slate-500">
              {snapshot.payPeriods.length > 0
                ? 'Use the pay-period dropdown to review a saved paycheck window.'
                : 'Enter your pay and recurring payments to get one clear dashboard total.'}
            </p>
          </div>
        )}
      </Panel>
      {viewedPeriod && (
        <Panel
          title="Paycheck to-do list"
          accent="emerald"
          description={`Tick off where this paycheck needs to go. ${completedTodoCount} of ${activeTodoItems.length} done.${ignoredTodoCount > 0 ? ` ${ignoredTodoCount} ignored.` : ''}`}
        >
          {todoItems.length > 0 ? (
            <ul className="space-y-2">
              {todoItems.map((item) => {
                const isDone = completedTodoIds.has(item.id)
                const isIgnored = ignoredPaymentIds.has(item.ignoreId)

                return (
                  <li
                    key={item.id}
                    className={
                      isIgnored
                        ? 'rounded-lg border border-slate-200 bg-slate-50 px-3 py-3 opacity-75'
                        : isDone
                          ? 'rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-3'
                          : 'rounded-lg border border-slate-200 bg-white px-3 py-3'
                    }
                  >
                    <div className="grid gap-3 sm:grid-cols-[auto_1fr_auto_auto] sm:items-start">
                      <input
                        id={`dashboard-todo-${item.id}`}
                        type="checkbox"
                        className="mt-1 h-4 w-4 rounded border-slate-300 accent-emerald-600 focus:ring-emerald-500 disabled:cursor-not-allowed disabled:opacity-40"
                        aria-label={item.label}
                        checked={isDone && !isIgnored}
                        disabled={isIgnored}
                        onChange={(event) => toggleTodo(item.id, event.target.checked)}
                      />
                      <label htmlFor={`dashboard-todo-${item.id}`} className={isIgnored ? 'min-w-0 cursor-default' : 'min-w-0 cursor-pointer'}>
                        <span
                          className={
                            isIgnored
                              ? 'block text-sm font-semibold text-slate-500 line-through decoration-2'
                              : isDone
                                ? 'block text-sm font-semibold text-emerald-900 line-through decoration-2'
                                : 'block text-sm font-semibold text-slate-950'
                          }
                        >
                          {item.label}
                        </span>
                        <span
                          className={
                            isIgnored
                              ? 'mt-1 block text-xs font-semibold text-slate-500'
                              : isDone
                                ? 'mt-1 block text-xs text-emerald-700'
                                : 'mt-1 block text-xs text-slate-500'
                          }
                        >
                          {isIgnored ? 'Ignored for this paycheck' : item.detail}
                        </span>
                      </label>
                      <span
                        className={
                          isIgnored
                            ? 'text-sm font-semibold text-slate-500 line-through decoration-2 sm:text-right'
                            : isDone
                              ? 'text-sm font-semibold text-emerald-800 sm:text-right'
                              : 'text-sm font-semibold text-slate-950 sm:text-right'
                        }
                      >
                        {formatPence(item.amountPence)}
                      </span>
                      <button
                        type="button"
                        aria-label={`Ignore Payment for ${item.ignoreLabel}`}
                        aria-pressed={isIgnored}
                        onClick={() => toggleIgnoredPayment(item, !isIgnored)}
                        className={
                          isIgnored
                            ? 'inline-flex min-h-8 items-center justify-center rounded-md border border-amber-300 bg-amber-50 px-2.5 text-xs font-semibold text-amber-800 transition hover:bg-amber-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-500'
                            : 'inline-flex min-h-8 items-center justify-center rounded-md border border-slate-200 bg-white px-2.5 text-xs font-semibold text-slate-600 transition hover:bg-slate-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400'
                        }
                      >
                        Ignore Payment
                      </button>
                    </div>
                  </li>
                )
              })}
            </ul>
          ) : (
            <div className="rounded-lg border border-dashed border-slate-300 bg-slate-50 p-6 text-center">
              <p className="text-sm font-semibold text-slate-950">No set-asides for this paycheck</p>
              <p className="mt-1 text-sm leading-5 text-slate-500">
                Add pot allocations, credit pots, or debt reserves and they will appear here.
              </p>
            </div>
          )}
        </Panel>
      )}
    </div>
  )
}

function formatPayPeriodOption(period: PayPeriod): string {
  return formatShortDateWithOrdinal(period.payday)
}

function formatShortDateWithOrdinal(value: string): string {
  const date = new Date(`${value}T00:00:00.000Z`)
  const day = date.getUTCDate()
  const month = new Intl.DateTimeFormat('en-GB', { month: 'short' }).format(date)
  const year = new Intl.DateTimeFormat('en-GB', { year: '2-digit' }).format(date)

  return `${day}${getOrdinalSuffix(day)} ${month} ${year}`
}

function getOrdinalSuffix(day: number): string {
  if (day >= 11 && day <= 13) {
    return 'th'
  }

  const lastDigit = day % 10

  if (lastDigit === 1) {
    return 'st'
  }

  if (lastDigit === 2) {
    return 'nd'
  }

  if (lastDigit === 3) {
    return 'rd'
  }

  return 'th'
}

function getTotalPayBreakdown(
  summary: PayPeriodCostSummary,
  startDate: string,
  endDate: string,
): CalculationBreakdown {
  return {
    formula: 'Total pay is the income saved on the active paycheck plan.',
    lines: [
      {
        label: 'Saved paycheck income',
        value: formatPence(summary.payReceivedPence),
        detail: `${startDate} to ${endDate}`,
        tone: 'result',
      },
    ],
    note: 'This comes from the Payday tab. If you enter actual received, that replaces the hours estimate.',
  }
}

function getTotalCostsBreakdown(summary: PayPeriodCostSummary): CalculationBreakdown {
  return {
    formula: 'Total costs = recurring + saved payments + manual spending + pot top-ups + debt reserves + debt due + credit pots + credit-card net.',
    lines: [
      {
        label: 'Recurring not on cards',
        value: formatPence(summary.directRecurringPence),
        detail: 'Bills due this pay period that are not linked to a credit card.',
        tone: 'add',
      },
      {
        label: 'Saved payments not on cards',
        value: formatPence(summary.savedPaymentsPence),
        detail: 'One-off saved payments due in this period and not linked to a credit card.',
        tone: 'add',
      },
      {
        label: 'Manual spending not on cards',
        value: formatPence(summary.manualSpendingPence),
        detail: 'Logged spending in this period paid from a pot.',
        tone: 'add',
      },
      {
        label: 'Pot payday top-ups',
        value: formatPence(summary.potAllocationsPence),
        detail: 'Money automatically moved into pots from this paycheck.',
        tone: 'add',
      },
      {
        label: 'Debt reserves',
        value: formatPence(summary.debtReservesPence),
        detail: 'Accepted AI/manual set-asides for debts in this pay period. They do not mark debts paid.',
        tone: 'add',
      },
      {
        label: 'Debt due',
        value: formatPence(summary.debtMinimumsPence),
        detail: 'Outstanding debt due by the end of this period after planned reserves are subtracted.',
        tone: 'add',
      },
      {
        label: 'Credit card pots',
        value: formatPence(summary.creditCardPotsPence),
        detail: 'Money set aside from this paycheck for cards, including linked card pot shortfalls.',
        tone: 'add',
      },
      {
        label: 'Credit-card charges',
        value: formatPence(summary.creditCardChargesPence),
        detail: 'Recurring, saved, and manual spends linked to credit cards.',
        tone: 'add',
      },
      {
        label: 'Card repayments',
        value: `-${formatPence(summary.creditCardRepaymentsPence)}`,
        detail: 'Repayments reduce card costs for the period.',
        tone: 'subtract',
      },
      {
        label: 'Credit-card net used',
        value: formatPence(summary.creditCardNetPence),
        detail: 'Charges minus repayments, never below zero.',
        tone: 'result',
      },
      {
        label: 'Total costs',
        value: formatPence(summary.totalCostsPence),
        tone: 'result',
      },
    ],
    note: `${summary.items.length} dated items fed this period total.`,
  }
}

function getMoneyLeftBreakdown(summary: PayPeriodCostSummary): CalculationBreakdown {
  return {
    formula: 'Money left = total pay - total costs.',
    lines: [
      {
        label: 'Total pay',
        value: formatPence(summary.payReceivedPence),
        tone: 'add',
      },
      {
        label: 'Total costs',
        value: `-${formatPence(summary.totalCostsPence)}`,
        tone: 'subtract',
      },
      {
        label: 'Money left',
        value: formatPence(summary.moneyLeftPence),
        tone: 'result',
      },
    ],
    note: summary.moneyLeftPence < 0 ? 'This period is over committed.' : 'This is what remains after the listed costs.',
  }
}

function getPaycheckTodoItems(
  snapshot: PlannerSnapshot,
  payPeriod: PayPeriod,
  summary: PayPeriodCostSummary,
): PaycheckTodoItem[] {
  const recurringPaymentIdsInSummary = new Set(
    summary.items
      .filter((item) => item.source === 'recurring')
      .map((item) => getRecurringPaymentIdFromCostItem(item))
      .filter((paymentId): paymentId is string => Boolean(paymentId)),
  )
  const recurringAllocationTodos = snapshot.potAllocations
    .filter(
      (allocation) =>
        allocation.payPeriodId === payPeriod.id &&
        allocation.amountPence > 0 &&
        allocation.recurringPaymentId &&
        !recurringPaymentIdsInSummary.has(allocation.recurringPaymentId),
    )
    .map((allocation) => recurringAllocationToTodoItem(allocation, snapshot))
  const todoItems = [
    ...summary.items.flatMap((item) => periodCostItemToTodoItems(item, snapshot)),
    ...recurringAllocationTodos,
  ]

  return todoItems.sort((a, b) => {
    const detailSort = a.detail.localeCompare(b.detail)

    if (detailSort !== 0) {
      return detailSort
    }

    return a.label.localeCompare(b.label)
  })
}

function getRecurringPaymentIdFromCostItem(item: PeriodCostItem): string | null {
  const match = item.id.match(/^recurring-(.+)-\d{4}-\d{2}-\d{2}$/)
  return match?.[1] ?? null
}

function periodCostItemToTodoItems(item: PeriodCostItem, snapshot: PlannerSnapshot): PaycheckTodoItem[] {
  if (item.amountPence <= 0) {
    return []
  }

  if (item.source === 'recurring') {
    return [recurringCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'saved_payment') {
    return [savedPaymentCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'manual_spend') {
    return [manualSpendCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'pot_allocation') {
    return [potAllocationCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'debt_reserve') {
    return [debtReserveCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'debt_minimum') {
    return [debtMinimumCostToTodoItem(item)]
  }

  if (item.source === 'credit_card_pot') {
    return [creditCardPotCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'linked_credit_card_pot') {
    return [linkedCreditCardPotCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'credit_card_repayment') {
    return []
  }

  return []
}

function recurringAllocationToTodoItem(
  allocation: PlannerSnapshot['potAllocations'][number],
  snapshot: PlannerSnapshot,
): PaycheckTodoItem {
  const payment = allocation.recurringPaymentId
    ? snapshot.recurringPayments.find((candidate) => candidate.id === allocation.recurringPaymentId)
    : null
  const potName = getPotName(snapshot, allocation.potId)

  return {
    id: `pot-allocation-${allocation.id}-todo`,
    ignoreId: `pot-allocation-${allocation.id}`,
    ignoreLabel: payment?.name ?? potName,
    label: payment
      ? `Set aside ${formatPence(allocation.amountPence)} into "${potName}" pot for "${payment.name}"`
      : `Set aside ${formatPence(allocation.amountPence)} into "${potName}" pot`,
    detail: 'Recurring bill reserve',
    amountPence: allocation.amountPence,
  }
}

function recurringCostToTodoItem(item: PeriodCostItem, snapshot: PlannerSnapshot): PaycheckTodoItem {
  if (item.creditCardId) {
    return cardChargeCostToTodoItem(item, snapshot, 'Recurring card charge')
  }

  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: item.label,
    label: item.potId
      ? `Set aside ${formatPence(item.amountPence)} into "${getPotName(snapshot, item.potId)}" pot for "${item.label}"`
      : `Pay ${formatPence(item.amountPence)} for "${item.label}"`,
    detail: `Recurring bill due ${item.date}`,
    amountPence: item.amountPence,
  }
}

function savedPaymentCostToTodoItem(item: PeriodCostItem, snapshot: PlannerSnapshot): PaycheckTodoItem {
  if (item.creditCardId) {
    return cardChargeCostToTodoItem(item, snapshot, 'Saved card payment')
  }

  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: item.label,
    label: `Pay ${formatPence(item.amountPence)} for "${item.label}"`,
    detail: `Saved payment due ${item.date}`,
    amountPence: item.amountPence,
  }
}

function manualSpendCostToTodoItem(item: PeriodCostItem, snapshot: PlannerSnapshot): PaycheckTodoItem {
  if (item.creditCardId) {
    return cardChargeCostToTodoItem(item, snapshot, 'Logged card spend')
  }

  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: item.label,
    label: item.potId
      ? `Cover ${formatPence(item.amountPence)} from "${getPotName(snapshot, item.potId)}" pot for "${item.label}"`
      : `Cover ${formatPence(item.amountPence)} for "${item.label}"`,
    detail: item.potId ? `Logged pot spend on ${item.date}` : `Logged spend on ${item.date}`,
    amountPence: item.amountPence,
  }
}

function potAllocationCostToTodoItem(item: PeriodCostItem, snapshot: PlannerSnapshot): PaycheckTodoItem {
  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: item.label,
    label: `Set aside ${formatPence(item.amountPence)} into "${getPotName(snapshot, item.potId)}" pot`,
    detail: item.label.toLowerCase().includes('payday top-up') ? 'Automatic payday top-up' : 'Manual pot allocation',
    amountPence: item.amountPence,
  }
}

function debtReserveCostToTodoItem(item: PeriodCostItem, snapshot: PlannerSnapshot): PaycheckTodoItem {
  const reserve = snapshot.debtReserves.find((candidate) => item.id === `debt-reserve-${candidate.id}`)
  const debt = reserve ? snapshot.debts.find((candidate) => candidate.id === reserve.debtId) : null
  const debtName = debt?.name ?? item.label.replace(/\s+reserve$/i, '')

  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: debtName,
    label: `Set aside ${formatPence(item.amountPence)} for "${debtName}" debt`,
    detail: reserve?.note || 'Debt reserve',
    amountPence: item.amountPence,
  }
}

function debtMinimumCostToTodoItem(item: PeriodCostItem): PaycheckTodoItem {
  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: item.label,
    label: `Pay ${formatPence(item.amountPence)} toward "${item.label}" debt`,
    detail: `Debt due ${item.date}`,
    amountPence: item.amountPence,
  }
}

function creditCardPotCostToTodoItem(item: PeriodCostItem, snapshot: PlannerSnapshot): PaycheckTodoItem {
  const creditCardPot = snapshot.creditCardPots.find((candidate) => item.id === `credit-card-pot-${candidate.id}`)
  const cardName = getCardName(snapshot, item.creditCardId)

  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: cardName,
    label: `Set aside ${formatPence(item.amountPence)} for "${cardName}" card`,
    detail: creditCardPot?.note || item.label,
    amountPence: item.amountPence,
  }
}

function linkedCreditCardPotCostToTodoItem(item: PeriodCostItem, snapshot: PlannerSnapshot): PaycheckTodoItem {
  const cardName = getCardName(snapshot, item.creditCardId)

  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: cardName,
    label: `Set aside ${formatPence(item.amountPence)} into "${getPotName(snapshot, item.potId)}" pot for "${cardName}" card amount owed`,
    detail: 'Linked card balance still owed',
    amountPence: item.amountPence,
  }
}

function cardChargeCostToTodoItem(item: PeriodCostItem, snapshot: PlannerSnapshot, detail: string): PaycheckTodoItem {
  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: item.label,
    label: `Set aside ${formatPence(item.amountPence)} for "${getCardName(snapshot, item.creditCardId)}" card charge "${item.label}"`,
    detail,
    amountPence: item.amountPence,
  }
}

function getPotName(snapshot: PlannerSnapshot, potId?: string | null): string {
  if (!potId) {
    return 'Unlinked'
  }

  return snapshot.pots.find((candidate) => candidate.id === potId)?.name ?? 'Archived pot'
}

function getCardName(snapshot: PlannerSnapshot, creditCardId?: string | null): string {
  if (!creditCardId) {
    return 'Unlinked'
  }

  return snapshot.creditCards.find((candidate) => candidate.id === creditCardId)?.name ?? 'Archived card'
}

function readCompletedTodos(): Record<string, string[]> {
  return readStoredStringArrayRecord(dashboardTodoStorageKey)
}

function writeCompletedTodos(completedTodos: Record<string, string[]>): void {
  writeStoredStringArrayRecord(dashboardTodoStorageKey, completedTodos)
}

function readIgnoredPayments(): Record<string, string[]> {
  return readStoredStringArrayRecord(dashboardIgnoredPaymentsStorageKey)
}

function writeIgnoredPayments(ignoredPayments: Record<string, string[]>): void {
  writeStoredStringArrayRecord(dashboardIgnoredPaymentsStorageKey, ignoredPayments)
}

function readStoredStringArrayRecord(storageKey: string): Record<string, string[]> {
  if (typeof window === 'undefined') {
    return {}
  }

  try {
    const stored = window.localStorage.getItem(storageKey)

    if (!stored) {
      return {}
    }

    const parsed = JSON.parse(stored) as unknown

    if (!parsed || typeof parsed !== 'object') {
      return {}
    }

    return Object.fromEntries(
      Object.entries(parsed).filter((entry): entry is [string, string[]] =>
        Array.isArray(entry[1]) && entry[1].every((item) => typeof item === 'string'),
      ),
    )
  } catch {
    return {}
  }
}

function writeStoredStringArrayRecord(storageKey: string, value: Record<string, string[]>): void {
  if (typeof window === 'undefined') {
    return
  }

  try {
    window.localStorage.setItem(storageKey, JSON.stringify(value))
  } catch {
    // The checklist still works for the current session if storage is unavailable.
  }
}
