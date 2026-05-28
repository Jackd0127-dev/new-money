import { useState, type ReactNode } from 'react'
import {
  ArrowRight,
  CalendarDays,
  CheckCircle2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  CircleDollarSign,
  Clock3,
  EyeOff,
  PiggyBank,
  ReceiptText,
} from 'lucide-react'

import {
  createNextPayPeriod,
  filterPayPeriodCostSummary,
  formatPence,
  getAppTodayIso,
  getCostItemIdFromDashboardTodoPeriodCostItemId,
  getAdditionalLinkedCreditCardPotAllocationPence,
  getAdditionalLinkedCreditCardPotCoverBreakdown,
  getCompletedLinkedCreditCardPotAllocation,
  getPreviousCompletedLinkedCreditCardPotAllocation,
  getCoveredAdditionalLinkedCardManualSpendTransactionIds,
  getCreditCardIdFromLinkedCreditCardPotCostItemId,
  getDashboardTodoAllocationId,
  getLinkedCreditCardPotAllocationExclusionPence,
  getLinkedCreditCardPotCoverBreakdown,
  getPayPeriodCostSummary,
  isAdditionalLinkedCreditCardPotCostItemId,
  type PeriodCostItem,
  type PayPeriodCostSummary,
} from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, MoneyMetric, Panel, SectionGrid, SelectInput, type CalculationBreakdown } from '../components/ui'
import type { PayFrequency, PayPeriod, PotAllocation } from '../types/models'
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
  breakdownLabel?: string
  breakdownLines: PaycheckTodoBreakdownLine[]
  completion?: PaycheckTodoCompletion
}

interface PaycheckTodoBreakdownLine {
  id: string
  label: string
  detail: string
  amountPence: number
}

interface PaycheckTodoCompletion {
  type: 'pot_allocation'
  id: string
  payPeriodId: string
  potId: string
  amountPence: number
}

export function DashboardPage({
  snapshot,
  selectedPayPeriod,
  actions,
  onPayPeriodChange,
  onViewChange,
}: {
  snapshot: PlannerSnapshot
  selectedPayPeriod?: PayPeriod | null
  actions?: Pick<PlannerActions, 'upsertPaycheckPotAllocation' | 'deletePaycheckPotAllocation'>
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
  const [pendingTodoIds, setPendingTodoIds] = useState<Set<string>>(() => new Set())
  const [expandedTodoIds, setExpandedTodoIds] = useState<Set<string>>(() => new Set())
  const [isNextOutgoingsOpen, setIsNextOutgoingsOpen] = useState(false)
  const [outgoingPreviewOffset, setOutgoingPreviewOffset] = useState(1)
  const today = getAppTodayIso(snapshot.settings)
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
    asOfDate: today,
  })
  const ignoredPaymentIds = new Set(viewedPeriod ? ignoredPaymentsByPeriod[viewedPeriod.id] ?? [] : [])
  const summary = filterPayPeriodCostSummary(baseSummary, ignoredPaymentIds)
  const todoItems = viewedPeriod ? getPaycheckTodoItems(snapshot, viewedPeriod, baseSummary, today) : []
  const completedTodoIds = new Set(viewedPeriod ? completedTodosByPeriod[viewedPeriod.id] ?? [] : [])
  const activeTodoItems = todoItems.filter((item) => !ignoredPaymentIds.has(item.ignoreId))
  const completedTodoCount = activeTodoItems.filter((item) => completedTodoIds.has(item.id)).length
  const ignoredTodoCount = todoItems.length - activeTodoItems.length
  const activeTodoAmountPence = activeTodoItems.reduce(
    (totalPence, item) => totalPence + Math.max(0, item.amountPence),
    0,
  )
  const completedTodoAmountPence = activeTodoItems
    .filter((item) => completedTodoIds.has(item.id))
    .reduce((totalPence, item) => totalPence + Math.max(0, item.amountPence), 0)
  const remainingTodoAmountPence = Math.max(0, activeTodoAmountPence - completedTodoAmountPence)
  const outgoingPreviewPeriod = viewedPeriod
    ? getRelativePaycheckPeriod(
        viewedPeriod,
        outgoingPreviewOffset,
        viewedPeriod.payFrequency ?? snapshot.settings.payFrequency,
      )
    : null
  const outgoingPreviewSummary = getPayPeriodCostSummary({
    payPeriod: outgoingPreviewPeriod,
    creditCards: snapshot.creditCards,
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
      ...(outgoingPreviewPeriod ? getPreviewPotTopUps(snapshot, outgoingPreviewPeriod) : []),
    ],
    asOfDate: today,
  })

  async function toggleTodo(item: PaycheckTodoItem, done: boolean) {
    if (!viewedPeriod) {
      return
    }

    if (item.completion && actions) {
      setPendingTodoIds((current) => new Set(current).add(item.id))

      try {
        if (done) {
          await actions.upsertPaycheckPotAllocation({
            id: item.completion.id,
            payPeriodId: item.completion.payPeriodId,
            potId: item.completion.potId,
            amountPence: item.completion.amountPence,
          })
        } else {
          await actions.deletePaycheckPotAllocation(item.completion.id)
        }
      } finally {
        setPendingTodoIds((current) => {
          const next = new Set(current)
          next.delete(item.id)
          return next
        })
      }
    }

    setCompletedTodosByPeriod((current) => {
      const currentIds = new Set(current[viewedPeriod.id] ?? [])

      if (done) {
        currentIds.add(item.id)
      } else {
        currentIds.delete(item.id)
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

  function toggleTodoBreakdown(itemId: string) {
    setExpandedTodoIds((current) => {
      const next = new Set(current)

      if (next.has(itemId)) {
        next.delete(itemId)
      } else {
        next.add(itemId)
      }

      return next
    })
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
          <div className="flex w-full flex-col gap-2 lg:min-w-80 lg:flex-row lg:items-end">
            {snapshot.payPeriods.length > 0 && (
              <label className="block w-full min-w-0 flex-1">
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
            <Button className="w-full lg:w-auto" onClick={() => onViewChange('payday')}>
              {viewedPeriod ? 'Update pay' : 'Plan pay'}
            </Button>
          </div>
        }
      >
        {viewedPeriod ? (
          <div className="space-y-4">
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
            <PaycheckFlowDiagram summary={summary} />
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
        <SectionGrid variant="wideLeft" className="gap-6">
          <Panel
            title="Paycheck to-do list"
            accent="emerald"
            description={`Tick off where this paycheck needs to go. ${completedTodoCount} of ${activeTodoItems.length} done.${ignoredTodoCount > 0 ? ` ${ignoredTodoCount} ignored.` : ''}`}
          >
            {todoItems.length > 0 ? (
              <div className="space-y-3">
                <ChecklistProgressCard
                  activeCount={activeTodoItems.length}
                  completedCount={completedTodoCount}
                  ignoredCount={ignoredTodoCount}
                  completedAmountPence={completedTodoAmountPence}
                  remainingAmountPence={remainingTodoAmountPence}
                  totalAmountPence={activeTodoAmountPence}
                />
                <ul className="space-y-2">
                  {todoItems.map((item) => {
                    const isDone = completedTodoIds.has(item.id)
                    const isIgnored = ignoredPaymentIds.has(item.ignoreId)
                    const isPending = pendingTodoIds.has(item.id)
                    const isExpanded = expandedTodoIds.has(item.id)
                    const breakdownId = `dashboard-todo-breakdown-${item.id}`
                    const breakdownLabel = item.breakdownLabel ?? item.ignoreLabel

                    return (
                      <li
                        key={item.id}
                        className={
                          isIgnored
                            ? 'rounded-lg border border-slate-200/90 bg-slate-50/80 px-3 py-3 opacity-75'
                            : isDone
                              ? 'rounded-lg border border-emerald-200/90 bg-emerald-50 bg-[linear-gradient(135deg,#f0fdf4,#ecfeff)] px-3 py-3 shadow-sm shadow-emerald-100/70'
                              : 'rounded-lg border border-slate-200/90 bg-white/95 px-3 py-3 shadow-[0_12px_30px_rgba(15,23,42,0.05)] transition hover:-translate-y-0.5 hover:border-emerald-200'
                        }
                      >
                        <div className="grid gap-3 sm:grid-cols-[auto_1fr_auto_auto_auto] sm:items-start">
                          <input
                            id={`dashboard-todo-${item.id}`}
                            type="checkbox"
                            className="mt-1 h-4 w-4 rounded border-slate-300 accent-emerald-600 focus:ring-emerald-500 disabled:cursor-not-allowed disabled:opacity-40"
                            aria-label={item.label}
                            checked={isDone && !isIgnored}
                            disabled={isIgnored || isPending}
                            onChange={(event) => void toggleTodo(item, event.target.checked)}
                          />
                          <label htmlFor={`dashboard-todo-${item.id}`} className={isIgnored ? 'min-w-0 cursor-default' : 'min-w-0 cursor-pointer'}>
                            <span
                              className={
                                isIgnored
                                  ? 'block text-sm font-semibold text-slate-500 line-through decoration-2'
                                  : isDone
                                    ? 'block text-sm font-semibold text-emerald-950 line-through decoration-2'
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
                            aria-label={`${isExpanded ? 'Hide' : 'Show'} breakdown for ${breakdownLabel}`}
                            aria-expanded={isExpanded}
                            aria-controls={breakdownId}
                            onClick={() => toggleTodoBreakdown(item.id)}
                            className={
                              isIgnored
                                ? 'inline-flex min-h-8 w-9 items-center justify-center rounded-lg border border-slate-200/90 bg-white/90 text-slate-400 transition hover:bg-slate-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400'
                                : 'inline-flex min-h-8 w-9 items-center justify-center rounded-lg border border-slate-200/90 bg-white/90 text-slate-600 shadow-sm shadow-slate-200/60 transition hover:-translate-y-0.5 hover:bg-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400'
                            }
                          >
                            <ChevronDown
                              size={16}
                              aria-hidden="true"
                              className={isExpanded ? 'rotate-180 transition' : 'transition'}
                            />
                          </button>
                          <button
                            type="button"
                            aria-label={`Ignore Payment for ${item.ignoreLabel}`}
                            aria-pressed={isIgnored}
                            onClick={() => toggleIgnoredPayment(item, !isIgnored)}
                            className={
                              isIgnored
                                ? 'inline-flex min-h-8 items-center justify-center rounded-lg border border-amber-300 bg-amber-50 px-2.5 text-xs font-semibold text-amber-800 transition hover:bg-amber-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-500'
                                : 'inline-flex min-h-8 items-center justify-center rounded-lg border border-slate-200/90 bg-white/90 px-2.5 text-xs font-semibold text-slate-600 shadow-sm shadow-slate-200/60 transition hover:-translate-y-0.5 hover:bg-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400'
                            }
                          >
                            Ignore Payment
                          </button>
                        </div>
                        {isExpanded && (
                          <div
                            id={breakdownId}
                            role="region"
                            aria-label={`Breakdown for ${breakdownLabel}`}
                            className="mt-3 rounded-lg border border-slate-200/90 bg-slate-50/80 p-3 shadow-inner shadow-slate-200/60"
                          >
                            <ul className="space-y-2">
                              {item.breakdownLines.map((line) => (
                                <li key={line.id} className="grid grid-cols-[minmax(0,1fr)_auto] gap-3 rounded-lg border border-slate-200/70 bg-white/90 px-3 py-2 text-sm shadow-sm shadow-slate-200/50">
                                  <div className="min-w-0">
                                    <p className="truncate font-semibold text-slate-900">{line.label}</p>
                                    <p className="mt-0.5 text-xs leading-5 text-slate-500">{line.detail}</p>
                                  </div>
                                  <p className={line.amountPence < 0 ? 'font-semibold text-emerald-700' : 'font-semibold text-slate-950'}>
                                    {formatPence(line.amountPence)}
                                  </p>
                                </li>
                              ))}
                            </ul>
                            <div className="mt-3 flex items-center justify-between border-t border-slate-200 pt-3 text-sm">
                              <span className="font-semibold text-slate-700">Total</span>
                              <span className="font-semibold text-slate-950">{formatPence(item.amountPence)}</span>
                            </div>
                          </div>
                        )}
                      </li>
                    )
                  })}
                </ul>
              </div>
            ) : (
              <div className="rounded-lg border border-dashed border-slate-300 bg-slate-50 p-6 text-center">
                <p className="text-sm font-semibold text-slate-950">No set-asides for this paycheck</p>
                <p className="mt-1 text-sm leading-5 text-slate-500">
                  Add pot allocations, credit pots, or debt reserves and they will appear here.
                </p>
              </div>
            )}
          </Panel>
          <NextPaycheckOutgoingsPanel
            period={outgoingPreviewPeriod}
            summary={outgoingPreviewSummary}
            offset={outgoingPreviewOffset}
            isOpen={isNextOutgoingsOpen}
            onToggleOpen={() => setIsNextOutgoingsOpen((current) => !current)}
            onPrevious={() => setOutgoingPreviewOffset((current) => current - 1)}
            onNext={() => setOutgoingPreviewOffset((current) => current + 1)}
          />
        </SectionGrid>
      )}
    </div>
  )
}

function ChecklistProgressCard({
  activeCount,
  completedCount,
  ignoredCount,
  completedAmountPence,
  remainingAmountPence,
  totalAmountPence,
}: {
  activeCount: number
  completedCount: number
  ignoredCount: number
  completedAmountPence: number
  remainingAmountPence: number
  totalAmountPence: number
}) {
  const countPercent = activeCount > 0 ? Math.round((completedCount / activeCount) * 100) : 0
  const amountPercent = totalAmountPence > 0
    ? Math.min(100, Math.round((completedAmountPence / totalAmountPence) * 100))
    : countPercent
  const openCount = Math.max(0, activeCount - completedCount)

  return (
    <div className="overflow-hidden rounded-2xl border border-emerald-200/90 bg-[linear-gradient(135deg,#ecfdf5,#f8fafc_55%,#ecfeff)] shadow-[0_18px_45px_rgba(16,185,129,0.12)]">
      <div className="grid gap-4 p-4 md:grid-cols-[auto_1fr] md:items-center">
        <div className="flex items-center gap-4">
          <div
            className="relative flex size-20 shrink-0 items-center justify-center rounded-full shadow-inner shadow-emerald-200/80"
            style={{ background: `conic-gradient(#10b981 ${countPercent * 3.6}deg, #dbeafe 0deg)` }}
            aria-hidden="true"
          >
            <div className="flex size-14 items-center justify-center rounded-full border border-white/80 bg-white text-lg font-semibold tracking-[-0.02em] text-slate-950 shadow-sm">
              {countPercent}%
            </div>
          </div>
          <div className="min-w-0">
            <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">Checklist progress</p>
            <p className="mt-1 text-xl font-semibold tracking-[-0.02em] text-slate-950">
              {completedCount} of {activeCount} sorted
            </p>
            <p className="mt-1 text-sm leading-5 text-slate-600">
              {openCount > 0
                ? `${openCount} item${openCount === 1 ? '' : 's'} still need attention.`
                : 'Every active set-aside is complete.'}
            </p>
          </div>
        </div>

        <div className="grid gap-3 sm:grid-cols-3">
          <ChecklistProgressStat
            icon={<CheckCircle2 size={16} />}
            label="Done"
            value={formatPence(completedAmountPence)}
            className="border-emerald-200/90 bg-white/80 text-emerald-700"
          />
          <ChecklistProgressStat
            icon={<Clock3 size={16} />}
            label="Left"
            value={formatPence(remainingAmountPence)}
            className="border-amber-200/90 bg-white/80 text-amber-700"
          />
          <ChecklistProgressStat
            icon={<EyeOff size={16} />}
            label="Ignored"
            value={`${ignoredCount}`}
            className="border-slate-200/90 bg-white/80 text-slate-500"
          />
        </div>
      </div>
      <div className="border-t border-emerald-100/80 bg-white/55 p-4">
        <div className="mb-2 flex items-center justify-between gap-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
          <span>Amount covered</span>
          <span>{formatPence(completedAmountPence)} of {formatPence(totalAmountPence)}</span>
        </div>
        <div className="h-2 overflow-hidden rounded-full bg-white shadow-inner shadow-slate-200/80">
          <div
            className="h-full rounded-full bg-[linear-gradient(90deg,#10b981,#06b6d4)] shadow-sm transition-all"
            style={{ width: `${amountPercent}%` }}
          />
        </div>
      </div>
    </div>
  )
}

function ChecklistProgressStat({
  icon,
  label,
  value,
  className,
}: {
  icon: ReactNode
  label: string
  value: string
  className: string
}) {
  return (
    <div className={`rounded-xl border p-3 shadow-sm shadow-slate-200/60 ${className}`}>
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide">
        {icon}
        {label}
      </div>
      <p className="mt-2 text-lg font-semibold tracking-[-0.02em] text-slate-950">{value}</p>
    </div>
  )
}

function PaycheckFlowDiagram({ summary }: { summary: PayPeriodCostSummary }) {
  const payPence = Math.max(0, summary.payReceivedPence)
  const costPence = Math.max(0, summary.totalCostsPence)
  const leftPence = Math.max(0, summary.moneyLeftPence)
  const overspentPence = Math.max(0, -summary.moneyLeftPence)
  const basePence = Math.max(payPence, costPence + leftPence, 1)
  const payWidth = Math.max(8, Math.round((payPence / basePence) * 100))
  const costWidth = Math.min(100, Math.max(8, Math.round((costPence / basePence) * 100)))
  const leftWidth = Math.min(100, Math.max(leftPence > 0 ? 8 : 0, Math.round((leftPence / basePence) * 100)))
  const overspentWidth = Math.min(100, Math.max(overspentPence > 0 ? 8 : 0, Math.round((overspentPence / basePence) * 100)))

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200/90 bg-white/95 shadow-[0_18px_55px_rgba(15,23,42,0.07)]">
      <div className="grid gap-4 p-4 lg:grid-cols-[1fr_auto_1fr_auto_1fr] lg:items-stretch">
        <PaycheckFlowNode
          icon={<CircleDollarSign size={17} />}
          label="Pay in"
          value={formatPence(summary.payReceivedPence)}
          detail="Income saved to this paycheck"
          tone="pay"
        />
        <FlowArrow />
        <PaycheckFlowNode
          icon={<ReceiptText size={17} />}
          label="Committed"
          value={formatPence(summary.totalCostsPence)}
          detail="Checklist, reserves, payments"
          tone="cost"
        />
        <FlowArrow />
        <PaycheckFlowNode
          icon={<PiggyBank size={17} />}
          label={summary.moneyLeftPence < 0 ? 'Shortfall' : 'Left'}
          value={formatPence(summary.moneyLeftPence)}
          detail={summary.moneyLeftPence < 0 ? 'Needs attention' : 'Available after plan'}
          tone={summary.moneyLeftPence < 0 ? 'bad' : 'left'}
        />
      </div>
      <div className="border-t border-slate-100 bg-slate-50/70 p-4">
        <div className="flex items-center justify-between gap-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
          <span>Paycheck shape</span>
          <span>{summary.items.length} planned item{summary.items.length === 1 ? '' : 's'}</span>
        </div>
        <div className="mt-3 grid gap-2">
          <FlowBar label="Pay" value={formatPence(summary.payReceivedPence)} width={payWidth} className="bg-slate-950" />
          <FlowBar label="Costs" value={formatPence(summary.totalCostsPence)} width={costWidth} className="bg-amber-400" />
          {summary.moneyLeftPence >= 0 ? (
            <FlowBar label="Left" value={formatPence(summary.moneyLeftPence)} width={leftWidth} className="bg-emerald-500" />
          ) : (
            <FlowBar label="Over" value={formatPence(overspentPence)} width={overspentWidth} className="bg-red-500" />
          )}
        </div>
      </div>
    </div>
  )
}

function PaycheckFlowNode({
  icon,
  label,
  value,
  detail,
  tone,
}: {
  icon: ReactNode
  label: string
  value: string
  detail: string
  tone: 'pay' | 'cost' | 'left' | 'bad'
}) {
  const toneClassName =
    tone === 'pay'
      ? 'border-slate-900 bg-slate-950 text-white'
      : tone === 'cost'
        ? 'border-amber-200 bg-[linear-gradient(135deg,#fff7ed,#fffbeb)] text-amber-700'
        : tone === 'bad'
          ? 'border-red-200 bg-[linear-gradient(135deg,#ffffff,#fef2f2)] text-red-700'
          : 'border-emerald-200 bg-[linear-gradient(135deg,#f0fdf4,#ecfeff)] text-emerald-700'
  const valueClassName = tone === 'pay' ? 'text-white' : 'text-slate-950'
  const detailClassName = tone === 'pay' ? 'text-slate-300' : 'text-slate-500'

  return (
    <div className={`rounded-2xl border p-4 shadow-[0_14px_35px_rgba(15,23,42,0.06)] ${toneClassName}`}>
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide">
        {icon}
        {label}
      </div>
      <p className={`mt-3 text-2xl font-semibold tracking-[-0.02em] ${valueClassName}`}>{value}</p>
      <p className={`mt-1 text-xs leading-5 ${detailClassName}`}>{detail}</p>
    </div>
  )
}

function FlowArrow() {
  return (
    <div className="hidden items-center justify-center text-slate-300 lg:flex">
      <span className="flex size-9 items-center justify-center rounded-full border border-slate-200/90 bg-white/90 shadow-sm shadow-slate-200/60">
        <ArrowRight size={16} />
      </span>
    </div>
  )
}

function FlowBar({
  label,
  value,
  width,
  className,
}: {
  label: string
  value: string
  width: number
  className: string
}) {
  return (
    <div className="grid gap-2 sm:grid-cols-[5rem_1fr_auto] sm:items-center">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <div className="h-2 overflow-hidden rounded-full bg-white shadow-inner shadow-slate-200/70">
        <div className={`h-full rounded-full shadow-sm transition-all ${className}`} style={{ width: `${width}%` }} />
      </div>
      <p className="text-xs font-semibold text-slate-700">{value}</p>
    </div>
  )
}

function NextPaycheckOutgoingsPanel({
  period,
  summary,
  offset,
  isOpen,
  onToggleOpen,
  onPrevious,
  onNext,
}: {
  period: PayPeriod | null
  summary: PayPeriodCostSummary
  offset: number
  isOpen: boolean
  onToggleOpen: () => void
  onPrevious: () => void
  onNext: () => void
}) {
  const periodDescription = period
    ? `${period.startDate} to ${period.endDate}`
    : 'Create a paycheck plan to preview future outgoings.'
  const outgoingItems = summary.items.filter((item) => item.amountPence !== 0)
  const toggleLabel = isOpen ? 'Hide next paycheck outgoings' : 'Show next paycheck outgoings'

  return (
    <Panel
      title="What you owe next paycheck"
      accent="amber"
      description={periodDescription}
      action={
        <div className="flex w-full shrink-0 items-center justify-between gap-2">
          <button
            type="button"
            aria-label="Previous paycheck preview"
            onClick={onPrevious}
            className="inline-flex min-h-9 w-9 items-center justify-center rounded-lg border border-slate-200/90 bg-white/90 text-slate-600 shadow-sm shadow-slate-200/60 transition hover:-translate-y-0.5 hover:bg-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400"
          >
            <ChevronLeft size={16} aria-hidden="true" />
          </button>
          <span className="hidden min-w-32 rounded-lg border border-slate-200/90 bg-white/90 px-3 py-2 text-center text-xs font-semibold uppercase tracking-wide text-slate-500 shadow-sm shadow-slate-200/60 sm:inline-block">
            {formatPaycheckOffsetLabel(offset)}
          </span>
          <button
            type="button"
            aria-label="Next paycheck preview"
            onClick={onNext}
            className="inline-flex min-h-9 w-9 items-center justify-center rounded-lg border border-slate-200/90 bg-white/90 text-slate-600 shadow-sm shadow-slate-200/60 transition hover:-translate-y-0.5 hover:bg-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400"
          >
            <ChevronRight size={16} aria-hidden="true" />
          </button>
        </div>
      }
    >
      {period ? (
        <div className="space-y-3">
          <div className="grid gap-3">
            <div className="rounded-lg border border-amber-200/90 bg-[linear-gradient(135deg,#fff7ed,#fffbeb)] p-4 shadow-sm shadow-amber-100/70">
              <p className="text-xs font-semibold uppercase tracking-wide text-amber-700">Total outgoing</p>
              <p className="mt-2 text-3xl font-semibold tracking-[-0.02em] text-slate-950">{formatPence(summary.totalCostsPence)}</p>
              <p className="mt-1 text-sm text-amber-800">{outgoingItems.length} payments in this paycheck window</p>
              <div className="mt-4 flex h-6 items-end gap-1.5" aria-hidden="true">
                {[36, 48, 28, 64, 52, 76, 34, 42, 58, 70, 45, 32].map((height, index) => (
                  <span
                    key={`${height}-${index}`}
                    className="w-1 flex-1 rounded-full bg-amber-400/75"
                    style={{ height: `${height}%` }}
                  />
                ))}
              </div>
            </div>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-1 2xl:grid-cols-2">
              <div className="rounded-lg border border-emerald-200/90 bg-emerald-50/80 p-3">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Money left estimate</p>
                <p className={summary.moneyLeftPence < 0 ? 'mt-1 text-lg font-semibold text-red-700' : 'mt-1 text-lg font-semibold text-emerald-700'}>
                  {formatPence(summary.moneyLeftPence)}
                </p>
              </div>
              <div className="rounded-lg border border-cyan-200/90 bg-cyan-50/70 p-3">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Paycheck</p>
                <p className="mt-1 text-sm font-semibold text-slate-950">{formatPaycheckOffsetLabel(offset)}</p>
              </div>
            </div>
            <button
              type="button"
              aria-label={toggleLabel}
              aria-expanded={isOpen}
              onClick={onToggleOpen}
              className="inline-flex min-h-12 items-center justify-center gap-2 rounded-lg border border-slate-900 bg-slate-950 px-4 text-sm font-semibold text-white shadow-[0_10px_26px_rgba(15,23,42,0.18)] transition hover:-translate-y-0.5 hover:bg-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-950"
            >
              <CalendarDays size={16} aria-hidden="true" />
              {isOpen ? 'Hide payments' : 'Show payments'}
              <ChevronDown size={16} aria-hidden="true" className={isOpen ? 'rotate-180 transition' : 'transition'} />
            </button>
          </div>

          {isOpen && (
            <div className="rounded-lg border border-slate-200/90 bg-slate-50/70 p-3">
              {outgoingItems.length > 0 ? (
                <ul className="divide-y divide-slate-200">
                  {outgoingItems.map((item) => (
                    <li key={item.id} className="grid gap-3 py-3 first:pt-0 last:pb-0 sm:grid-cols-[minmax(0,1fr)_auto]">
                      <div className="min-w-0">
                        <p className="truncate text-sm font-semibold text-slate-950">{item.label}</p>
                        <p className="mt-0.5 text-xs leading-5 text-slate-500">
                          {item.date} · {formatCostSource(item.source)}
                        </p>
                        {item.coverBreakdown && item.coverBreakdown.length > 0 && (
                          <ul className="mt-2 space-y-1 rounded-lg border border-slate-200/90 bg-white/90 px-2.5 py-2 shadow-sm shadow-slate-200/60">
                            {item.coverBreakdown.map((line) => (
                              <li key={line.id} className="flex items-start justify-between gap-3 text-xs">
                                <span className="min-w-0">
                                  <span className="block truncate font-semibold text-slate-700">{line.label}</span>
                                  <span className="block leading-4 text-slate-500">
                                    {line.date} · {line.detail}
                                  </span>
                                </span>
                                <span className={line.amountPence < 0 ? 'shrink-0 font-semibold text-emerald-700' : 'shrink-0 font-semibold text-slate-800'}>
                                  {line.amountPence < 0 ? '-' : ''}
                                  {formatPence(Math.abs(line.amountPence))}
                                </span>
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                      <p className={item.amountPence < 0 ? 'text-sm font-semibold text-emerald-700' : 'text-sm font-semibold text-slate-950'}>
                        {item.amountPence < 0 ? '-' : ''}
                        {formatPence(Math.abs(item.amountPence))}
                      </p>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="rounded-lg border border-dashed border-slate-200/90 bg-white/90 px-3 py-3 text-sm text-slate-500">
                  No outgoing payments are dated inside this paycheck window yet.
                </p>
              )}
            </div>
          )}
        </div>
      ) : (
        <p className="rounded-lg border border-dashed border-slate-200/90 bg-slate-50/80 p-3 text-sm text-slate-500">
          No paycheck is selected, so there is no future period to preview yet.
        </p>
      )}
    </Panel>
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

function getRelativePaycheckPeriod(currentPeriod: PayPeriod, offset: number, frequency: PayFrequency): PayPeriod {
  if (offset === 0) {
    return currentPeriod
  }

  if (offset > 0) {
    let payday = currentPeriod.nextPayday

    for (let index = 1; index < offset; index += 1) {
      payday = createNextPayPeriod(payday, frequency).nextPayday
    }

    const dates = createNextPayPeriod(payday, frequency)

    return {
      id: `paycheck-preview-${offset}-${payday}`,
      startDate: dates.startDate,
      endDate: dates.endDate,
      payday,
      nextPayday: dates.nextPayday,
      payFrequency: frequency,
      incomePence: currentPeriod.incomePence,
      status: 'planned',
      createdAt: currentPeriod.updatedAt,
      updatedAt: currentPeriod.updatedAt,
    }
  }

  const stepDays = getPaycheckStepDays(currentPeriod, frequency)
  const payday = shiftIsoDate(currentPeriod.payday, stepDays * offset)
  const nextPayday = shiftIsoDate(payday, stepDays)

  return {
    id: `paycheck-preview-${offset}-${payday}`,
    startDate: payday,
    endDate: shiftIsoDate(nextPayday, -1),
    payday,
    nextPayday,
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

function formatPaycheckOffsetLabel(offset: number): string {
  if (offset === 0) {
    return 'Selected paycheck'
  }

  if (offset === 1) {
    return 'Next paycheck'
  }

  if (offset === -1) {
    return 'Previous paycheck'
  }

  return offset > 1 ? `${offset} paychecks ahead` : `${Math.abs(offset)} paychecks back`
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

  if (source === 'linked_credit_card_pot') {
    return 'Card pot'
  }

  return 'Card repayment'
}

function getPaycheckStepDays(currentPeriod: PayPeriod, frequency: PayFrequency): number {
  if (frequency === 'weekly') {
    return 7
  }

  if (frequency === 'monthly') {
    return 31
  }

  if (frequency === 'custom') {
    return Math.max(1, getIsoDateDayDifference(currentPeriod.payday, currentPeriod.nextPayday) || 14)
  }

  return 14
}

function shiftIsoDate(value: string, days: number): string {
  const date = new Date(`${value}T00:00:00.000Z`)
  date.setUTCDate(date.getUTCDate() + days)

  return date.toISOString().slice(0, 10)
}

function getIsoDateDayDifference(startDate: string, endDate: string): number {
  const start = new Date(`${startDate}T00:00:00.000Z`).getTime()
  const end = new Date(`${endDate}T00:00:00.000Z`).getTime()

  return Math.round((end - start) / 86400000)
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
        detail: 'Bills due this pay period that are not linked to a credit card, after money already set aside in linked pots.',
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
  today: string,
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
    ...summary.items.flatMap((item) => periodCostItemToTodoItems(item, snapshot, payPeriod, today)),
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

function periodCostItemToTodoItems(
  item: PeriodCostItem,
  snapshot: PlannerSnapshot,
  payPeriod: PayPeriod,
  today: string,
): PaycheckTodoItem[] {
  if (item.amountPence <= 0) {
    return []
  }

  if (item.source === 'recurring') {
    return [recurringCostToTodoItem(item, snapshot, payPeriod)]
  }

  if (item.source === 'saved_payment') {
    return [savedPaymentCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'manual_spend') {
    return [manualSpendCostToTodoItem(item, snapshot)]
  }

  if (item.source === 'pot_allocation') {
    return [potAllocationCostToTodoItem(item, snapshot, payPeriod, today)]
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
    return [linkedCreditCardPotCostToTodoItem(item, snapshot, payPeriod, today)]
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
    breakdownLines: [
      {
        id: `breakdown-${allocation.id}`,
        label: payment?.name ?? potName,
        detail: `Recurring reserve into ${potName} pot`,
        amountPence: allocation.amountPence,
      },
    ],
  }
}

function recurringCostToTodoItem(
  item: PeriodCostItem,
  snapshot: PlannerSnapshot,
  payPeriod: PayPeriod,
): PaycheckTodoItem {
  if (item.creditCardId) {
    return cardChargeCostToTodoItem(item, snapshot, 'Recurring card charge')
  }

  const completion = item.potId
    ? createPaycheckPotCompletion({
        payPeriod,
        potId: item.potId,
        amountPence: item.amountPence,
        costItemId: item.id,
      })
    : undefined

  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: item.label,
    label: item.potId
      ? `Set aside ${formatPence(item.amountPence)} into "${getPotName(snapshot, item.potId)}" pot for "${item.label}"`
      : `Pay ${formatPence(item.amountPence)} for "${item.label}"`,
    detail: `Recurring bill due ${item.date}`,
    amountPence: item.amountPence,
    breakdownLines: [periodCostItemToBreakdownLine(item, item.potId ? `${getPotName(snapshot, item.potId)} pot` : 'Recurring bill')],
    completion,
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
    breakdownLines: [periodCostItemToBreakdownLine(item, 'Saved payment')],
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
    breakdownLines: [periodCostItemToBreakdownLine(item, item.potId ? `${getPotName(snapshot, item.potId)} pot spend` : 'Logged spend')],
  }
}

function potAllocationCostToTodoItem(
  item: PeriodCostItem,
  snapshot: PlannerSnapshot,
  payPeriod: PayPeriod,
  today: string,
): PaycheckTodoItem {
  const sourceCostItemId = getCostItemIdFromDashboardTodoPeriodCostItemId(item.id, payPeriod.id)
  const todoId = sourceCostItemId ? `${sourceCostItemId}-todo` : `${item.id}-todo`
  const linkedCreditCardId = sourceCostItemId
    ? getCreditCardIdFromLinkedCreditCardPotCostItemId(sourceCostItemId)
    : null
  const completion = sourceCostItemId && item.potId
    ? createPaycheckPotCompletion({
        payPeriod,
        potId: item.potId,
        amountPence: item.amountPence,
        costItemId: sourceCostItemId,
      })
    : undefined

  if (sourceCostItemId && linkedCreditCardId && item.potId) {
    const cardName = getCardName(snapshot, linkedCreditCardId)
    const isAdditionalCover = isAdditionalLinkedCreditCardPotCostItemId(sourceCostItemId)
    const breakdownLabel = isAdditionalCover
      ? `${cardName} additional planned card cover`
      : `${cardName} planned card cover`
    const allocation = item.id.startsWith('pot-allocation-')
      ? snapshot.potAllocations.find((candidate) => candidate.id === item.id.slice('pot-allocation-'.length))
      : null
    const previousAllocation = isAdditionalCover
      ? allocation
        ? getPreviousCompletedLinkedCreditCardPotAllocation(
            snapshot.potAllocations,
            payPeriod.id,
            linkedCreditCardId,
            allocation,
          ) ?? getCompletedLinkedCreditCardPotAllocation(snapshot.potAllocations, payPeriod.id, linkedCreditCardId)
        : getCompletedLinkedCreditCardPotAllocation(snapshot.potAllocations, payPeriod.id, linkedCreditCardId)
      : null
    const breakdownLines = isAdditionalCover && previousAllocation
      ? mapLinkedCreditCardPotCoverBreakdownLines(
          sourceCostItemId,
          getAdditionalLinkedCreditCardPotCoverBreakdown({
            recurringPayments: snapshot.recurringPayments,
            customPayments: snapshot.customPayments,
            transactions: snapshot.transactions,
            payPeriod,
            creditCardId: linkedCreditCardId,
            amountPence: item.amountPence,
            completedAllocation: previousAllocation,
          }),
        )
      : getLinkedCreditCardPotBreakdownLines(
          {
            ...item,
            id: sourceCostItemId,
            label: `${cardName} planned card cover`,
            source: 'linked_credit_card_pot',
            creditCardId: linkedCreditCardId,
          },
          snapshot,
          payPeriod,
          today,
          getLinkedCreditCardPotAllocationExclusionPence(
            snapshot.potAllocations,
            payPeriod.id,
            item.potId,
            item.createdAt,
          ) || item.amountPence,
          item.createdAt ?? undefined,
        )

    return {
      id: todoId,
      ignoreId: item.id,
      ignoreLabel: cardName,
      label: `Set aside ${formatPence(item.amountPence)} into "${getPotName(snapshot, item.potId)}" pot for "${cardName}" planned card cover`,
      detail: 'Moved into this pot from the dashboard checklist',
      amountPence: item.amountPence,
      breakdownLabel,
      breakdownLines,
      completion,
    }
  }

  return {
    id: todoId,
    ignoreId: item.id,
    ignoreLabel: item.label,
    label: `Set aside ${formatPence(item.amountPence)} into "${getPotName(snapshot, item.potId)}" pot`,
    detail: sourceCostItemId
      ? 'Moved into this pot from the dashboard checklist'
      : item.label.toLowerCase().includes('payday top-up')
        ? 'Automatic payday top-up'
        : 'Manual pot allocation',
    amountPence: item.amountPence,
    breakdownLines: [
      periodCostItemToBreakdownLine(
        item,
        sourceCostItemId
          ? 'Moved from dashboard checklist'
          : item.label.toLowerCase().includes('payday top-up')
            ? 'Automatic payday top-up'
            : 'Manual pot allocation',
      ),
    ],
    completion,
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
    breakdownLines: [periodCostItemToBreakdownLine(item, reserve?.note || 'Debt reserve')],
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
    breakdownLines: [periodCostItemToBreakdownLine(item, 'Debt due this pay period')],
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
    breakdownLines: [periodCostItemToBreakdownLine(item, creditCardPot?.note || 'Card pot reserve')],
  }
}

function linkedCreditCardPotCostToTodoItem(
  item: PeriodCostItem,
  snapshot: PlannerSnapshot,
  payPeriod: PayPeriod,
  today: string,
): PaycheckTodoItem {
  const cardName = getCardName(snapshot, item.creditCardId)
  const isAdditionalCover = Boolean(item.coverBreakdown)
  const breakdownLabel = isAdditionalCover
    ? `${cardName} additional planned card cover`
    : `${cardName} planned card cover`

  return {
    id: `${item.id}-todo`,
    ignoreId: item.id,
    ignoreLabel: cardName,
    label: `Set aside ${formatPence(item.amountPence)} into "${getPotName(snapshot, item.potId)}" pot for "${cardName}" planned card cover`,
    detail: isAdditionalCover
      ? 'New card costs after the previous checklist cover was completed'
      : 'Current shortfall plus planned card charges before next payday',
    amountPence: item.amountPence,
    breakdownLabel,
    breakdownLines: getLinkedCreditCardPotBreakdownLines(item, snapshot, payPeriod, today),
    completion: item.potId
      ? createPaycheckPotCompletion({
          payPeriod,
          potId: item.potId,
          amountPence: item.amountPence,
          costItemId: item.id,
        })
      : undefined,
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
    breakdownLines: [periodCostItemToBreakdownLine(item, detail)],
  }
}

function periodCostItemToBreakdownLine(item: PeriodCostItem, detail: string): PaycheckTodoBreakdownLine {
  return {
    id: `breakdown-${item.id}`,
    label: item.label,
    detail: `${detail} · ${item.date}`,
    amountPence: item.amountPence,
  }
}

function getLinkedCreditCardPotBreakdownLines(
  item: PeriodCostItem,
  snapshot: PlannerSnapshot,
  payPeriod: PayPeriod,
  today: string,
  excludedLinkedPotAllocationPence = 0,
  createdBeforeOrAt?: string,
): PaycheckTodoBreakdownLine[] {
  const additionalCoverPence = getAdditionalLinkedCreditCardPotAllocationPence(
    snapshot.potAllocations,
    payPeriod.id,
    item.potId,
    item.creditCardId ?? '',
  )
  const coveredManualSpendIds = getCoveredAdditionalLinkedCardManualSpendTransactionIds(
    snapshot.transactions,
    payPeriod,
    item.creditCardId ?? '',
    additionalCoverPence,
  )
  const historicalExcludedLinkedPotAllocationPence = createdBeforeOrAt
    ? Math.max(excludedLinkedPotAllocationPence, item.amountPence + additionalCoverPence)
    : excludedLinkedPotAllocationPence
  const breakdownSnapshot = createdBeforeOrAt
    ? filterSnapshotForHistoricalAllocation(snapshot, createdBeforeOrAt, coveredManualSpendIds)
    : snapshot
  const lines = item.coverBreakdown ?? getLinkedCreditCardPotCoverBreakdown({
    creditCards: breakdownSnapshot.creditCards,
    recurringPayments: breakdownSnapshot.recurringPayments,
    customPayments: breakdownSnapshot.customPayments,
    transactions: breakdownSnapshot.transactions,
    repayments: breakdownSnapshot.creditCardRepayments,
    creditCardPots: breakdownSnapshot.creditCardPots,
    pots: breakdownSnapshot.pots,
    payPeriod,
    creditCardId: item.creditCardId ?? '',
    linkedPotId: item.potId,
    amountPence: item.amountPence,
    excludedLinkedPotAllocationPence: historicalExcludedLinkedPotAllocationPence,
    asOfDate: today,
  })

  return lines.map((line) => ({
    id: `breakdown-${item.id}-${line.id}`,
    label: line.label,
    detail: line.detail,
    amountPence: line.amountPence,
  }))
}

function mapLinkedCreditCardPotCoverBreakdownLines(
  itemId: string,
  lines: ReturnType<typeof getLinkedCreditCardPotCoverBreakdown>,
): PaycheckTodoBreakdownLine[] {
  return lines.map((line) => ({
    id: `breakdown-${itemId}-${line.id}`,
    label: line.label,
    detail: line.detail,
    amountPence: line.amountPence,
  }))
}

function filterSnapshotForHistoricalAllocation(
  snapshot: PlannerSnapshot,
  cutoffTimestamp: string,
  excludedTransactionIds: Set<string>,
): PlannerSnapshot {
  return {
    ...snapshot,
    recurringPayments: snapshot.recurringPayments.filter((payment) => payment.createdAt <= cutoffTimestamp),
    customPayments: snapshot.customPayments.filter((payment) => payment.createdAt <= cutoffTimestamp),
    transactions: snapshot.transactions.filter(
      (transaction) => transaction.createdAt <= cutoffTimestamp && !excludedTransactionIds.has(transaction.id),
    ),
    creditCardRepayments: snapshot.creditCardRepayments.filter((repayment) => repayment.createdAt <= cutoffTimestamp),
  }
}

function createPaycheckPotCompletion({
  payPeriod,
  potId,
  amountPence,
  costItemId,
}: {
  payPeriod: PayPeriod
  potId: string
  amountPence: number
  costItemId: string
}): PaycheckTodoCompletion {
  return {
    type: 'pot_allocation',
    id: getDashboardTodoAllocationId(payPeriod.id, costItemId),
    payPeriodId: payPeriod.id,
    potId,
    amountPence,
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
