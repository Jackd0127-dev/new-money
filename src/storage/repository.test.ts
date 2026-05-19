import 'fake-indexeddb/auto'

import { beforeEach, describe, expect, it } from 'vitest'

import {
  addCreditCard,
  addCreditCardRepayment,
  addCustomPayment,
  addDailyBrief,
  createPaycheckPlan,
  deletePayPeriod,
  getPlannerSnapshot,
  resetPlannerData,
} from './repository'
import { db } from './db'

describe('paycheck plan storage', () => {
  beforeEach(async () => {
    await db.delete()
    await db.open()
    await resetPlannerData()
  })

  it('updates an existing payday plan instead of creating duplicate history or double-counting pots', async () => {
    await createPaycheckPlan({
      payday: '2026-05-16',
      payFrequency: 'biweekly',
      hoursWorked: 72,
      hourlyRatePence: 1250,
      actualAmountPence: null,
      allocations: [{ potId: 'pot-food', amountPence: 10000 }],
    })

    await createPaycheckPlan({
      payday: '2026-05-16',
      payFrequency: 'biweekly',
      hoursWorked: 80,
      hourlyRatePence: 1300,
      actualAmountPence: 100000,
      allocations: [{ potId: 'pot-food', amountPence: 20000 }],
    })

    const snapshot = await getPlannerSnapshot()
    const foodPot = snapshot.pots.find((pot) => pot.id === 'pot-food')

    expect(snapshot.payPeriods).toHaveLength(1)
    expect(snapshot.paychecks).toHaveLength(1)
    expect(snapshot.potAllocations).toHaveLength(1)
    expect(snapshot.payPeriods[0]).toMatchObject({
      payday: '2026-05-16',
      incomePence: 100000,
    })
    expect(snapshot.paychecks[0]).toMatchObject({
      hoursWorked: 80,
      hourlyRatePence: 1300,
      actualAmountPence: 100000,
    })
    expect(foodPot?.balancePence).toBe(20000)
    expect(snapshot.settings.hourlyRatePence).toBe(1300)
    expect((snapshot.settings as { defaultHoursWorked?: number }).defaultHoursWorked).toBe(80)
  })

  it('deletes a payday plan and reverses its allocations from pot balances', async () => {
    await createPaycheckPlan({
      payday: '2026-05-16',
      payFrequency: 'biweekly',
      hoursWorked: 72,
      hourlyRatePence: 1250,
      actualAmountPence: null,
      allocations: [{ potId: 'pot-food', amountPence: 10000 }],
    })

    const savedSnapshot = await getPlannerSnapshot()
    await deletePayPeriod(savedSnapshot.payPeriods[0].id)

    const snapshot = await getPlannerSnapshot()
    const foodPot = snapshot.pots.find((pot) => pot.id === 'pot-food')

    expect(snapshot.payPeriods).toHaveLength(0)
    expect(snapshot.paychecks).toHaveLength(0)
    expect(snapshot.potAllocations).toHaveLength(0)
    expect(foodPot?.balancePence).toBe(0)
  })

  it('persists credit cards, custom payments, repayments, and daily briefs in the planner snapshot', async () => {
    await addCreditCard({
      name: 'Everyday Amex',
      provider: 'Amex',
      limitPence: 100000,
      dueDay: 12,
      dueDate: null,
      color: '#2563eb',
    })

    const withCard = await getPlannerSnapshot()
    const card = withCard.creditCards[0]

    await addCustomPayment({
      name: 'Tyres',
      amountPence: 3000,
      dueDate: '2026-05-20',
      creditCardId: card.id,
    })
    await addCreditCardRepayment({
      creditCardId: card.id,
      amountPence: 1250,
      date: '2026-05-24',
      note: 'Part payment',
    })
    await addDailyBrief({
      date: '2026-05-19',
      snapshotSignature: 'snapshot-signature',
      content: 'Today: check your card balances.',
    })

    const snapshot = await getPlannerSnapshot()

    expect(snapshot.creditCards[0]).toMatchObject({
      name: 'Everyday Amex',
      provider: 'Amex',
      limitPence: 100000,
      dueDay: 12,
      dueDate: null,
      archived: false,
    })
    expect(snapshot.customPayments[0]).toMatchObject({
      name: 'Tyres',
      amountPence: 3000,
      creditCardId: card.id,
      status: 'unpaid',
    })
    expect(snapshot.creditCardRepayments[0]).toMatchObject({
      creditCardId: card.id,
      amountPence: 1250,
      note: 'Part payment',
    })
    expect(snapshot.dailyBriefs[0]).toMatchObject({
      date: '2026-05-19',
      snapshotSignature: 'snapshot-signature',
      content: 'Today: check your card balances.',
    })
  })
})
