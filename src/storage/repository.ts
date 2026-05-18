import { defaultPots, defaultSettings } from '../data/defaults'
import {
  calculatePaycheckAmount,
  createNextPayPeriod,
  getPotBalanceAfterTransactionRemoval,
  getRecurringPaymentsDue,
  getUncoveredRecurringPence,
} from '../domain/money'
import type {
  Debt,
  DebtPayment,
  DebtStatus,
  PayPeriod,
  Paycheck,
  Pot,
  PotAllocation,
  PotType,
  RecurringPayment,
  RecurringFrequency,
  RecurringPriority,
  Settings,
  Transaction,
  TransactionType,
} from '../types/models'
import { db } from './db'

export interface PlannerSnapshot {
  settings: Settings
  pots: Pot[]
  recurringPayments: RecurringPayment[]
  payPeriods: PayPeriod[]
  paychecks: Paycheck[]
  potAllocations: PotAllocation[]
  transactions: Transaction[]
  debts: Debt[]
  debtPayments: DebtPayment[]
}

export interface PaycheckPlanInput {
  payday: string
  payFrequency?: Settings['payFrequency']
  hoursWorked: number
  hourlyRatePence: number
  actualAmountPence: number | null
  allocations: Array<{ potId: string; amountPence: number }>
}

export interface PotInput {
  name: string
  type: PotType
  balancePence: number
  color: string
}

export interface RecurringPaymentInput {
  name: string
  amountPence: number
  dueDay: number
  frequency: RecurringFrequency
  potId: string
  priority: RecurringPriority
}

export type RecurringPaymentUpdateInput = RecurringPaymentInput

export interface TransactionInput {
  potId: string
  payPeriodId?: string | null
  amountPence: number
  type: TransactionType
  date: string
  note: string
}

export interface TransactionUpdateInput {
  potId: string
  amountPence: number
  date: string
  note: string
}

export interface DebtInput {
  name: string
  lender: string
  currentBalancePence: number
  minimumPaymentPence: number
  dueDate: string
  interestRateApr: number | null
  note: string
}

export type DebtUpdateInput = DebtInput & {
  status: DebtStatus
}

export interface DebtPaymentInput {
  debtId: string
  amountPence: number
  date: string
  note: string
}

export async function getPlannerSnapshot(): Promise<PlannerSnapshot> {
  await ensureSeedData()

  const [
    settings,
    pots,
    recurringPayments,
    payPeriods,
    paychecks,
    potAllocations,
    transactions,
    debts,
    debtPayments,
  ] =
    await Promise.all([
      db.settings.get('default'),
      db.pots.toArray(),
      db.recurringPayments.toArray(),
      db.payPeriods.orderBy('payday').reverse().toArray(),
      db.paychecks.toArray(),
      db.potAllocations.toArray(),
      db.transactions.orderBy('date').reverse().toArray(),
      db.debts.orderBy('dueDate').toArray(),
      db.debtPayments.orderBy('date').reverse().toArray(),
    ])

  return {
    settings: settings ?? defaultSettings,
    pots: pots.sort((a, b) => a.name.localeCompare(b.name)),
    recurringPayments: recurringPayments.sort((a, b) => a.name.localeCompare(b.name)),
    payPeriods,
    paychecks,
    potAllocations,
    transactions,
    debts,
    debtPayments,
  }
}

export async function updateSettings(updates: Partial<Pick<Settings, 'hourlyRatePence' | 'payFrequency'>>): Promise<void> {
  const current = (await db.settings.get('default')) ?? defaultSettings
  await db.settings.put({
    ...current,
    ...updates,
    updatedAt: nowIso(),
  })
}

export async function addPot(input: PotInput): Promise<void> {
  const timestamp = nowIso()

  await db.pots.add({
    id: crypto.randomUUID(),
    name: input.name,
    type: input.type,
    balancePence: input.balancePence,
    targetPence: null,
    color: input.color,
    archived: false,
    createdAt: timestamp,
    updatedAt: timestamp,
  })
}

export async function archivePot(potId: string): Promise<void> {
  await db.pots.update(potId, {
    archived: true,
    updatedAt: nowIso(),
  })
}

export async function addRecurringPayment(input: RecurringPaymentInput): Promise<void> {
  const timestamp = nowIso()
  const payment: RecurringPayment = {
    id: crypto.randomUUID(),
    name: input.name,
    amountPence: input.amountPence,
    dueDay: input.dueDay,
    frequency: input.frequency,
    potId: input.potId,
    priority: input.priority,
    active: true,
    createdAt: timestamp,
    updatedAt: timestamp,
  }

  await db.transaction('rw', [db.recurringPayments, db.payPeriods, db.potAllocations, db.pots], async () => {
    await db.recurringPayments.add(payment)
    await reserveNewRecurringPaymentForActivePeriod(payment, timestamp)
  })
}

export async function updateRecurringPayment(
  paymentId: string,
  input: RecurringPaymentUpdateInput,
): Promise<void> {
  const timestamp = nowIso()

  await db.transaction('rw', [db.recurringPayments, db.payPeriods, db.potAllocations, db.pots], async () => {
    const current = await db.recurringPayments.get(paymentId)

    if (!current) {
      return
    }

    const nextPayment: RecurringPayment = {
      ...current,
      ...input,
      updatedAt: timestamp,
    }

    await db.recurringPayments.put(nextPayment)
    await reconcileRecurringPaymentForActivePeriod(nextPayment, timestamp)
  })
}

export async function toggleRecurringPayment(payment: RecurringPayment): Promise<void> {
  await db.recurringPayments.update(payment.id, {
    active: !payment.active,
    updatedAt: nowIso(),
  })
}

export async function deleteRecurringPayment(paymentId: string): Promise<void> {
  await db.transaction('rw', [db.recurringPayments, db.potAllocations, db.pots], async () => {
    const allocations = (await db.potAllocations.toArray()).filter(
      (allocation) => allocation.recurringPaymentId === paymentId,
    )

    for (const allocation of allocations) {
      await db.potAllocations.delete(allocation.id)

      const pot = await db.pots.get(allocation.potId)

      if (pot) {
        await db.pots.update(pot.id, {
          balancePence: pot.balancePence - allocation.amountPence,
          updatedAt: nowIso(),
        })
      }
    }

    await db.recurringPayments.delete(paymentId)
  })
}

export async function addTransaction(input: TransactionInput): Promise<void> {
  const timestamp = nowIso()
  const amountPence = Math.abs(input.amountPence)

  await db.transaction('rw', db.transactions, db.pots, async () => {
    await db.transactions.add({
      id: crypto.randomUUID(),
      potId: input.potId,
      payPeriodId: input.payPeriodId ?? null,
      amountPence,
      type: input.type,
      date: input.date,
      note: input.note,
      createdAt: timestamp,
      updatedAt: timestamp,
    })

    const pot = await db.pots.get(input.potId)

    if (pot) {
      const delta = input.type === 'spending' ? -amountPence : amountPence
      await db.pots.update(pot.id, {
        balancePence: pot.balancePence + delta,
        updatedAt: timestamp,
      })
    }
  })
}

export async function updateTransaction(
  transactionId: string,
  input: TransactionUpdateInput,
): Promise<void> {
  const timestamp = nowIso()
  const amountPence = Math.abs(input.amountPence)

  await db.transaction('rw', db.transactions, db.pots, async () => {
    const current = await db.transactions.get(transactionId)

    if (!current) {
      return
    }

    const oldPot = await db.pots.get(current.potId)
    let samePotAfterRemovalBalance: number | null = null

    if (oldPot) {
      samePotAfterRemovalBalance = getPotBalanceAfterTransactionRemoval(oldPot, current)
      await db.pots.update(oldPot.id, {
        balancePence: samePotAfterRemovalBalance,
        updatedAt: timestamp,
      })
    }

    const nextPot =
      input.potId === current.potId && oldPot && samePotAfterRemovalBalance !== null
        ? { ...oldPot, balancePence: samePotAfterRemovalBalance }
        : await db.pots.get(input.potId)

    if (nextPot) {
      const delta = current.type === 'spending' ? -amountPence : amountPence
      await db.pots.update(nextPot.id, {
        balancePence: nextPot.balancePence + delta,
        updatedAt: timestamp,
      })
    }

    await db.transactions.update(current.id, {
      potId: input.potId,
      amountPence,
      date: input.date,
      note: input.note,
      updatedAt: timestamp,
    })
  })
}

export async function deleteTransaction(transactionId: string): Promise<void> {
  await db.transaction('rw', db.transactions, db.pots, async () => {
    const transaction = await db.transactions.get(transactionId)

    if (!transaction) {
      return
    }

    await db.transactions.delete(transaction.id)

    const pot = await db.pots.get(transaction.potId)

    if (pot) {
      await db.pots.update(pot.id, {
        balancePence: getPotBalanceAfterTransactionRemoval(pot, transaction),
        updatedAt: nowIso(),
      })
    }
  })
}

export async function addDebt(input: DebtInput): Promise<void> {
  const timestamp = nowIso()
  const currentBalancePence = Math.max(0, input.currentBalancePence)

  await db.debts.add({
    id: crypto.randomUUID(),
    name: input.name.trim(),
    lender: input.lender.trim(),
    originalAmountPence: currentBalancePence,
    currentBalancePence,
    minimumPaymentPence: Math.max(0, input.minimumPaymentPence),
    dueDate: input.dueDate,
    interestRateApr: input.interestRateApr,
    note: input.note.trim(),
    status: currentBalancePence > 0 ? 'active' : 'paid',
    createdAt: timestamp,
    updatedAt: timestamp,
  })
}

export async function updateDebt(debtId: string, input: DebtUpdateInput): Promise<void> {
  const current = await db.debts.get(debtId)

  if (!current) {
    return
  }

  const currentBalancePence = Math.max(0, input.currentBalancePence)
  const status = currentBalancePence <= 0 ? 'paid' : input.status

  await db.debts.update(debtId, {
    name: input.name.trim(),
    lender: input.lender.trim(),
    originalAmountPence: Math.max(current.originalAmountPence, currentBalancePence),
    currentBalancePence,
    minimumPaymentPence: Math.max(0, input.minimumPaymentPence),
    dueDate: input.dueDate,
    interestRateApr: input.interestRateApr,
    note: input.note.trim(),
    status,
    updatedAt: nowIso(),
  })
}

export async function deleteDebt(debtId: string): Promise<void> {
  await db.transaction('rw', db.debts, db.debtPayments, async () => {
    await db.debtPayments.where('debtId').equals(debtId).delete()
    await db.debts.delete(debtId)
  })
}

export async function addDebtPayment(input: DebtPaymentInput): Promise<void> {
  const timestamp = nowIso()
  const amountPence = Math.abs(input.amountPence)

  if (amountPence <= 0) {
    return
  }

  await db.transaction('rw', db.debts, db.debtPayments, async () => {
    const debt = await db.debts.get(input.debtId)

    if (!debt || debt.currentBalancePence <= 0) {
      return
    }

    const appliedAmountPence = Math.min(amountPence, debt.currentBalancePence)
    const nextBalancePence = debt.currentBalancePence - appliedAmountPence

    await db.debtPayments.add({
      id: crypto.randomUUID(),
      debtId: input.debtId,
      amountPence: appliedAmountPence,
      date: input.date,
      note: input.note.trim(),
      createdAt: timestamp,
      updatedAt: timestamp,
    })

    await db.debts.update(debt.id, {
      currentBalancePence: nextBalancePence,
      status: nextBalancePence > 0 ? 'active' : 'paid',
      updatedAt: timestamp,
    })
  })
}

export async function deleteDebtPayment(paymentId: string): Promise<void> {
  await db.transaction('rw', db.debts, db.debtPayments, async () => {
    const payment = await db.debtPayments.get(paymentId)

    if (!payment) {
      return
    }

    await db.debtPayments.delete(payment.id)

    const debt = await db.debts.get(payment.debtId)

    if (!debt) {
      return
    }

    const restoredBalancePence = Math.min(
      debt.originalAmountPence,
      debt.currentBalancePence + payment.amountPence,
    )

    await db.debts.update(debt.id, {
      currentBalancePence: restoredBalancePence,
      status: restoredBalancePence > 0 ? 'active' : 'paid',
      updatedAt: nowIso(),
    })
  })
}

export async function createPaycheckPlan(input: PaycheckPlanInput): Promise<void> {
  const settings = (await db.settings.get('default')) ?? defaultSettings
  const periodDates = createNextPayPeriod(input.payday, input.payFrequency ?? settings.payFrequency)
  const timestamp = nowIso()
  const payPeriodId = crypto.randomUUID()
  const calculatedAmountPence = calculatePaycheckAmount({
    hoursWorked: input.hoursWorked,
    hourlyRatePence: input.hourlyRatePence,
  })
  const incomePence = calculatePaycheckAmount({
    hoursWorked: input.hoursWorked,
    hourlyRatePence: input.hourlyRatePence,
    actualAmountPence: input.actualAmountPence,
  })

  await db.transaction(
    'rw',
    [db.payPeriods, db.paychecks, db.potAllocations, db.pots, db.recurringPayments],
    async () => {
      const recurringPayments = await db.recurringPayments.toArray()
      const duePayments = getRecurringPaymentsDue(
        recurringPayments,
        periodDates.startDate,
        periodDates.endDate,
      )
      const reservedAllocations = duePayments.map((payment) => ({
        potId: payment.potId,
        amountPence: payment.amountPence,
        source: 'recurring' as const,
        recurringPaymentId: payment.id,
      }))
      const manualAllocations = input.allocations.map((allocation) => ({
        ...allocation,
        source: 'manual' as const,
        recurringPaymentId: null,
      }))
      const allAllocations = [...reservedAllocations, ...manualAllocations].filter(
        (allocation) => allocation.amountPence > 0,
      )

      await db.payPeriods.add({
        id: payPeriodId,
        payday: input.payday,
        incomePence,
        status: 'active',
        startDate: periodDates.startDate,
        endDate: periodDates.endDate,
        nextPayday: periodDates.nextPayday,
        createdAt: timestamp,
        updatedAt: timestamp,
      })

      await db.paychecks.add({
        id: crypto.randomUUID(),
        payPeriodId,
        hoursWorked: input.hoursWorked,
        hourlyRatePence: input.hourlyRatePence,
        calculatedAmountPence,
        actualAmountPence: input.actualAmountPence,
        createdAt: timestamp,
        updatedAt: timestamp,
      })

      for (const allocation of allAllocations) {
        await db.potAllocations.add({
          id: crypto.randomUUID(),
          payPeriodId,
          potId: allocation.potId,
          amountPence: allocation.amountPence,
          source: allocation.source,
          recurringPaymentId: allocation.recurringPaymentId,
          createdAt: timestamp,
          updatedAt: timestamp,
        })

        const pot = await db.pots.get(allocation.potId)

        if (pot) {
          await db.pots.update(pot.id, {
            balancePence: pot.balancePence + allocation.amountPence,
            updatedAt: timestamp,
          })
        }
      }
    },
  )
}

export async function resetPlannerData(): Promise<void> {
  await db.transaction(
    'rw',
    [
      db.settings,
      db.pots,
      db.recurringPayments,
      db.payPeriods,
      db.paychecks,
      db.potAllocations,
      db.transactions,
      db.debts,
      db.debtPayments,
    ],
    async () => {
      await Promise.all([
        db.settings.clear(),
        db.pots.clear(),
        db.recurringPayments.clear(),
        db.payPeriods.clear(),
        db.paychecks.clear(),
        db.potAllocations.clear(),
        db.transactions.clear(),
        db.debts.clear(),
        db.debtPayments.clear(),
      ])
      await seedDefaults()
    },
  )
}

export async function replacePlannerSnapshot(snapshot: PlannerSnapshot): Promise<void> {
  await db.transaction(
    'rw',
    [
      db.settings,
      db.pots,
      db.recurringPayments,
      db.payPeriods,
      db.paychecks,
      db.potAllocations,
      db.transactions,
      db.debts,
      db.debtPayments,
    ],
    async () => {
      await Promise.all([
        db.settings.clear(),
        db.pots.clear(),
        db.recurringPayments.clear(),
        db.payPeriods.clear(),
        db.paychecks.clear(),
        db.potAllocations.clear(),
        db.transactions.clear(),
        db.debts.clear(),
        db.debtPayments.clear(),
      ])

      await db.settings.put(snapshot.settings ?? defaultSettings)
      await putAll(db.pots, snapshot.pots)
      await putAll(db.recurringPayments, snapshot.recurringPayments)
      await putAll(db.payPeriods, snapshot.payPeriods)
      await putAll(db.paychecks, snapshot.paychecks)
      await putAll(db.potAllocations, snapshot.potAllocations)
      await putAll(db.transactions, snapshot.transactions)
      await putAll(db.debts, snapshot.debts)
      await putAll(db.debtPayments, snapshot.debtPayments)
    },
  )
}

async function ensureSeedData(): Promise<void> {
  const settings = await db.settings.get('default')
  const potCount = await db.pots.count()

  if (!settings || potCount === 0) {
    await seedDefaults()
  }
}

async function seedDefaults(): Promise<void> {
  await db.settings.put({
    ...defaultSettings,
    updatedAt: nowIso(),
  })
  await db.pots.bulkPut(
    defaultPots.map((pot) => ({
      ...pot,
      createdAt: nowIso(),
      updatedAt: nowIso(),
    })),
  )
}

function nowIso(): string {
  return new Date().toISOString()
}

async function putAll<T extends { id: string }>(
  table: { bulkPut: (items: T[]) => Promise<unknown> },
  items: T[],
): Promise<void> {
  if (items.length > 0) {
    await table.bulkPut(items)
  }
}

async function reserveNewRecurringPaymentForActivePeriod(
  payment: RecurringPayment,
  timestamp: string,
): Promise<void> {
  const latestPeriod = await db.payPeriods.orderBy('payday').last()

  if (!latestPeriod || latestPeriod.status === 'closed') {
    return
  }

  const duePayments = getRecurringPaymentsDue([payment], latestPeriod.startDate, latestPeriod.endDate)

  if (duePayments.length === 0) {
    return
  }

  const existingAllocations = await db.potAllocations
    .where('payPeriodId')
    .equals(latestPeriod.id)
    .toArray()
  const uncoveredPence = getUncoveredRecurringPence(duePayments, existingAllocations)

  if (uncoveredPence <= 0) {
    return
  }

  await db.potAllocations.add({
    id: crypto.randomUUID(),
    payPeriodId: latestPeriod.id,
    potId: payment.potId,
    amountPence: uncoveredPence,
    source: 'recurring',
    recurringPaymentId: payment.id,
    createdAt: timestamp,
    updatedAt: timestamp,
  })

  const pot = await db.pots.get(payment.potId)

  if (pot) {
    await db.pots.update(pot.id, {
      balancePence: pot.balancePence + uncoveredPence,
      updatedAt: timestamp,
    })
  }
}

async function reconcileRecurringPaymentForActivePeriod(
  payment: RecurringPayment,
  timestamp: string,
): Promise<void> {
  const latestPeriod = await db.payPeriods.orderBy('payday').last()

  if (!latestPeriod || latestPeriod.status === 'closed') {
    return
  }

  const activePeriodAllocations = await db.potAllocations
    .where('payPeriodId')
    .equals(latestPeriod.id)
    .toArray()
  const existingAllocations = activePeriodAllocations.filter(
    (allocation) => allocation.recurringPaymentId === payment.id,
  )
  const [existingAllocation, ...duplicateAllocations] = existingAllocations
  const isDue = getRecurringPaymentsDue([payment], latestPeriod.startDate, latestPeriod.endDate).length > 0

  for (const allocation of duplicateAllocations) {
    await removeAllocationFromPot(allocation, timestamp)
    await db.potAllocations.delete(allocation.id)
  }

  if (!isDue) {
    if (existingAllocation) {
      await removeAllocationFromPot(existingAllocation, timestamp)
      await db.potAllocations.delete(existingAllocation.id)
    }

    return
  }

  if (!existingAllocation) {
    await db.potAllocations.add({
      id: crypto.randomUUID(),
      payPeriodId: latestPeriod.id,
      potId: payment.potId,
      amountPence: payment.amountPence,
      source: 'recurring',
      recurringPaymentId: payment.id,
      createdAt: timestamp,
      updatedAt: timestamp,
    })
    await addAllocationToPot(payment.potId, payment.amountPence, timestamp)
    return
  }

  if (existingAllocation.potId !== payment.potId) {
    await removeAllocationFromPot(existingAllocation, timestamp)
    await addAllocationToPot(payment.potId, payment.amountPence, timestamp)
  } else {
    await addAllocationToPot(
      existingAllocation.potId,
      payment.amountPence - existingAllocation.amountPence,
      timestamp,
    )
  }

  await db.potAllocations.update(existingAllocation.id, {
    potId: payment.potId,
    amountPence: payment.amountPence,
    source: 'recurring',
    recurringPaymentId: payment.id,
    updatedAt: timestamp,
  })
}

async function removeAllocationFromPot(
  allocation: Pick<PotAllocation, 'potId' | 'amountPence'>,
  timestamp: string,
): Promise<void> {
  await addAllocationToPot(allocation.potId, -allocation.amountPence, timestamp)
}

async function addAllocationToPot(
  potId: string,
  amountPence: number,
  timestamp: string,
): Promise<void> {
  const pot = await db.pots.get(potId)

  if (!pot) {
    return
  }

  await db.pots.update(pot.id, {
    balancePence: pot.balancePence + amountPence,
    updatedAt: timestamp,
  })
}
