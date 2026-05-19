import 'fake-indexeddb/auto'

import { beforeEach, describe, expect, it } from 'vitest'

import {
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
})
