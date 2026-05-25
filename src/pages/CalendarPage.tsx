import { useEffect, useMemo, useState } from 'react'
import { clsx } from 'clsx'
import {
  Banknote,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  CreditCard,
  PiggyBank,
  ReceiptText,
  Repeat2,
  ShieldCheck,
  WalletCards,
} from 'lucide-react'

import {
  addIsoDays,
  findPayPeriodForDate,
  formatPence,
  getDebtDueAmountAfterReservesAndLinkedPotsPence,
  getPayPeriodCostSummary,
  getRecurringPaymentOccurrences,
  toIsoDate,
} from '../domain/money'
import type { PlannerSnapshot } from '../hooks/usePlannerData'
import type { PayPeriod } from '../types/models'
import { Button, Panel, SectionGrid } from '../components/ui'

type CalendarEventType =
  | 'payday'
  | 'recurring'
  | 'subscription'
  | 'insurance'
  | 'saved'
  | 'card'
  | 'debt'
  | 'debtReserve'
  | 'debtPayment'
  | 'cardRepayment'
  | 'creditCardPot'
  | 'allocation'
  | 'spending'

type CalendarEventDirection = 'in' | 'out' | 'info'

interface CalendarEvent {
  id: string
  date: string
  title: string
  amountPence: number
  type: CalendarEventType
  direction: CalendarEventDirection
  description: string
}

const eventStyles: Record<CalendarEventType, { label: string; className: string; icon: typeof CalendarDays }> = {
  payday: {
    label: 'Payday',
    className: 'border-emerald-200 bg-emerald-50 text-emerald-800',
    icon: Banknote,
  },
  recurring: {
    label: 'Recurring',
    className: 'border-indigo-200 bg-indigo-50 text-indigo-800',
    icon: Repeat2,
  },
  subscription: {
    label: 'Subscription',
    className: 'border-violet-200 bg-violet-50 text-violet-800',
    icon: Repeat2,
  },
  insurance: {
    label: 'Insurance',
    className: 'border-sky-200 bg-sky-50 text-sky-800',
    icon: ShieldCheck,
  },
  saved: {
    label: 'Saved payment',
    className: 'border-amber-200 bg-amber-50 text-amber-800',
    icon: CalendarDays,
  },
  card: {
    label: 'Card due',
    className: 'border-blue-200 bg-blue-50 text-blue-800',
    icon: CreditCard,
  },
  debt: {
    label: 'Debt due',
    className: 'border-red-200 bg-red-50 text-red-800',
    icon: CreditCard,
  },
  debtReserve: {
    label: 'Debt reserve',
    className: 'border-fuchsia-200 bg-fuchsia-50 text-fuchsia-800',
    icon: PiggyBank,
  },
  debtPayment: {
    label: 'Debt payment',
    className: 'border-rose-200 bg-rose-50 text-rose-800',
    icon: ReceiptText,
  },
  cardRepayment: {
    label: 'Card repayment',
    className: 'border-cyan-200 bg-cyan-50 text-cyan-800',
    icon: CreditCard,
  },
  creditCardPot: {
    label: 'Credit pot',
    className: 'border-lime-200 bg-lime-50 text-lime-800',
    icon: PiggyBank,
  },
  allocation: {
    label: 'Pot allocation',
    className: 'border-teal-200 bg-teal-50 text-teal-800',
    icon: PiggyBank,
  },
  spending: {
    label: 'Manual spend',
    className: 'border-pink-200 bg-pink-50 text-pink-800',
    icon: WalletCards,
  },
}

export function CalendarPage({
  snapshot,
  selectedPayPeriod,
}: {
  snapshot: PlannerSnapshot
  selectedPayPeriod?: PayPeriod | null
}) {
  const [visibleMonth, setVisibleMonth] = useState(() =>
    startOfMonth(selectedPayPeriod ? parseIsoDate(selectedPayPeriod.startDate) : new Date()),
  )
  const [selectedDate, setSelectedDate] = useState<string | null>(null)
  const monthStart = toIsoDate(visibleMonth)
  const monthEnd = toIsoDate(new Date(Date.UTC(visibleMonth.getUTCFullYear(), visibleMonth.getUTCMonth() + 1, 0)))
  const monthCells = useMemo(() => getMonthCells(visibleMonth), [visibleMonth])
  const gridStart = monthCells[0]?.date ?? monthStart
  const gridEnd = monthCells[monthCells.length - 1]?.date ?? monthEnd
  const events = useMemo(
    () => getCalendarEvents(snapshot, gridStart, gridEnd),
    [gridEnd, gridStart, snapshot],
  )
  const selectedDayEvents = useMemo(
    () => (selectedDate ? getCalendarEvents(snapshot, selectedDate, selectedDate) : []),
    [selectedDate, snapshot],
  )
  const eventsByDate = useMemo(() => groupEventsByDate(events), [events])
  const selectedDayPayPeriod = selectedDate ? findPayPeriodForDate(snapshot.payPeriods, selectedDate) : null

  useEffect(() => {
    if (!selectedDate || typeof window.scrollTo !== 'function') {
      return
    }

    if (window.navigator.userAgent.toLowerCase().includes('jsdom')) {
      return
    }

    try {
      window.scrollTo({ top: 0, behavior: 'auto' })
    } catch {
      window.scrollTo(0, 0)
    }
  }, [selectedDate])

  function changeMonth(delta: number) {
    setVisibleMonth(
      new Date(Date.UTC(visibleMonth.getUTCFullYear(), visibleMonth.getUTCMonth() + delta, 1)),
    )
  }

  function selectDate(date: string) {
    setSelectedDate(date)
    setVisibleMonth(startOfMonth(parseIsoDate(date)))
  }

  if (selectedDate) {
    return (
      <CalendarDayDetails
        date={selectedDate}
        events={selectedDayEvents}
        payPeriod={selectedDayPayPeriod}
        snapshot={snapshot}
        onBack={() => setSelectedDate(null)}
        onSelectDate={selectDate}
      />
    )
  }

  return (
    <div className="space-y-6">
      <Panel
        title={formatMonth(visibleMonth)}
        description={
          selectedPayPeriod
            ? `Selected period ${selectedPayPeriod.startDate} to ${selectedPayPeriod.endDate}. Click any day for details.`
            : 'Pay, payments, cards, debts, reserves, and spending signals.'
        }
        accent="violet"
        density="compact"
        action={
          <div className="flex gap-2">
            <Button variant="secondary" onClick={() => changeMonth(-1)} aria-label="Previous month">
              <ChevronLeft size={18} />
            </Button>
            <Button variant="secondary" onClick={() => setVisibleMonth(startOfMonth(new Date()))}>
              Today
            </Button>
            <Button variant="secondary" onClick={() => changeMonth(1)} aria-label="Next month">
              <ChevronRight size={18} />
            </Button>
          </div>
        }
      >
        <div className="mb-2 flex flex-nowrap gap-1.5 overflow-x-auto pb-1">
          {Object.entries(eventStyles).map(([type, style]) => {
            const Icon = style.icon

            return (
              <span key={type} className={`inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-[11px] font-semibold ${style.className}`}>
                <Icon size={12} />
                {style.label}
              </span>
            )
          })}
        </div>

        <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white">
          <div className="grid min-w-[680px] grid-cols-7">
            {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) => (
              <div key={day} className="border-b border-slate-200 bg-slate-50 px-2 py-1.5 text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                {day}
              </div>
            ))}
            {monthCells.map((cell) => {
              const dayEvents = eventsByDate.get(cell.date) ?? []
              const isCurrentMonth = cell.date >= monthStart && cell.date <= monthEnd
              const isToday = cell.date === toIsoDate(new Date())
              const isSelectedPeriodDay = selectedPayPeriod
                ? cell.date >= selectedPayPeriod.startDate && cell.date <= selectedPayPeriod.endDate
                : false
              const dayCostPence = dayEvents
                .filter((event) => event.direction === 'out')
                .reduce((total, event) => total + event.amountPence, 0)

              return (
                <button
                  key={cell.date}
                  type="button"
                  onClick={() => selectDate(cell.date)}
                  aria-label={`Open ${formatDateForAria(cell.date)}`}
                  className={clsx(
                    'group min-h-[58px] border-b border-r p-1 text-left transition focus-visible:relative focus-visible:z-10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-slate-950',
                    isSelectedPeriodDay
                      ? 'border-slate-200 bg-slate-50 hover:bg-slate-100'
                      : isCurrentMonth
                        ? 'border-slate-100 bg-white hover:bg-slate-50'
                        : 'border-slate-100 bg-slate-50 text-slate-400 hover:bg-slate-100',
                  )}
                >
                  <div className="mb-1 flex items-center justify-between gap-2">
                    <span
                      className={
                        isToday
                          ? 'flex size-6 items-center justify-center rounded-full bg-slate-950 text-[11px] font-semibold text-white'
                          : 'text-[11px] font-semibold text-slate-500'
                      }
                    >
                      {Number(cell.date.slice(-2))}
                    </span>
                    {dayEvents.length > 0 && (
                      <span className="rounded-full bg-slate-900 px-1.5 py-0.5 text-[10px] font-semibold text-white">
                        {dayEvents.length}
                      </span>
                    )}
                  </div>
                  {dayCostPence > 0 && (
                    <p className="mb-0.5 truncate text-[10px] font-semibold text-slate-600">{formatPence(dayCostPence)} out</p>
                  )}
                  <div className="space-y-0.5">
                    {dayEvents.slice(0, 1).map((event) => {
                      const Icon = eventStyles[event.type].icon

                      return (
                        <div
                          key={event.id}
                          className={`rounded-md border px-1.5 py-0.5 ${eventStyles[event.type].className}`}
                          title={`${event.title} ${formatPence(event.amountPence)}`}
                        >
                          <div className="flex items-center gap-1">
                            <Icon className="shrink-0" size={11} />
                            <span className="min-w-0 truncate text-[10px] font-semibold">{event.title}</span>
                          </div>
                        </div>
                      )
                    })}
                    {dayEvents.length > 1 && (
                      <p className="rounded-md bg-slate-100 px-1.5 py-0.5 text-[10px] font-semibold text-slate-600">
                        +{dayEvents.length - 1} more
                      </p>
                    )}
                  </div>
                </button>
              )
            })}
          </div>
        </div>
      </Panel>
    </div>
  )
}

function CalendarDayDetails({
  date,
  events,
  payPeriod,
  snapshot,
  onBack,
  onSelectDate,
}: {
  date: string
  events: CalendarEvent[]
  payPeriod: PayPeriod | null
  snapshot: PlannerSnapshot
  onBack: () => void
  onSelectDate: (date: string) => void
}) {
  const moneyInPence = events
    .filter((event) => event.direction === 'in')
    .reduce((total, event) => total + event.amountPence, 0)
  const moneyOutPence = events
    .filter((event) => event.direction === 'out')
    .reduce((total, event) => total + event.amountPence, 0)
  const infoCount = events.filter((event) => event.direction === 'info').length
  const netPence = moneyInPence - moneyOutPence
  const costSummary = payPeriod
    ? getPayPeriodCostSummary({
        payPeriod,
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
    : null

  return (
    <div className="space-y-6" aria-label={`Calendar day ${date}`}>
      <section className="overflow-hidden rounded-lg border border-slate-900 bg-slate-950 shadow-sm">
        <div className="grid gap-6 p-5 text-white lg:grid-cols-[1fr_auto] lg:items-center">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-300">Day overview</p>
            <h2 className="mt-2 text-3xl font-semibold">{formatDayHeading(date)}</h2>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
              Everything tied to this day, including pay, due costs, debt reserves, repayments, pot allocations, and manual spending.
            </p>
          </div>
          <div className="flex flex-wrap gap-2 lg:justify-end">
            <Button variant="secondary" onClick={() => onSelectDate(addIsoDays(date, -1))}>
              <ChevronLeft size={18} />
              Previous day
            </Button>
            <Button variant="secondary" onClick={() => onSelectDate(addIsoDays(date, 1))}>
              Next day
              <ChevronRight size={18} />
            </Button>
            <Button variant="secondary" onClick={onBack}>Back to calendar</Button>
          </div>
        </div>
      </section>

      <div className="grid gap-4 md:grid-cols-4">
        <DayMetric label="Money in" value={formatPence(moneyInPence)} tone="good" />
        <DayMetric label="Money out" value={formatPence(moneyOutPence)} tone={moneyOutPence > 0 ? 'warning' : 'neutral'} />
        <DayMetric label="Net day" value={formatSignedPence(netPence)} tone={netPence >= 0 ? 'good' : 'bad'} />
        <DayMetric label="Info items" value={String(infoCount)} tone="neutral" />
      </div>

      <SectionGrid variant="wideLeft">
        <Panel
          title="Timeline"
          description={events.length > 0 ? `${events.length} calendar item${events.length === 1 ? '' : 's'} on this day.` : 'No saved activity is attached to this date yet.'}
          accent="violet"
          density="compact"
        >
          {events.length === 0 ? (
            <div className="rounded-lg border border-dashed border-slate-200 bg-slate-50 p-6 text-center">
              <p className="text-sm font-semibold text-slate-950">Nothing scheduled</p>
              <p className="mt-1 text-sm text-slate-500">No paycheck, debt, saved payment, recurring payment, repayment, reserve, allocation, or spend is linked to this day.</p>
            </div>
          ) : (
            <div className="space-y-3">
              {events.map((event) => (
                <CalendarDayEventCard key={event.id} event={event} />
              ))}
            </div>
          )}
        </Panel>

        <Panel
          title="Pay period context"
          description={payPeriod ? `${payPeriod.startDate} to ${payPeriod.endDate}` : 'No saved pay period covers this date.'}
          accent="blue"
          density="compact"
        >
          {payPeriod && costSummary ? (
            <div className="space-y-3">
              <div className="rounded-lg border border-slate-200 bg-slate-50 p-4">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Paycheck</p>
                <p className="mt-2 text-2xl font-semibold text-slate-950">{formatPence(payPeriod.incomePence)}</p>
                <p className="mt-1 text-xs text-slate-500">Payday {payPeriod.payday}</p>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                <CompactMoneyLine label="Period costs" value={formatPence(costSummary.totalCostsPence)} />
                <CompactMoneyLine label="Money left" value={formatPence(costSummary.moneyLeftPence)} emphasized={costSummary.moneyLeftPence >= 0} />
                <CompactMoneyLine label="Debt reserves" value={formatPence(costSummary.debtReservesPence)} />
                <CompactMoneyLine label="Debt due" value={formatPence(costSummary.debtMinimumsPence)} />
              </div>
            </div>
          ) : (
            <div className="rounded-lg border border-slate-200 bg-slate-50 p-4">
              <p className="text-sm font-semibold text-slate-950">No pay period found</p>
              <p className="mt-1 text-sm leading-5 text-slate-500">Create or select a paycheck period if you want this date included in dashboard calculations.</p>
            </div>
          )}
        </Panel>
      </SectionGrid>
    </div>
  )
}

function CalendarDayEventCard({ event }: { event: CalendarEvent }) {
  const style = eventStyles[event.type]
  const Icon = style.icon

  return (
    <article className="grid gap-3 rounded-lg border border-slate-200 bg-white p-4 shadow-sm sm:grid-cols-[auto_1fr_auto] sm:items-center">
      <div className={`flex size-11 items-center justify-center rounded-lg border ${style.className}`}>
        <Icon size={19} />
      </div>
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="font-semibold text-slate-950">{event.title}</h3>
          <span className={`rounded-md border px-2 py-0.5 text-xs font-semibold ${style.className}`}>
            {style.label}
          </span>
        </div>
        <p className="mt-1 text-sm leading-5 text-slate-500">{event.description}</p>
      </div>
      <p className={clsx(
        'text-lg font-semibold',
        event.direction === 'in' && 'text-emerald-700',
        event.direction === 'out' && 'text-red-700',
        event.direction === 'info' && 'text-slate-500',
      )}
      >
        {formatEventAmount(event)}
      </p>
    </article>
  )
}

function DayMetric({
  label,
  value,
  tone,
}: {
  label: string
  value: string
  tone: 'neutral' | 'good' | 'warning' | 'bad'
}) {
  return (
    <div
      className={clsx(
        'rounded-lg border p-4 shadow-sm',
        tone === 'neutral' && 'border-slate-200 bg-white',
        tone === 'good' && 'border-emerald-200 bg-emerald-50',
        tone === 'warning' && 'border-amber-200 bg-amber-50',
        tone === 'bad' && 'border-red-200 bg-red-50',
      )}
    >
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-2 text-2xl font-semibold text-slate-950">{value}</p>
    </div>
  )
}

function CompactMoneyLine({
  label,
  value,
  emphasized = false,
}: {
  label: string
  value: string
  emphasized?: boolean
}) {
  return (
    <div className={clsx('flex items-center justify-between gap-3 rounded-lg border p-3', emphasized ? 'border-emerald-200 bg-emerald-50' : 'border-slate-200 bg-white')}>
      <p className="text-sm font-medium text-slate-600">{label}</p>
      <p className="text-sm font-semibold text-slate-950">{value}</p>
    </div>
  )
}

function getCalendarEvents(snapshot: PlannerSnapshot, startDate: string, endDate: string): CalendarEvent[] {
  const potById = new Map(snapshot.pots.map((pot) => [pot.id, pot]))
  const debtById = new Map(snapshot.debts.map((debt) => [debt.id, debt]))
  const cardById = new Map(snapshot.creditCards.map((card) => [card.id, card]))
  const periodById = new Map(snapshot.payPeriods.map((period) => [period.id, period]))
  const savedPaydays = new Set(snapshot.payPeriods.map((period) => period.payday))
  const recurringEvents: CalendarEvent[] = getRecurringPaymentOccurrences(snapshot.recurringPayments, startDate, endDate).map(
    (occurrence) => {
      const card = occurrence.payment.creditCardId ? cardById.get(occurrence.payment.creditCardId) : null

      return {
        id: `recurring-${occurrence.payment.id}-${occurrence.dueDate}`,
        date: occurrence.dueDate,
        title: occurrence.payment.name,
        amountPence: occurrence.amountPence,
        type: getRecurringCalendarType(occurrence.payment.name),
        direction: 'out',
        description: `${occurrence.payment.frequency} payment${card ? ` charged to ${card.name}` : ''}.`,
      }
    },
  )
  const savedEvents: CalendarEvent[] = snapshot.customPayments
    .filter((payment) => payment.status !== 'archived' && payment.dueDate >= startDate && payment.dueDate <= endDate)
    .map((payment) => {
      const card = payment.creditCardId ? cardById.get(payment.creditCardId) : null

      return {
        id: `saved-${payment.id}`,
        date: payment.dueDate,
        title: payment.name,
        amountPence: payment.amountPence,
        type: 'saved',
        direction: 'out',
        description: `${payment.status === 'paid' ? 'Paid' : 'Unpaid'} saved payment${card ? ` linked to ${card.name}` : ''}.`,
      }
    })
  const paydayEvents: CalendarEvent[] = snapshot.payPeriods.flatMap((period) => {
    const eventsForPeriod: CalendarEvent[] = []

    if (period.payday >= startDate && period.payday <= endDate) {
      eventsForPeriod.push({
        id: `payday-${period.id}-${period.payday}`,
        date: period.payday,
        title: 'Paycheck received',
        amountPence: period.incomePence,
        type: 'payday',
        direction: 'in',
        description: `Pay period ${period.startDate} to ${period.endDate}.`,
      })
    }

    if (period.nextPayday >= startDate && period.nextPayday <= endDate && !savedPaydays.has(period.nextPayday)) {
      eventsForPeriod.push({
        id: `next-payday-${period.id}-${period.nextPayday}`,
        date: period.nextPayday,
        title: 'Next payday starts',
        amountPence: 0,
        type: 'payday',
        direction: 'info',
        description: `Next paycheck date after the ${period.startDate} to ${period.endDate} period.`,
      })
    }

    return eventsForPeriod
  })
  const cardEvents: CalendarEvent[] = snapshot.creditCards
    .filter((card) => !card.archived)
    .flatMap((card) => getCardDueDates(card.dueDay ?? null, card.dueDate ?? null, startDate, endDate).map((date) => ({
      id: `card-${card.id}-${date}`,
      date,
      title: card.name,
      amountPence: 0,
      type: 'card' as const,
      direction: 'info' as const,
      description: `${card.provider || 'Credit card'} due date. Limit ${formatPence(card.limitPence)}.`,
    })))
  const debtEvents: CalendarEvent[] = snapshot.debts
    .filter((debt) => debt.status === 'active' && debt.dueDate >= startDate && debt.dueDate <= endDate)
    .map((debt) => ({
      id: `debt-${debt.id}`,
      date: debt.dueDate,
      title: debt.name,
      amountPence: getDebtDueAmountAfterReservesAndLinkedPotsPence(debt, snapshot.debtReserves, snapshot.pots),
      type: 'debt' as const,
      direction: 'out' as const,
      description: `${debt.lender || 'Debt'} due date. Linked pots and planned reserves reduce the amount still to cover.`,
    }))
  const reserveEvents: CalendarEvent[] = snapshot.debtReserves
    .filter((reserve) => reserve.status !== 'cancelled' && reserve.payday >= startDate && reserve.payday <= endDate)
    .map((reserve) => {
      const debt = debtById.get(reserve.debtId)
      const isPlanned = reserve.status === 'planned'

      return {
        id: `debt-reserve-${reserve.id}`,
        date: reserve.payday,
        title: debt ? `${debt.name} reserve` : 'Debt reserve',
        amountPence: reserve.amountPence,
        type: 'debtReserve' as const,
        direction: isPlanned ? 'out' as const : 'info' as const,
        description: `${reserve.status} reserve for ${reserve.periodStartDate} to ${reserve.periodEndDate}${reserve.note ? ` · ${reserve.note}` : ''}.`,
      }
    })
  const debtPaymentEvents: CalendarEvent[] = snapshot.debtPayments
    .filter((payment) => payment.date >= startDate && payment.date <= endDate)
    .map((payment) => {
      const debt = debtById.get(payment.debtId)

      return {
        id: `debt-payment-${payment.id}`,
        date: payment.date,
        title: debt ? `${debt.name} payment` : 'Debt payment',
        amountPence: payment.amountPence,
        type: 'debtPayment' as const,
        direction: 'out' as const,
        description: payment.note || 'Recorded debt payment.',
      }
    })
  const cardRepaymentEvents: CalendarEvent[] = snapshot.creditCardRepayments
    .filter((repayment) => repayment.date >= startDate && repayment.date <= endDate)
    .map((repayment) => {
      const card = cardById.get(repayment.creditCardId)

      return {
        id: `card-repayment-${repayment.id}`,
        date: repayment.date,
        title: card ? `${card.name} repayment` : 'Card repayment',
        amountPence: repayment.amountPence,
        type: 'cardRepayment' as const,
        direction: 'out' as const,
        description: repayment.note || 'Recorded credit card repayment.',
      }
    })
  const creditCardPotEvents: CalendarEvent[] = snapshot.creditCardPots
    .filter((creditCardPot) => {
      const date = creditCardPot.payday ?? creditCardPot.createdAt.slice(0, 10)

      return creditCardPot.status === 'active' && date >= startDate && date <= endDate
    })
    .map((creditCardPot) => {
      const card = cardById.get(creditCardPot.creditCardId)
      const date = creditCardPot.payday ?? creditCardPot.createdAt.slice(0, 10)

      return {
        id: `credit-card-pot-${creditCardPot.id}`,
        date,
        title: creditCardPot.name,
        amountPence: creditCardPot.amountPence,
        type: 'creditCardPot' as const,
        direction: creditCardPot.source === 'paycheck' ? 'out' as const : 'info' as const,
        description: `${creditCardPot.source === 'paycheck' ? 'Paycheck-funded' : 'External'} set-aside for ${card?.name ?? 'credit card'}${creditCardPot.note ? ` · ${creditCardPot.note}` : ''}.`,
      }
    })
  const allocationEvents: CalendarEvent[] = snapshot.potAllocations
    .flatMap((allocation): CalendarEvent[] => {
      const period = periodById.get(allocation.payPeriodId)
      const pot = potById.get(allocation.potId)

      if (!period || period.payday < startDate || period.payday > endDate) {
        return []
      }

      return [{
        id: `allocation-${allocation.id}`,
        date: period.payday,
        title: pot
          ? allocation.source === 'pot_auto'
            ? `${pot.name} payday top-up`
            : `${pot.name} allocation`
          : 'Pot allocation',
        amountPence: allocation.amountPence,
        type: 'allocation' as const,
        direction: allocation.source === 'recurring' ? 'info' as const : 'out' as const,
        description: `${allocation.source === 'recurring' ? 'Bill reserve' : allocation.source === 'pot_auto' ? 'Automatic payday top-up' : 'Manual allocation'} for ${period.startDate} to ${period.endDate}.`,
      }]
    })
  const spendingEvents: CalendarEvent[] = snapshot.transactions
    .filter(
      (transaction) =>
        transaction.type === 'spending' &&
        !transaction.recurringPaymentId &&
        transaction.date >= startDate &&
        transaction.date <= endDate,
    )
    .map((transaction) => {
      const card = transaction.creditCardId ? cardById.get(transaction.creditCardId) : null
      const pot = transaction.potId ? potById.get(transaction.potId) : null

      return {
        id: `spending-${transaction.id}`,
        date: transaction.date,
        title: transaction.note || 'Manual spend',
        amountPence: transaction.amountPence,
        type: 'spending' as const,
        direction: 'out' as const,
        description: card ? `Manual spend on ${card.name}.` : `Manual spend${pot ? ` from ${pot.name}` : ''}.`,
      }
    })

  return [
    ...paydayEvents,
    ...recurringEvents,
    ...savedEvents,
    ...cardEvents,
    ...debtEvents,
    ...reserveEvents,
    ...debtPaymentEvents,
    ...cardRepaymentEvents,
    ...creditCardPotEvents,
    ...allocationEvents,
    ...spendingEvents,
  ].sort((a, b) => {
    const dateSort = a.date.localeCompare(b.date)

    if (dateSort !== 0) {
      return dateSort
    }

    return getEventRank(a.type) - getEventRank(b.type)
  })
}

function getMonthCells(month: Date): Array<{ date: string }> {
  const firstDay = new Date(Date.UTC(month.getUTCFullYear(), month.getUTCMonth(), 1))
  const firstWeekday = (firstDay.getUTCDay() + 6) % 7
  const start = new Date(firstDay.getTime() - firstWeekday * 24 * 60 * 60 * 1000)

  return Array.from({ length: 42 }, (_, index) => ({
    date: toIsoDate(new Date(start.getTime() + index * 24 * 60 * 60 * 1000)),
  }))
}

function groupEventsByDate(events: CalendarEvent[]): Map<string, CalendarEvent[]> {
  const groups = new Map<string, CalendarEvent[]>()

  for (const event of events) {
    groups.set(event.date, [...(groups.get(event.date) ?? []), event])
  }

  return groups
}

function getRecurringCalendarType(name: string): CalendarEventType {
  const lowerName = name.toLowerCase()

  if (lowerName.includes('insurance') || lowerName.includes('insur')) {
    return 'insurance'
  }

  if (
    lowerName.includes('subscription') ||
    lowerName.includes('netflix') ||
    lowerName.includes('spotify') ||
    lowerName.includes('gym')
  ) {
    return 'subscription'
  }

  return 'recurring'
}

function getCardDueDates(
  dueDay: number | null,
  dueDate: string | null,
  startDate: string,
  endDate: string,
): string[] {
  if (dueDate) {
    return dueDate >= startDate && dueDate <= endDate ? [dueDate] : []
  }

  if (!dueDay) {
    return []
  }

  const start = new Date(`${startDate}T00:00:00.000Z`)
  const lastDay = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 0)).getUTCDate()
  const due = toIsoDate(new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), Math.min(dueDay, lastDay))))

  return due >= startDate && due <= endDate ? [due] : []
}

function getEventRank(type: CalendarEventType): number {
  const ranks: Record<CalendarEventType, number> = {
    payday: 0,
    insurance: 1,
    recurring: 2,
    subscription: 3,
    saved: 4,
    debtReserve: 5,
    card: 6,
    debt: 7,
    debtPayment: 8,
    cardRepayment: 9,
    creditCardPot: 10,
    allocation: 11,
    spending: 12,
  }

  return ranks[type]
}

function startOfMonth(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1))
}

function parseIsoDate(value: string): Date {
  return new Date(`${value}T00:00:00.000Z`)
}

function formatMonth(date: Date): string {
  return new Intl.DateTimeFormat('en-GB', {
    month: 'long',
    year: 'numeric',
  }).format(date)
}

function formatDayHeading(date: string): string {
  return new Intl.DateTimeFormat('en-GB', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(parseIsoDate(date))
}

function formatDateForAria(date: string): string {
  return new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(parseIsoDate(date))
}

function formatSignedPence(amountPence: number): string {
  if (amountPence > 0) {
    return `+${formatPence(amountPence)}`
  }

  if (amountPence < 0) {
    return `-${formatPence(Math.abs(amountPence))}`
  }

  return formatPence(0)
}

function formatEventAmount(event: CalendarEvent): string {
  if (event.amountPence <= 0) {
    return event.direction === 'info' ? 'Info' : formatPence(0)
  }

  if (event.direction === 'in') {
    return `+${formatPence(event.amountPence)}`
  }

  if (event.direction === 'out') {
    return `-${formatPence(event.amountPence)}`
  }

  return formatPence(event.amountPence)
}
