import type {
  PayFrequency,
  Pot,
  PotAllocation,
  RecurringPayment,
  Transaction,
  TransactionType,
} from '../types/models'

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
  const start = parseDate(startDate)
  const end = parseDate(endDate)

  return payments
    .filter((payment) => payment.active)
    .filter((payment) => recurringPaymentHasDueDate(payment, start, end))
    .sort((a, b) => getPriorityRank(a.priority) - getPriorityRank(b.priority))
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
    const directCoveredPence = Math.min(
      payment.amountPence,
      directAllocationByPayment.get(payment.id) ?? 0,
    )
    const remainingPaymentPence = payment.amountPence - directCoveredPence

    if (remainingPaymentPence <= 0) {
      return total
    }

    const availableInPot = remainingAllocationByPot.get(payment.potId) ?? 0
    const coveredPence = Math.min(remainingPaymentPence, availableInPot)
    remainingAllocationByPot.set(payment.potId, availableInPot - coveredPence)

    return total + remainingPaymentPence - coveredPence
  }, 0)
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

function recurringPaymentHasDueDate(payment: RecurringPayment, start: Date, end: Date): boolean {
  if (payment.dueDate) {
    return isBetweenInclusive(parseDate(payment.dueDate), start, end)
  }

  if (payment.frequency === 'monthly' && payment.dueDay) {
    return getMonthlyDueDates(payment.dueDay, start, end).length > 0
  }

  if (payment.frequency === 'yearly' && payment.dueDay) {
    return getMonthlyDueDates(payment.dueDay, start, end).length > 0
  }

  return false
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
