import { describe, expect, it } from 'vitest'

import {
  applyTransactionToPot,
  calculatePaycheckAmount,
  createNextPayPeriod,
  getPotBalanceAfterTransactionRemoval,
  getAllocationBalance,
  getDebtSummary,
  getRecurringPaymentOccurrences,
  getRecurringPaymentsDue,
  getUncoveredRecurringPence,
} from './money'
import type { Debt, DebtPayment, Pot, PotAllocation, RecurringPayment, Transaction } from '../types/models'

describe('paycheck calculations', () => {
  it('calculates income from hours worked and hourly rate in pence', () => {
    expect(calculatePaycheckAmount({ hoursWorked: 72.5, hourlyRatePence: 1250 })).toBe(90625)
  })

  it('uses actual received amount when it is provided', () => {
    expect(
      calculatePaycheckAmount({
        hoursWorked: 72.5,
        hourlyRatePence: 1250,
        actualAmountPence: 88000,
      }),
    ).toBe(88000)
  })
})

describe('pay period planning', () => {
  const payments: RecurringPayment[] = [
    {
      id: 'rent',
      name: 'Rent',
      amountPence: 70000,
      dueDay: 1,
      frequency: 'monthly',
      potId: 'bills',
      priority: 'essential',
      active: true,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
    },
    {
      id: 'phone',
      name: 'Phone',
      amountPence: 2200,
      dueDay: 23,
      frequency: 'monthly',
      potId: 'subs',
      priority: 'important',
      active: true,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
    },
    {
      id: 'archived',
      name: 'Old subscription',
      amountPence: 999,
      dueDay: 21,
      frequency: 'monthly',
      potId: 'subs',
      priority: 'optional',
      active: false,
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
    },
  ]

  it('finds recurring payments due inside the current pay period only', () => {
    const due = getRecurringPaymentsDue(payments, '2026-05-16', '2026-05-30')

    expect(due.map((payment) => payment.id)).toEqual(['phone'])
  })

  it('builds dated recurring payment occurrences for calendar views', () => {
    const due = getRecurringPaymentOccurrences(payments, '2026-05-16', '2026-06-02')

    expect(due.map((occurrence) => `${occurrence.payment.id}:${occurrence.dueDate}`)).toEqual([
      'phone:2026-05-23',
      'rent:2026-06-01',
    ])
  })

  it('supports weekly recurring payments in calendar views', () => {
    const due = getRecurringPaymentOccurrences(
      [
        {
          id: 'travel-card',
          name: 'Travel card',
          amountPence: 1200,
          dueDay: 18,
          frequency: 'weekly',
          potId: 'transport',
          priority: 'important',
          active: true,
          createdAt: '2026-05-01T00:00:00.000Z',
          updatedAt: '2026-05-01T00:00:00.000Z',
        },
      ],
      '2026-05-16',
      '2026-05-30',
    )

    expect(due.map((occurrence) => occurrence.dueDate)).toEqual([
      '2026-05-18',
      '2026-05-25',
    ])
  })

  it('anchors yearly recurring payments to their creation month', () => {
    const due = getRecurringPaymentOccurrences(
      [
        {
          id: 'insurance',
          name: 'Insurance',
          amountPence: 12000,
          dueDay: 23,
          frequency: 'yearly',
          potId: 'bills',
          priority: 'essential',
          active: true,
          createdAt: '2026-05-01T00:00:00.000Z',
          updatedAt: '2026-05-01T00:00:00.000Z',
        },
      ],
      '2026-05-16',
      '2026-07-30',
    )

    expect(due.map((occurrence) => occurrence.dueDate)).toEqual(['2026-05-23'])
  })

  it('creates weekly, biweekly, and monthly pay periods from a payday', () => {
    expect(createNextPayPeriod('2026-05-16', 'weekly')).toMatchObject({
      startDate: '2026-05-16',
      endDate: '2026-05-22',
      nextPayday: '2026-05-23',
    })
    expect(createNextPayPeriod('2026-05-16', 'biweekly')).toMatchObject({
      startDate: '2026-05-16',
      endDate: '2026-05-29',
      nextPayday: '2026-05-30',
    })
    expect(createNextPayPeriod('2026-05-16', 'monthly')).toMatchObject({
      startDate: '2026-05-16',
      endDate: '2026-06-15',
      nextPayday: '2026-06-16',
    })
  })
})

describe('pot balances', () => {
  const pot: Pot = {
    id: 'food',
    name: 'Food',
    type: 'spending',
    balancePence: 2200,
    targetPence: null,
    color: '#16a34a',
    archived: false,
    createdAt: '2026-05-01T00:00:00.000Z',
    updatedAt: '2026-05-01T00:00:00.000Z',
  }

  it('carries over pot balance when allocation is added', () => {
    expect(applyTransactionToPot(pot, 16000, 'allocation').balancePence).toBe(18200)
  })

  it('allows spending to reduce a pot below zero so overspending is visible', () => {
    expect(applyTransactionToPot(pot, 4000, 'spending').balancePence).toBe(-1800)
  })

  it('restores a pot balance when a manual spending transaction is deleted', () => {
    const transaction: Transaction = {
      id: 'spend',
      potId: 'food',
      amountPence: 4820,
      type: 'spending',
      date: '2026-05-16',
      note: 'Groceries',
      createdAt: '2026-05-16T00:00:00.000Z',
      updatedAt: '2026-05-16T00:00:00.000Z',
    }

    expect(getPotBalanceAfterTransactionRemoval({ ...pot, balancePence: 11180 }, transaction)).toBe(16000)
  })

  it('subtracts reserved money when an allocation transaction is deleted', () => {
    const transaction: Transaction = {
      id: 'allocation',
      potId: 'food',
      amountPence: 5600,
      type: 'allocation',
      date: '2026-05-16',
      note: 'Insurance reserve',
      createdAt: '2026-05-16T00:00:00.000Z',
      updatedAt: '2026-05-16T00:00:00.000Z',
    }

    expect(getPotBalanceAfterTransactionRemoval({ ...pot, balancePence: 15600 }, transaction)).toBe(10000)
  })

  it('calculates remaining allocation money and warns when allocations exceed income', () => {
    expect(
      getAllocationBalance({
        incomePence: 95000,
        reservedPence: 31000,
        allocationPence: 72000,
      }),
    ).toEqual({
      availableAfterReservedPence: 64000,
      remainingPence: -8000,
      isOverAllocated: true,
    })
  })

  it('detects recurring bills that were added after the active paycheck plan', () => {
    const duePayments: RecurringPayment[] = [
      {
        id: 'insurance',
        name: 'Insurance',
        amountPence: 5600,
        dueDay: 20,
        frequency: 'monthly',
        potId: 'bills',
        priority: 'essential',
        active: true,
        createdAt: '2026-05-01T00:00:00.000Z',
        updatedAt: '2026-05-01T00:00:00.000Z',
      },
      {
        id: 'phone',
        name: 'Phone',
        amountPence: 2200,
        dueDay: 23,
        frequency: 'monthly',
        potId: 'bills',
        priority: 'essential',
        active: true,
        createdAt: '2026-05-01T00:00:00.000Z',
        updatedAt: '2026-05-01T00:00:00.000Z',
      },
    ]
    const allocations: PotAllocation[] = [
      {
        id: 'allocation-phone',
        payPeriodId: 'period',
        potId: 'bills',
        amountPence: 2200,
        source: 'recurring',
        recurringPaymentId: 'phone',
        createdAt: '2026-05-16T00:00:00.000Z',
        updatedAt: '2026-05-16T00:00:00.000Z',
      },
    ]

    expect(getUncoveredRecurringPence(duePayments, allocations)).toBe(5600)
  })
})

describe('debt tracking', () => {
  const debts: Debt[] = [
    {
      id: 'debt-card',
      name: 'Credit card',
      lender: 'Bank',
      originalAmountPence: 120000,
      currentBalancePence: 85000,
      minimumPaymentPence: 5000,
      dueDate: '2026-05-20',
      interestRateApr: 19.9,
      note: 'Main card',
      status: 'active',
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
    },
    {
      id: 'debt-loan',
      name: 'Old loan',
      lender: 'Finance Co',
      originalAmountPence: 50000,
      currentBalancePence: 0,
      minimumPaymentPence: 0,
      dueDate: '2026-05-10',
      interestRateApr: null,
      note: '',
      status: 'paid',
      createdAt: '2026-05-01T00:00:00.000Z',
      updatedAt: '2026-05-01T00:00:00.000Z',
    },
  ]
  const payments: DebtPayment[] = [
    {
      id: 'payment-1',
      debtId: 'debt-card',
      amountPence: 35000,
      date: '2026-05-12',
      note: 'First chunk',
      createdAt: '2026-05-12T00:00:00.000Z',
      updatedAt: '2026-05-12T00:00:00.000Z',
    },
  ]

  it('summarises active debt balances, progress, and upcoming minimum payments', () => {
    expect(getDebtSummary(debts, payments, '2026-05-18')).toEqual({
      activeDebtCount: 1,
      overdueDebtCount: 0,
      totalCurrentBalancePence: 85000,
      totalOriginalAmountPence: 120000,
      totalPaidPence: 35000,
      minimumDueNext30DaysPence: 5000,
      progressPercent: 29,
    })
  })
})
