import type {
  CreditCard,
  CreditCardPot,
  CreditCardRepayment,
  CustomPayment,
  Debt,
  DebtPayment,
  DebtReserve,
  PayFrequency,
  PayPeriod,
  Pot,
  PotAllocation,
  RecurringPayment,
  Transaction,
  TransactionType,
} from '../types/models.js'

const dayMs = 24 * 60 * 60 * 1000

interface PaycheckInput {
  hoursWorked: number
  hourlyRatePence: number
  actualAmountPence?: number | null
}

interface AllocationBalanceInput {
  incomePence: number
  reservedPence: number
  allocationPence: number
}

export interface AllocationBalance {
  availableAfterReservedPence: number
  remainingPence: number
  isOverAllocated: boolean
}

export interface NextPayPeriod {
  startDate: string
  endDate: string
  nextPayday: string
}

export interface RecurringPaymentOccurrence {
  payment: RecurringPayment
  dueDate: string
  amountPence: number
}

export interface DebtSummary {
  activeDebtCount: number
  overdueDebtCount: number
  totalCurrentBalancePence: number
  totalOriginalAmountPence: number
  totalPaidPence: number
  debtDueThisPayPeriodPence: number
  progressPercent: number
}

interface PayPeriodMoneySummaryInput {
  incomePence: number
  duePayments: RecurringPayment[]
  allocations: Array<Pick<PotAllocation, 'potId' | 'amountPence' | 'recurringPaymentId'>>
}

interface PayPeriodCostSummaryInput {
  payPeriod: PayPeriod | null
  creditCards?: CreditCard[]
  recurringPayments: RecurringPayment[]
  customPayments: CustomPayment[]
  transactions: Transaction[]
  debts: Debt[]
  creditCardRepayments: CreditCardRepayment[]
  creditCardPots?: CreditCardPot[]
  debtReserves?: DebtReserve[]
  pots?: Pot[]
  potAllocations?: PotAllocation[]
}

export interface PayPeriodMoneySummary {
  payReceivedPence: number
  allocatedPence: number
  uncoveredRecurringPence: number
  totalPaymentsDuePence: number
  moneyLeftPence: number
  isOverCommitted: boolean
}

export type PeriodCostItemSource =
  | 'recurring'
  | 'saved_payment'
  | 'manual_spend'
  | 'pot_allocation'
  | 'debt_minimum'
  | 'debt_reserve'
  | 'credit_card_pot'
  | 'linked_credit_card_pot'
  | 'credit_card_repayment'

export interface PeriodCostItem {
  id: string
  label: string
  amountPence: number
  date: string
  source: PeriodCostItemSource
  creditCardId?: string | null
  potId?: string | null
}

export interface PayPeriodCostSummary {
  payReceivedPence: number
  directRecurringPence: number
  savedPaymentsPence: number
  manualSpendingPence: number
  potAllocationsPence: number
  debtMinimumsPence: number
  debtReservesPence: number
  creditCardPotsPence: number
  creditCardChargesPence: number
  creditCardRepaymentsPence: number
  creditCardNetPence: number
  totalCostsPence: number
  moneyLeftPence: number
  isOverCommitted: boolean
  items: PeriodCostItem[]
}

export function getDebtDueAmountPence(
  debt: Pick<Debt, 'currentBalancePence'>,
): number {
  return Math.max(0, debt.currentBalancePence)
}

export function getPlannedDebtReservePence(
  reserves: DebtReserve[],
  debtId?: string,
): number {
  return reserves
    .filter((reserve) => reserve.status === 'planned' && (!debtId || reserve.debtId === debtId))
    .reduce((total, reserve) => total + reserve.amountPence, 0)
}

export function getDebtDueAmountAfterReservesPence(
  debt: Pick<Debt, 'id' | 'currentBalancePence'>,
  reserves: DebtReserve[],
): number {
  return Math.max(0, getDebtDueAmountPence(debt) - getPlannedDebtReservePence(reserves, debt.id))
}

export function getLinkedCreditCardPotPence(
  pots: Pot[],
  creditCardId?: string | null,
): number {
  if (!creditCardId) {
    return 0
  }

  return pots
    .filter((pot) => !pot.archived && pot.linkedCreditCardId === creditCardId)
    .reduce((total, pot) => total + Math.max(0, pot.balancePence), 0)
}

export function getLinkedDebtPotPence(
  pots: Pot[],
  debtId?: string | null,
): number {
  if (!debtId) {
    return 0
  }

  return pots
    .filter((pot) => !pot.archived && pot.linkedDebtId === debtId)
    .reduce((total, pot) => total + Math.max(0, pot.balancePence), 0)
}

export function getDebtDueAmountAfterReservesAndLinkedPotsPence(
  debt: Pick<Debt, 'id' | 'currentBalancePence'>,
  reserves: DebtReserve[],
  pots: Pot[] = [],
): number {
  return Math.max(
    0,
    getDebtDueAmountAfterReservesPence(debt, reserves) - getLinkedDebtPotPence(pots, debt.id),
  )
}

interface CreditCardAllocationInput {
  creditCards: CreditCard[]
  recurringPayments: RecurringPayment[]
  customPayments: CustomPayment[]
  transactions: Transaction[]
  repayments: CreditCardRepayment[]
  creditCardPots?: CreditCardPot[]
  pots?: Pot[]
  payPeriod: PayPeriod | null
}

export interface CreditCardAllocationItem {
  id: string
  creditCardId: string | null
  potId?: string | null
  label: string
  amountPence: number
  date: string
  source: 'recurring' | 'custom' | 'spending' | 'repayment'
}

export interface CreditCardAllocationCardSummary {
  card: CreditCard
  openingBalancePence: number
  owedPence: number
  creditPotPence: number
  paycheckCreditPotPence: number
  externalCreditPotPence: number
  linkedPotPence: number
  remainingAfterCreditPotsPence: number
  availableCreditPence: number
  utilisationPercent: number
  dueLabel: string
  items: CreditCardAllocationItem[]
  balanceItems: CreditCardAllocationItem[]
}

export interface CreditCardAllocationSummary {
  cards: CreditCardAllocationCardSummary[]
  unlinkedItems: CreditCardAllocationItem[]
  totalOwedPence: number
  totalCreditPotsPence: number
  totalPaycheckCreditPotsPence: number
  totalExternalCreditPotsPence: number
  totalLinkedPotPence: number
  totalRemainingAfterCreditPotsPence: number
  payReceivedPence: number
  paycheckRemainingAfterCardsPence: number
}

export function calculatePaycheckAmount({
  hoursWorked,
  hourlyRatePence,
  actualAmountPence,
}: PaycheckInput): number {
  if (typeof actualAmountPence === 'number') {
    return Math.round(actualAmountPence)
  }

  return Math.round(hoursWorked * hourlyRatePence)
}

export function getAllocationBalance({
  incomePence,
  reservedPence,
  allocationPence,
}: AllocationBalanceInput): AllocationBalance {
  const availableAfterReservedPence = incomePence - reservedPence
  const remainingPence = availableAfterReservedPence - allocationPence

  return {
    availableAfterReservedPence,
    remainingPence,
    isOverAllocated: remainingPence < 0,
  }
}

export function applyTransactionToPot(
  pot: Pot,
  amountPence: number,
  type: TransactionType,
): Pot {
  const delta = type === 'spending' ? -Math.abs(amountPence) : amountPence

  return {
    ...pot,
    balancePence: pot.balancePence + delta,
    updatedAt: new Date().toISOString(),
  }
}

export function getPotBalanceAfterTransactionRemoval(
  pot: Pot,
  transaction: Pick<Transaction, 'amountPence' | 'type'>,
): number {
  if (transaction.type === 'spending') {
    return pot.balancePence + Math.abs(transaction.amountPence)
  }

  if (transaction.type === 'allocation') {
    return pot.balancePence - Math.abs(transaction.amountPence)
  }

  return pot.balancePence
}

export function createNextPayPeriod(payday: string, frequency: PayFrequency): NextPayPeriod {
  const start = parseDate(payday)
  const days = frequencyToDays(frequency)
  const nextPayday = addDays(start, days)
  const end = addDays(nextPayday, -1)

  return {
    startDate: toIsoDate(start),
    endDate: toIsoDate(end),
    nextPayday: toIsoDate(nextPayday),
  }
}

export function getRecurringPaymentsDue(
  payments: RecurringPayment[],
  startDate: string,
  endDate: string,
): RecurringPayment[] {
  const seenPaymentIds = new Set<string>()

  return getRecurringPaymentOccurrences(payments, startDate, endDate)
    .filter((occurrence) => {
      if (seenPaymentIds.has(occurrence.payment.id)) {
        return false
      }

      seenPaymentIds.add(occurrence.payment.id)
      return true
    })
    .map((occurrence) => occurrence.payment)
    .sort((a, b) => getPriorityRank(a.priority) - getPriorityRank(b.priority))
}

export function getRecurringPaymentOccurrences(
  payments: RecurringPayment[],
  startDate: string,
  endDate: string,
): RecurringPaymentOccurrence[] {
  const start = parseDate(startDate)
  const end = parseDate(endDate)

  return payments
    .filter((payment) => payment.active)
    .flatMap((payment) =>
      getRecurringPaymentDueDates(payment, start, end).map((dueDate) => ({
        payment,
        dueDate: toIsoDate(dueDate),
        amountPence: payment.amountPence,
      })),
    )
    .sort((a, b) => {
      const dateSort = a.dueDate.localeCompare(b.dueDate)

      if (dateSort !== 0) {
        return dateSort
      }

      return getPriorityRank(a.payment.priority) - getPriorityRank(b.payment.priority)
    })
}

export function getTotalPence(items: Array<{ amountPence: number }>): number {
  return items.reduce((total, item) => total + item.amountPence, 0)
}

export function getSpendablePence(pots: Pot[]): number {
  return pots
    .filter((pot) => !pot.archived && ['spending', 'buffer'].includes(pot.type))
    .reduce((total, pot) => total + pot.balancePence, 0)
}

export function getUncoveredRecurringPence(
  payments: RecurringPayment[],
  allocations: Array<Pick<PotAllocation, 'potId' | 'amountPence' | 'recurringPaymentId'>>,
): number {
  const directAllocationByPayment = new Map<string, number>()
  const remainingAllocationByPot = new Map<string, number>()

  for (const allocation of allocations) {
    if (allocation.recurringPaymentId) {
      directAllocationByPayment.set(
        allocation.recurringPaymentId,
        (directAllocationByPayment.get(allocation.recurringPaymentId) ?? 0) + allocation.amountPence,
      )
      continue
    }

    remainingAllocationByPot.set(
      allocation.potId,
      (remainingAllocationByPot.get(allocation.potId) ?? 0) + allocation.amountPence,
    )
  }

  return payments.reduce((total, payment) => {
    const directAvailablePence = directAllocationByPayment.get(payment.id) ?? 0
    const directCoveredPence = Math.min(
      payment.amountPence,
      directAvailablePence,
    )
    directAllocationByPayment.set(payment.id, directAvailablePence - directCoveredPence)
    const remainingPaymentPence = payment.amountPence - directCoveredPence

    if (remainingPaymentPence <= 0) {
      return total
    }

    if (!payment.potId) {
      return total + remainingPaymentPence
    }

    const availableInPot = remainingAllocationByPot.get(payment.potId) ?? 0
    const coveredPence = Math.min(remainingPaymentPence, availableInPot)
    remainingAllocationByPot.set(payment.potId, availableInPot - coveredPence)

    return total + remainingPaymentPence - coveredPence
  }, 0)
}

export function getPayPeriodMoneySummary({
  incomePence,
  duePayments,
  allocations,
}: PayPeriodMoneySummaryInput): PayPeriodMoneySummary {
  const allocatedPence = getTotalPence(allocations)
  const uncoveredRecurringPence = getUncoveredRecurringPence(duePayments, allocations)
  const totalPaymentsDuePence = allocatedPence + uncoveredRecurringPence
  const moneyLeftPence = incomePence - totalPaymentsDuePence

  return {
    payReceivedPence: incomePence,
    allocatedPence,
    uncoveredRecurringPence,
    totalPaymentsDuePence,
    moneyLeftPence,
    isOverCommitted: moneyLeftPence < 0,
  }
}

export function getPayPeriodCostSummary({
  payPeriod,
  creditCards = [],
  recurringPayments,
  customPayments,
  transactions,
  debts,
  creditCardRepayments,
  creditCardPots = [],
  debtReserves = [],
  pots = [],
  potAllocations = [],
}: PayPeriodCostSummaryInput): PayPeriodCostSummary {
  if (!payPeriod) {
    return createEmptyPayPeriodCostSummary()
  }

  const recurringItems = getRecurringPaymentOccurrences(
    recurringPayments,
    payPeriod.startDate,
    payPeriod.endDate,
  )
    .map((occurrence) => ({
      id: `recurring-${occurrence.payment.id}-${occurrence.dueDate}`,
      label: occurrence.payment.name,
      amountPence: occurrence.amountPence,
      date: occurrence.dueDate,
      source: 'recurring' as const,
      creditCardId: occurrence.payment.creditCardId ?? null,
      potId: occurrence.payment.potId,
    }))
  const directRecurringItems = applyLinkedPotBalancesToRecurringItems(
    recurringItems.filter((item) => !item.creditCardId),
    pots,
  )
  const creditCardRecurringItems = recurringItems.filter((item) => item.creditCardId)
  const savedPaymentItems = customPayments
    .filter(
      (payment) =>
        payment.status !== 'archived' &&
        isIsoDateBetweenInclusive(payment.dueDate, payPeriod.startDate, payPeriod.endDate),
    )
    .map((payment) => ({
      id: `custom-${payment.id}`,
      label: payment.name,
      amountPence: payment.amountPence,
      date: payment.dueDate,
      source: 'saved_payment' as const,
      creditCardId: payment.creditCardId ?? null,
      potId: null,
    }))
  const manualSpendItems = transactions
    .filter(
      (transaction) =>
        transaction.type === 'spending' &&
        !transaction.recurringPaymentId &&
        isIsoDateBetweenInclusive(transaction.date, payPeriod.startDate, payPeriod.endDate),
    )
    .map((transaction) => ({
      id: `transaction-${transaction.id}`,
      label: transaction.note,
      amountPence: transaction.amountPence,
      date: transaction.date,
      source: 'manual_spend' as const,
      creditCardId: transaction.paymentMethod === 'credit_card' ? transaction.creditCardId ?? null : null,
      potId: transaction.potId ?? null,
    }))
  const potLookup = new Map(pots.map((pot) => [pot.id, pot]))
  const potAllocationItems = potAllocations
    .filter(
      (allocation) =>
        allocation.payPeriodId === payPeriod.id &&
        allocation.amountPence > 0 &&
        allocation.source !== 'recurring' &&
        !allocation.recurringPaymentId,
    )
    .map((allocation) => {
      const pot = potLookup.get(allocation.potId)
      const label = pot
        ? allocation.source === 'pot_auto'
          ? `${pot.name} payday top-up`
          : `${pot.name} allocation`
        : 'Pot allocation'

      return {
        id: `pot-allocation-${allocation.id}`,
        label,
        amountPence: allocation.amountPence,
        date: payPeriod.payday,
        source: 'pot_allocation' as const,
        creditCardId: null,
        potId: allocation.potId,
      }
    })
  const debtReserveItems = debtReserves
    .filter(
      (reserve) =>
        reserve.status === 'planned' &&
        reserve.amountPence > 0 &&
        isDebtReserveInPayPeriod(reserve, payPeriod),
    )
    .map((reserve) => {
      const debt = debts.find((candidate) => candidate.id === reserve.debtId)

      return {
        id: `debt-reserve-${reserve.id}`,
        label: debt ? `${debt.name} reserve` : 'Debt reserve',
        amountPence: reserve.amountPence,
        date: reserve.payday,
        source: 'debt_reserve' as const,
        creditCardId: null,
        potId: null,
      }
    })
  const debtMinimumItems = debts
    .filter(
      (debt) =>
        debt.status === 'active' &&
        debt.currentBalancePence > 0 &&
        debt.dueDate <= payPeriod.endDate,
    )
    .map((debt) => ({
      id: `debt-${debt.id}`,
      label: debt.name,
      amountPence: getDebtDueAmountAfterReservesAndLinkedPotsPence(debt, debtReserves, pots),
      date: debt.dueDate,
      source: 'debt_minimum' as const,
      creditCardId: null,
      potId: null,
    }))
    .filter((item) => item.amountPence > 0)
  const creditCardPotItems = creditCardPots
    .filter(
      (creditCardPot) =>
        creditCardPot.status === 'active' &&
        creditCardPot.source === 'paycheck' &&
        creditCardPot.amountPence > 0 &&
        isCreditCardPotInPayPeriod(creditCardPot, payPeriod),
    )
    .map((creditCardPot) => ({
      id: `credit-card-pot-${creditCardPot.id}`,
      label: creditCardPot.name,
      amountPence: creditCardPot.amountPence,
      date: creditCardPot.payday ?? payPeriod.payday,
      source: 'credit_card_pot' as const,
      creditCardId: creditCardPot.creditCardId,
      potId: null,
    }))
  const repaymentItems = creditCardRepayments
    .filter((repayment) => isIsoDateBetweenInclusive(repayment.date, payPeriod.startDate, payPeriod.endDate))
    .map((repayment) => ({
      id: `repayment-${repayment.id}`,
      label: repayment.note || 'Card repayment',
      amountPence: -repayment.amountPence,
      date: repayment.date,
      source: 'credit_card_repayment' as const,
      creditCardId: repayment.creditCardId,
      potId: null,
    }))
  const activeCreditCardIds = new Set(creditCards.filter((card) => !card.archived).map((card) => card.id))
  const linkedCreditCardPots = activeCreditCardIds.size > 0
    ? pots.filter((pot) => !pot.archived && pot.linkedCreditCardId)
    : []
  const linkedCreditCardIds = new Set(
    linkedCreditCardPots
      .map((pot) => pot.linkedCreditCardId)
      .filter((cardId): cardId is string => typeof cardId === 'string' && activeCreditCardIds.has(cardId)),
  )
  const linkedCreditCardPotItems = linkedCreditCardIds.size > 0
    ? getCreditCardAllocationSummary({
        creditCards,
        recurringPayments,
        customPayments,
        transactions,
        repayments: creditCardRepayments,
        creditCardPots,
        pots,
        payPeriod,
      }).cards.flatMap((cardSummary) => {
        if (!linkedCreditCardIds.has(cardSummary.card.id) || cardSummary.remainingAfterCreditPotsPence <= 0) {
          return []
        }

        const linkedPot = linkedCreditCardPots.find((pot) => pot.linkedCreditCardId === cardSummary.card.id)

        if (!linkedPot) {
          return []
        }

        return [
          {
            id: `linked-credit-card-pot-${cardSummary.card.id}`,
            label: `${cardSummary.card.name} amount owed`,
            amountPence: cardSummary.remainingAfterCreditPotsPence,
            date: payPeriod.payday,
            source: 'linked_credit_card_pot' as const,
            creditCardId: cardSummary.card.id,
            potId: linkedPot.id,
          },
        ]
      })
    : []
  const allItems = [
    ...directRecurringItems,
    ...creditCardRecurringItems.filter((item) => !linkedCreditCardIds.has(item.creditCardId ?? '')),
    ...savedPaymentItems.filter((item) => !linkedCreditCardIds.has(item.creditCardId ?? '')),
    ...manualSpendItems.filter((item) => !linkedCreditCardIds.has(item.creditCardId ?? '')),
    ...potAllocationItems,
    ...debtReserveItems,
    ...debtMinimumItems,
    ...creditCardPotItems,
    ...linkedCreditCardPotItems,
    ...repaymentItems.filter((item) => !linkedCreditCardIds.has(item.creditCardId ?? '')),
  ].sort(sortPeriodCostItems)

  return createPayPeriodCostSummaryFromItems(payPeriod.incomePence, allItems)
}

function applyLinkedPotBalancesToRecurringItems(
  items: PeriodCostItem[],
  pots: Pot[],
): PeriodCostItem[] {
  const availableBalanceByPot = new Map(
    pots
      .filter((pot) => !pot.archived)
      .map((pot) => [pot.id, Math.max(0, pot.balancePence)]),
  )

  return items.map((item) => {
    if (!item.potId || item.amountPence <= 0) {
      return item
    }

    const availablePence = availableBalanceByPot.get(item.potId) ?? 0

    if (availablePence <= 0) {
      return item
    }

    const coveredPence = Math.min(item.amountPence, availablePence)
    availableBalanceByPot.set(item.potId, availablePence - coveredPence)

    return {
      ...item,
      amountPence: item.amountPence - coveredPence,
    }
  })
}

export function filterPayPeriodCostSummary(
  summary: PayPeriodCostSummary,
  ignoredItemIds: Iterable<string>,
): PayPeriodCostSummary {
  const ignoredIds = new Set(ignoredItemIds)

  if (ignoredIds.size === 0) {
    return summary
  }

  return createPayPeriodCostSummaryFromItems(
    summary.payReceivedPence,
    summary.items.filter((item) => !ignoredIds.has(item.id)),
  )
}

function createPayPeriodCostSummaryFromItems(
  payReceivedPence: number,
  items: PeriodCostItem[],
): PayPeriodCostSummary {
  const directRecurringPence = sumPositive(
    items.filter((item) => item.source === 'recurring' && !item.creditCardId),
  )
  const savedPaymentsPence = sumPositive(
    items.filter((item) => item.source === 'saved_payment' && !item.creditCardId),
  )
  const manualSpendingPence = sumPositive(
    items.filter((item) => item.source === 'manual_spend' && !item.creditCardId),
  )
  const potAllocationsPence = sumPositive(items.filter((item) => item.source === 'pot_allocation'))
  const debtReservesPence = sumPositive(items.filter((item) => item.source === 'debt_reserve'))
  const debtMinimumsPence = sumPositive(items.filter((item) => item.source === 'debt_minimum'))
  const creditCardPotsPence = sumPositive(
    items.filter((item) => item.source === 'credit_card_pot' || item.source === 'linked_credit_card_pot'),
  )
  const creditCardChargesPence = sumPositive(
    items.filter(
      (item) =>
        item.creditCardId &&
        ['recurring', 'saved_payment', 'manual_spend'].includes(item.source),
    ),
  )
  const creditCardRepaymentsPence = Math.abs(
    items
      .filter((item) => item.source === 'credit_card_repayment')
      .reduce((total, item) => total + item.amountPence, 0),
  )
  const creditCardNetPence = Math.max(0, creditCardChargesPence - creditCardRepaymentsPence)
  const totalCostsPence =
    directRecurringPence +
    savedPaymentsPence +
    manualSpendingPence +
    potAllocationsPence +
    debtReservesPence +
    debtMinimumsPence +
    creditCardPotsPence +
    creditCardNetPence
  const moneyLeftPence = payReceivedPence - totalCostsPence

  return {
    payReceivedPence,
    directRecurringPence,
    savedPaymentsPence,
    manualSpendingPence,
    potAllocationsPence,
    debtMinimumsPence,
    debtReservesPence,
    creditCardPotsPence,
    creditCardChargesPence,
    creditCardRepaymentsPence,
    creditCardNetPence,
    totalCostsPence,
    moneyLeftPence,
    isOverCommitted: moneyLeftPence < 0,
    items,
  }
}

export function getCreditCardAllocationSummary({
  creditCards,
  recurringPayments,
  customPayments,
  transactions,
  repayments,
  creditCardPots = [],
  pots = [],
  payPeriod,
}: CreditCardAllocationInput): CreditCardAllocationSummary {
  const rangeStart = payPeriod?.startDate ?? '0000-01-01'
  const rangeEnd = payPeriod?.endDate ?? toIsoDate(new Date())
  const activeCards = creditCards.filter((card) => !card.archived)
  const items = [
    ...getRecurringPaymentOccurrences(recurringPayments, rangeStart, rangeEnd).map((occurrence) => ({
      id: `recurring-${occurrence.payment.id}-${occurrence.dueDate}`,
      creditCardId: occurrence.payment.creditCardId ?? null,
      potId: occurrence.payment.potId,
      label: occurrence.payment.name,
      amountPence: occurrence.amountPence,
      date: occurrence.dueDate,
      source: 'recurring' as const,
    })),
    ...customPayments
      .filter(
        (payment) =>
          payment.status === 'unpaid' &&
          payment.dueDate >= rangeStart &&
          payment.dueDate <= rangeEnd,
      )
      .map((payment) => ({
        id: `custom-${payment.id}`,
        creditCardId: payment.creditCardId ?? null,
        potId: null,
        label: payment.name,
        amountPence: payment.amountPence,
        date: payment.dueDate,
        source: 'custom' as const,
      })),
    ...transactions
      .filter(
        (transaction) =>
          transaction.type === 'spending' &&
          transaction.paymentMethod === 'credit_card' &&
          transaction.date >= rangeStart &&
          transaction.date <= rangeEnd,
      )
      .map((transaction) => ({
        id: `transaction-${transaction.id}`,
        creditCardId: transaction.creditCardId ?? null,
        potId: transaction.potId ?? null,
        label: transaction.note,
        amountPence: transaction.amountPence,
        date: transaction.date,
        source: 'spending' as const,
      })),
    ...repayments
      .filter((repayment) => repayment.date >= rangeStart && repayment.date <= rangeEnd)
      .map((repayment) => ({
        id: `repayment-${repayment.id}`,
        creditCardId: repayment.creditCardId,
        potId: null,
        label: repayment.note || 'Card repayment',
        amountPence: -repayment.amountPence,
        date: repayment.date,
        source: 'repayment' as const,
      })),
  ].sort((a, b) => {
    const dateSort = a.date.localeCompare(b.date)

    if (dateSort !== 0) {
      return dateSort
    }

    return a.label.localeCompare(b.label)
  })
  const cards = activeCards.map((card) => {
    const openingBalancePence = getCreditCardOpeningBalancePence(card)
    const cardItems = items.filter((item) => item.creditCardId === card.id)
    const balanceItems = getCreditCardBalanceItems({
      card,
      recurringPayments,
      customPayments,
      transactions,
      repayments,
      rangeEnd,
    })
    const owedPence = Math.max(
      0,
      openingBalancePence + balanceItems.reduce((total, item) => total + item.amountPence, 0),
    )
    const activeCreditPots = creditCardPots.filter(
      (creditCardPot) =>
        creditCardPot.creditCardId === card.id &&
        creditCardPot.status === 'active' &&
        creditCardPot.amountPence > 0 &&
        (!payPeriod || creditCardPot.source === 'external' || isCreditCardPotInPayPeriod(creditCardPot, payPeriod)),
    )
    const storedCreditPotPence = sumCreditCardPots(activeCreditPots)
    const paycheckCreditPotPence = sumCreditCardPots(activeCreditPots.filter((creditCardPot) => creditCardPot.source === 'paycheck'))
    const externalCreditPotPence = sumCreditCardPots(activeCreditPots.filter((creditCardPot) => creditCardPot.source === 'external'))
    const linkedPotPence = getLinkedCreditCardPotPence(pots, card.id)
    const creditPotPence = storedCreditPotPence + linkedPotPence
    const availableCreditPence = Math.max(0, card.limitPence - owedPence)

    return {
      card,
      openingBalancePence,
      owedPence,
      creditPotPence,
      paycheckCreditPotPence,
      externalCreditPotPence,
      linkedPotPence,
      remainingAfterCreditPotsPence: Math.max(0, owedPence - creditPotPence),
      availableCreditPence,
      utilisationPercent: card.limitPence > 0 ? Math.round((owedPence / card.limitPence) * 100) : 0,
      dueLabel: getCreditCardDueLabel(card),
      items: cardItems,
      balanceItems,
    }
  })
  const totalOwedPence = cards.reduce((total, card) => total + card.owedPence, 0)
  const totalCreditPotsPence = cards.reduce((total, card) => total + card.creditPotPence, 0)
  const totalPaycheckCreditPotsPence = cards.reduce((total, card) => total + card.paycheckCreditPotPence, 0)
  const totalExternalCreditPotsPence = cards.reduce((total, card) => total + card.externalCreditPotPence, 0)
  const totalLinkedPotPence = cards.reduce((total, card) => total + card.linkedPotPence, 0)
  const totalRemainingAfterCreditPotsPence = cards.reduce(
    (total, card) => total + card.remainingAfterCreditPotsPence,
    0,
  )

  return {
    cards,
    unlinkedItems: items.filter((item) => !item.creditCardId),
    totalOwedPence,
    totalCreditPotsPence,
    totalPaycheckCreditPotsPence,
    totalExternalCreditPotsPence,
    totalLinkedPotPence,
    totalRemainingAfterCreditPotsPence,
    payReceivedPence: payPeriod?.incomePence ?? 0,
    paycheckRemainingAfterCardsPence: (payPeriod?.incomePence ?? 0) - totalOwedPence - totalPaycheckCreditPotsPence,
  }
}

function getCreditCardBalanceItems({
  card,
  recurringPayments,
  customPayments,
  transactions,
  repayments,
  rangeEnd,
}: {
  card: CreditCard
  recurringPayments: RecurringPayment[]
  customPayments: CustomPayment[]
  transactions: Transaction[]
  repayments: CreditCardRepayment[]
  rangeEnd: string
}): CreditCardAllocationItem[] {
  const cardStart = card.createdAt.slice(0, 10)

  return [
    ...recurringPayments
      .filter((payment) => payment.creditCardId === card.id)
      .flatMap((payment) =>
        getRecurringPaymentOccurrences(
          [payment],
          maxIsoDate(cardStart, payment.createdAt.slice(0, 10)),
          rangeEnd,
        ).map((occurrence) => ({
          id: `recurring-${occurrence.payment.id}-${occurrence.dueDate}`,
          creditCardId: card.id,
          potId: occurrence.payment.potId,
          label: occurrence.payment.name,
          amountPence: occurrence.amountPence,
          date: occurrence.dueDate,
          source: 'recurring' as const,
        })),
      ),
    ...customPayments
      .filter(
        (payment) =>
          payment.creditCardId === card.id &&
          payment.status === 'unpaid' &&
          payment.dueDate <= rangeEnd,
      )
      .map((payment) => ({
        id: `custom-${payment.id}`,
        creditCardId: card.id,
        potId: null,
        label: payment.name,
        amountPence: payment.amountPence,
        date: payment.dueDate,
        source: 'custom' as const,
      })),
    ...transactions
      .filter(
        (transaction) =>
          transaction.type === 'spending' &&
          transaction.paymentMethod === 'credit_card' &&
          transaction.creditCardId === card.id &&
          transaction.date <= rangeEnd,
      )
      .map((transaction) => ({
        id: `transaction-${transaction.id}`,
        creditCardId: card.id,
        potId: transaction.potId ?? null,
        label: transaction.note,
        amountPence: transaction.amountPence,
        date: transaction.date,
        source: 'spending' as const,
      })),
    ...repayments
      .filter(
        (repayment) =>
          repayment.creditCardId === card.id &&
          repayment.date <= rangeEnd,
      )
      .map((repayment) => ({
        id: `repayment-${repayment.id}`,
        creditCardId: card.id,
        potId: null,
        label: repayment.note || 'Card repayment',
        amountPence: -repayment.amountPence,
        date: repayment.date,
        source: 'repayment' as const,
      })),
  ].sort(sortCreditCardItems)
}

function getCreditCardOpeningBalancePence(card: CreditCard): number {
  return Math.max(0, card.openingBalancePence ?? 0)
}

function maxIsoDate(left: string, right: string): string {
  return left > right ? left : right
}

function sortCreditCardItems(a: CreditCardAllocationItem, b: CreditCardAllocationItem): number {
  const dateSort = a.date.localeCompare(b.date)

  if (dateSort !== 0) {
    return dateSort
  }

  return a.label.localeCompare(b.label)
}

export function getDaysInclusive(startDate: string, endDate: string): number {
  const start = parseDate(startDate)
  const end = parseDate(endDate)
  return Math.max(1, Math.floor((end.getTime() - start.getTime()) / dayMs) + 1)
}

export function getDailySafeToSpendPence(spendablePence: number, today: string, endDate: string): number {
  return Math.floor(spendablePence / getDaysInclusive(today, endDate))
}

export function parsePoundsToPence(value: string): number {
  const normalized = value.trim().replace(/[£,\s]/g, '')

  if (!normalized) {
    return 0
  }

  const isNegative = normalized.startsWith('-')
  const unsigned = isNegative ? normalized.slice(1) : normalized
  const [pounds = '0', pence = ''] = unsigned.split('.')
  const wholePence = Number.parseInt(pounds || '0', 10) * 100
  const fractionPence = Number.parseInt(pence.padEnd(2, '0').slice(0, 2) || '0', 10)
  const result = wholePence + fractionPence

  return isNegative ? -result : result
}

export function formatPence(amountPence: number, currency = 'GBP'): string {
  return new Intl.NumberFormat('en-GB', {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
  }).format(amountPence / 100)
}

export function toIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10)
}

export function addIsoDays(date: string, days: number): string {
  return toIsoDate(addDays(parseDate(date), days))
}

export function findPayPeriodForDate(payPeriods: PayPeriod[], date: string): PayPeriod | null {
  return (
    payPeriods.find((period) =>
      isIsoDateBetweenInclusive(date, period.startDate, period.endDate),
    ) ?? null
  )
}

export function getDebtSummary(
  debts: Debt[],
  payments: DebtPayment[],
  today: string,
  payPeriod: Pick<PayPeriod, 'endDate'> | null = null,
  debtReserves: DebtReserve[] = [],
  pots: Pot[] = [],
): DebtSummary {
  const activeDebts = debts.filter(
    (debt) => debt.status === 'active' && debt.currentBalancePence > 0,
  )
  const totalOriginalAmountPence = activeDebts.reduce(
    (total, debt) => total + debt.originalAmountPence,
    0,
  )
  const totalCurrentBalancePence = activeDebts.reduce(
    (total, debt) => total + debt.currentBalancePence,
    0,
  )
  const activeDebtIds = new Set(activeDebts.map((debt) => debt.id))
  const recordedPaymentPence = payments
    .filter((payment) => activeDebtIds.has(payment.debtId))
    .reduce((total, payment) => total + payment.amountPence, 0)
  const balanceReductionPence = Math.max(0, totalOriginalAmountPence - totalCurrentBalancePence)
  const totalPaidPence = Math.max(recordedPaymentPence, balanceReductionPence)

  return {
    activeDebtCount: activeDebts.length,
    overdueDebtCount: activeDebts.filter((debt) => debt.dueDate < today).length,
    totalCurrentBalancePence,
    totalOriginalAmountPence,
    totalPaidPence,
    debtDueThisPayPeriodPence: payPeriod
      ? activeDebts
          .filter((debt) => debt.dueDate <= payPeriod.endDate)
          .reduce(
            (total, debt) =>
              total + getDebtDueAmountAfterReservesAndLinkedPotsPence(debt, debtReserves, pots),
            0,
          )
      : 0,
    progressPercent:
      totalOriginalAmountPence > 0
        ? Math.round((totalPaidPence / totalOriginalAmountPence) * 100)
        : 0,
  }
}

function getCreditCardDueLabel(card: CreditCard): string {
  if (card.dueDate) {
    return card.dueDate
  }

  if (card.dueDay) {
    return `Day ${card.dueDay}`
  }

  return 'No due date'
}

function createEmptyPayPeriodCostSummary(): PayPeriodCostSummary {
  return {
    payReceivedPence: 0,
    directRecurringPence: 0,
    savedPaymentsPence: 0,
    manualSpendingPence: 0,
    potAllocationsPence: 0,
    debtMinimumsPence: 0,
    debtReservesPence: 0,
    creditCardPotsPence: 0,
    creditCardChargesPence: 0,
    creditCardRepaymentsPence: 0,
    creditCardNetPence: 0,
    totalCostsPence: 0,
    moneyLeftPence: 0,
    isOverCommitted: false,
    items: [],
  }
}

function isDebtReserveInPayPeriod(
  reserve: Pick<DebtReserve, 'payPeriodId' | 'periodStartDate' | 'periodEndDate'>,
  payPeriod: PayPeriod,
): boolean {
  if (reserve.payPeriodId) {
    return reserve.payPeriodId === payPeriod.id
  }

  return reserve.periodStartDate === payPeriod.startDate && reserve.periodEndDate === payPeriod.endDate
}

function isCreditCardPotInPayPeriod(
  creditCardPot: Pick<CreditCardPot, 'payPeriodId' | 'periodStartDate' | 'periodEndDate' | 'payday'>,
  payPeriod: PayPeriod,
): boolean {
  if (creditCardPot.payPeriodId) {
    return creditCardPot.payPeriodId === payPeriod.id
  }

  if (creditCardPot.periodStartDate && creditCardPot.periodEndDate) {
    return creditCardPot.periodStartDate === payPeriod.startDate && creditCardPot.periodEndDate === payPeriod.endDate
  }

  return Boolean(creditCardPot.payday && isIsoDateBetweenInclusive(creditCardPot.payday, payPeriod.startDate, payPeriod.endDate))
}

function sumPositive(items: Array<{ amountPence: number }>): number {
  return items.reduce((total, item) => total + Math.max(0, item.amountPence), 0)
}

function sumCreditCardPots(creditCardPots: CreditCardPot[]): number {
  return creditCardPots.reduce((total, creditCardPot) => total + Math.max(0, creditCardPot.amountPence), 0)
}

function sortPeriodCostItems(a: PeriodCostItem, b: PeriodCostItem): number {
  const dateSort = a.date.localeCompare(b.date)

  if (dateSort !== 0) {
    return dateSort
  }

  return a.label.localeCompare(b.label)
}

function isIsoDateBetweenInclusive(date: string, startDate: string, endDate: string): boolean {
  return date >= startDate && date <= endDate
}

function getRecurringPaymentDueDates(payment: RecurringPayment, start: Date, end: Date): Date[] {
  if (payment.dueDate) {
    return getAnchoredRecurringDates(payment, start, end)
  }

  if (!payment.dueDay) {
    return []
  }

  if (payment.frequency === 'weekly') {
    return getIntervalDueDates(payment.dueDay, start, end, 7)
  }

  if (payment.frequency === 'biweekly') {
    return getIntervalDueDates(payment.dueDay, start, end, 14)
  }

  if (payment.frequency === 'yearly') {
    return getYearlyDueDates(payment, start, end)
  }

  return getMonthlyDueDates(payment.dueDay, start, end)
}

function getMonthlyDueDates(dueDay: number, start: Date, end: Date): Date[] {
  const dueDates: Date[] = []
  const cursor = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), 1))

  while (cursor <= end) {
    const lastDay = new Date(Date.UTC(cursor.getUTCFullYear(), cursor.getUTCMonth() + 1, 0)).getUTCDate()
    const date = new Date(Date.UTC(cursor.getUTCFullYear(), cursor.getUTCMonth(), Math.min(dueDay, lastDay)))

    if (isBetweenInclusive(date, start, end)) {
      dueDates.push(date)
    }

    cursor.setUTCMonth(cursor.getUTCMonth() + 1)
  }

  return dueDates
}

function getYearlyDueDates(payment: RecurringPayment, start: Date, end: Date): Date[] {
  const dueDates: Date[] = []
  const anchor = parseDate(payment.createdAt.slice(0, 10))

  for (let year = start.getUTCFullYear(); year <= end.getUTCFullYear(); year += 1) {
    const lastDay = new Date(Date.UTC(year, anchor.getUTCMonth() + 1, 0)).getUTCDate()
    const date = new Date(Date.UTC(year, anchor.getUTCMonth(), Math.min(payment.dueDay ?? 1, lastDay)))

    if (isBetweenInclusive(date, start, end)) {
      dueDates.push(date)
    }
  }

  return dueDates
}

function getIntervalDueDates(dueDay: number, start: Date, end: Date, intervalDays: number): Date[] {
  const dueDates: Date[] = []
  const boundedDueDay = Math.min(Math.max(1, dueDay), 28)
  const anchor = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), boundedDueDay))
  let cursor = anchor

  while (cursor > start) {
    cursor = addDays(cursor, -intervalDays)
  }

  while (cursor <= end) {
    if (isBetweenInclusive(cursor, start, end)) {
      dueDates.push(cursor)
    }

    cursor = addDays(cursor, intervalDays)
  }

  return dueDates
}

function getAnchoredRecurringDates(payment: RecurringPayment, start: Date, end: Date): Date[] {
  const anchor = parseDate(payment.dueDate!)
  const dueDates: Date[] = []
  let cursor = anchor

  while (cursor < start) {
    cursor = getNextRecurringDate(cursor, payment.frequency)
  }

  while (cursor <= end) {
    dueDates.push(cursor)
    cursor = getNextRecurringDate(cursor, payment.frequency)
  }

  return dueDates
}

function getNextRecurringDate(date: Date, frequency: RecurringPayment['frequency']): Date {
  if (frequency === 'weekly') {
    return addDays(date, 7)
  }

  if (frequency === 'biweekly') {
    return addDays(date, 14)
  }

  if (frequency === 'yearly') {
    return new Date(Date.UTC(date.getUTCFullYear() + 1, date.getUTCMonth(), date.getUTCDate()))
  }

  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate()))
}

function parseDate(value: string): Date {
  return new Date(`${value}T00:00:00.000Z`)
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * dayMs)
}

function frequencyToDays(frequency: PayFrequency): number {
  if (frequency === 'weekly') {
    return 7
  }

  if (frequency === 'monthly') {
    return 31
  }

  return 14
}

function isBetweenInclusive(date: Date, start: Date, end: Date): boolean {
  return date >= start && date <= end
}

function getPriorityRank(priority: RecurringPayment['priority']): number {
  if (priority === 'essential') {
    return 0
  }

  if (priority === 'important') {
    return 1
  }

  return 2
}
