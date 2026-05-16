import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'

import { PaydayWizardPage } from './PaydayWizardPage'
import { RecurringPage } from './RecurringPage'
import { SettingsPage } from './SettingsPage'
import { SpendingPage } from './SpendingPage'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import type { RecurringPayment, Transaction } from '../types/models'

type TestActions = PlannerActions & {
  updateRecurringPayment: ReturnType<typeof vi.fn>
  updateTransaction: ReturnType<typeof vi.fn>
}

describe('settings page', () => {
  it('confirms when settings are saved', async () => {
    const user = userEvent.setup()
    const actions = createActions()

    render(<SettingsPage snapshot={createSnapshot()} actions={actions} />)

    expect(screen.queryByText('Settings saved')).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Save settings' }))

    expect(actions.updateSettings).toHaveBeenCalledWith({
      hourlyRatePence: 1250,
      payFrequency: 'biweekly',
    })
    expect(screen.getByText('Settings saved')).toBeVisible()
  })
})

describe('payday wizard', () => {
  it('lets the paycheck frequency change the visible pay period', async () => {
    const user = userEvent.setup()

    render(<PaydayWizardPage snapshot={createSnapshot()} actions={createActions()} />)

    fireEvent.change(screen.getByLabelText('Payday'), { target: { value: '2026-05-16' } })
    await user.selectOptions(screen.getByRole('combobox', { name: 'Pay frequency' }), 'monthly')

    expect(screen.getByDisplayValue('2026-05-16 to 2026-06-15')).toBeInTheDocument()
  })
})

describe('spending page', () => {
  it('edits an existing manual spending entry', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const snapshot = createSnapshot({
      transactions: [
        {
          id: 'txn-food',
          potId: 'pot-food',
          payPeriodId: null,
          amountPence: 1250,
          type: 'spending',
          date: '2026-05-16',
          note: 'Lunch',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<SpendingPage snapshot={snapshot} actions={actions} />)

    await user.click(screen.getByRole('button', { name: 'Edit Lunch' }))

    const editPanel = screen.getByRole('region', { name: 'Edit spending entry' })
    await user.clear(within(editPanel).getByLabelText('Amount'))
    await user.type(within(editPanel).getByLabelText('Amount'), '14.20')
    await user.clear(within(editPanel).getByLabelText('Note'))
    await user.type(within(editPanel).getByLabelText('Note'), 'Dinner')
    await user.click(within(editPanel).getByRole('button', { name: 'Save spending' }))

    expect(actions.updateTransaction).toHaveBeenCalledWith('txn-food', {
      amountPence: 1420,
      date: '2026-05-16',
      note: 'Dinner',
      potId: 'pot-food',
    })
  })
})

describe('recurring page', () => {
  it('edits an existing recurring payment', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const snapshot = createSnapshot({
      recurringPayments: [
        {
          id: 'rec-phone',
          name: 'Phone',
          amountPence: 2200,
          dueDay: 23,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'important',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<RecurringPage snapshot={snapshot} actions={actions} />)

    await user.click(screen.getByRole('button', { name: 'Edit Phone' }))

    const editPanel = screen.getByRole('region', { name: 'Edit recurring payment' })
    await user.clear(within(editPanel).getByLabelText('Amount'))
    await user.type(within(editPanel).getByLabelText('Amount'), '25.50')
    await user.selectOptions(within(editPanel).getByLabelText('Frequency'), 'yearly')
    await user.click(within(editPanel).getByRole('button', { name: 'Save recurring payment' }))

    expect(actions.updateRecurringPayment).toHaveBeenCalledWith('rec-phone', {
      amountPence: 2550,
      dueDay: 23,
      frequency: 'yearly',
      name: 'Phone',
      potId: 'pot-bills',
      priority: 'important',
    })
  })
})

function createActions(): TestActions {
  return {
    refresh: vi.fn(async () => {}),
    updateSettings: vi.fn(async () => {}),
    addPot: vi.fn(async () => {}),
    archivePot: vi.fn(async () => {}),
    addRecurringPayment: vi.fn(async () => {}),
    updateRecurringPayment: vi.fn(async () => {}),
    toggleRecurringPayment: vi.fn(async () => {}),
    deleteRecurringPayment: vi.fn(async () => {}),
    addTransaction: vi.fn(async () => {}),
    updateTransaction: vi.fn(async () => {}),
    deleteTransaction: vi.fn(async () => {}),
    createPaycheckPlan: vi.fn(async () => {}),
    resetPlannerData: vi.fn(async () => {}),
  }
}

function createSnapshot(overrides: Partial<PlannerSnapshot> = {}): PlannerSnapshot {
  const timestamp = '2026-05-16T00:00:00.000Z'
  const recurringPayments = overrides.recurringPayments as RecurringPayment[] | undefined
  const transactions = overrides.transactions as Transaction[] | undefined

  return {
    settings: {
      id: 'default',
      currency: 'GBP',
      payFrequency: 'biweekly',
      defaultPayPeriodDays: 14,
      hourlyRatePence: 1250,
      createdAt: timestamp,
      updatedAt: timestamp,
    },
    pots: [
      {
        id: 'pot-bills',
        name: 'Bills',
        type: 'reserved',
        balancePence: 40000,
        targetPence: null,
        color: '#2563eb',
        archived: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
      {
        id: 'pot-food',
        name: 'Food',
        type: 'spending',
        balancePence: 12000,
        targetPence: null,
        color: '#16a34a',
        archived: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    ],
    recurringPayments: recurringPayments ?? [],
    payPeriods: [],
    paychecks: [],
    potAllocations: [],
    transactions: transactions ?? [],
    ...overrides,
  }
}
