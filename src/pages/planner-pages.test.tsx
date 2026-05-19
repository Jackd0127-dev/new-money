import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'

import { DashboardPage } from './DashboardPage'
import { DebtsPage } from './DebtsPage'
import { HistoryPage } from './HistoryPage'
import { PaydayWizardPage } from './PaydayWizardPage'
import { PotsPage } from './PotsPage'
import { RecurringPage } from './RecurringPage'
import { SettingsPage } from './SettingsPage'
import { SpendingPage } from './SpendingPage'
import { toIsoDate } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import type { RecurringPayment, Transaction } from '../types/models'

type TestActions = PlannerActions & {
  addDebt: ReturnType<typeof vi.fn>
  addDebtPayment: ReturnType<typeof vi.fn>
  deletePayPeriod: ReturnType<typeof vi.fn>
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
      defaultHoursWorked: 72,
      hourlyRatePence: 1250,
      payFrequency: 'biweekly',
    })
    expect(screen.getByText('Settings saved')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Save settings' })).toBeDisabled()
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

  it('loads an existing payday plan so saving that date updates instead of creating a duplicate', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const snapshot = createSnapshot({
      payPeriods: [
        {
          id: 'period-current',
          startDate: '2026-05-16',
          endDate: '2026-05-29',
          payday: '2026-05-16',
          nextPayday: '2026-05-30',
          payFrequency: 'biweekly',
          incomePence: 120000,
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      paychecks: [
        {
          id: 'paycheck-current',
          payPeriodId: 'period-current',
          hoursWorked: 84.5,
          hourlyRatePence: 1350,
          calculatedAmountPence: 114075,
          actualAmountPence: 120000,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      potAllocations: [
        {
          id: 'allocation-food',
          payPeriodId: 'period-current',
          potId: 'pot-food',
          amountPence: 15000,
          source: 'manual',
          recurringPaymentId: null,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<PaydayWizardPage snapshot={snapshot} actions={actions} />)

    fireEvent.change(screen.getByLabelText('Payday'), { target: { value: '2026-05-16' } })

    expect(screen.getByDisplayValue('84.5')).toBeInTheDocument()
    expect(screen.getByDisplayValue('13.50')).toBeInTheDocument()
    expect(screen.getByDisplayValue('1200.00')).toBeInTheDocument()
    expect(screen.getByLabelText('Food')).toHaveValue('150.00')

    await user.clear(screen.getByLabelText('Hours worked'))
    await user.type(screen.getByLabelText('Hours worked'), '86')
    await user.click(screen.getByRole('button', { name: 'Update paycheck plan' }))

    expect(actions.createPaycheckPlan).toHaveBeenCalledWith({
      payday: '2026-05-16',
      payFrequency: 'biweekly',
      hoursWorked: 86,
      hourlyRatePence: 1350,
      actualAmountPence: 120000,
      allocations: [{ potId: 'pot-food', amountPence: 15000 }],
    })
  })
})

describe('spending page', () => {
  it('uses quick amount buttons for faster manual spending entry', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const today = toIsoDate(new Date())

    render(<SpendingPage snapshot={createSnapshot()} actions={actions} />)

    await user.click(screen.getByRole('button', { name: '£10.00' }))
    await user.type(screen.getByLabelText('Note'), 'Coffee')
    await user.click(screen.getByRole('button', { name: 'Log spending' }))

    expect(actions.addTransaction).toHaveBeenCalledWith({
      amountPence: 1000,
      date: today,
      note: 'Coffee',
      payPeriodId: null,
      potId: 'pot-bills',
      type: 'spending',
    })
  })

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

describe('pots page', () => {
  it('expands a pot to show spending, recurring payments, and allocations tied to it', async () => {
    const user = userEvent.setup()
    const snapshot = createSnapshot({
      payPeriods: [
        {
          id: 'period-current',
          startDate: '2026-05-16',
          endDate: '2026-05-29',
          payday: '2026-05-16',
          nextPayday: '2026-05-30',
          incomePence: 90000,
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      potAllocations: [
        {
          id: 'allocation-food',
          payPeriodId: 'period-current',
          potId: 'pot-food',
          amountPence: 7500,
          source: 'manual',
          recurringPaymentId: null,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'meal-kit',
          name: 'Meal kit',
          amountPence: 1800,
          dueDay: 20,
          frequency: 'monthly',
          potId: 'pot-food',
          priority: 'important',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      transactions: [
        {
          id: 'txn-food',
          potId: 'pot-food',
          payPeriodId: 'period-current',
          amountPence: 1250,
          type: 'spending',
          date: '2026-05-17',
          note: 'Lunch',
          createdAt: '2026-05-17T00:00:00.000Z',
          updatedAt: '2026-05-17T00:00:00.000Z',
        },
        {
          id: 'txn-bills',
          potId: 'pot-bills',
          payPeriodId: 'period-current',
          amountPence: 8500,
          type: 'spending',
          date: '2026-05-18',
          note: 'Direct debit',
          createdAt: '2026-05-18T00:00:00.000Z',
          updatedAt: '2026-05-18T00:00:00.000Z',
        },
      ],
    })

    render(<PotsPage snapshot={snapshot} actions={createActions()} />)

    expect(screen.queryByText('Lunch')).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'View Food activity' }))

    const activity = screen.getByRole('region', { name: 'Food activity' })
    expect(within(activity).getByText('Lunch')).toBeInTheDocument()
    expect(within(activity).getByText('Spending · 2026-05-17')).toBeInTheDocument()
    expect(within(activity).getByText('-£12.50')).toBeInTheDocument()
    expect(within(activity).getByText('Paycheck allocation')).toBeInTheDocument()
    expect(within(activity).getByText('Allocation · 2026-05-16')).toBeInTheDocument()
    expect(within(activity).getByText('+£75.00')).toBeInTheDocument()
    expect(within(activity).getByText('Meal kit')).toBeInTheDocument()
    expect(within(activity).getByText('Recurring · monthly · day 20')).toBeInTheDocument()
    expect(within(activity).queryByText('Direct debit')).not.toBeInTheDocument()
  })
})

describe('recurring page', () => {
  it('shows a dated recurring calendar', () => {
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
      payPeriods: [
        {
          id: 'period-current',
          startDate: '2026-05-16',
          endDate: '2026-05-29',
          payday: '2026-05-16',
          nextPayday: '2026-05-30',
          incomePence: 90000,
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<RecurringPage snapshot={snapshot} actions={createActions()} />)

    expect(screen.getByRole('region', { name: 'Recurring calendar' })).toBeInTheDocument()
    expect(screen.getAllByText('Phone').length).toBeGreaterThan(0)
    expect(screen.getByText(/23 May/)).toBeInTheDocument()
    expect(screen.getByText('Before payday')).toBeInTheDocument()
  })

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

describe('dashboard page', () => {
  it('shows one clear pay summary with correct current period maths', () => {
    const snapshot = createSnapshot({
      payPeriods: [
        {
          id: 'period-current',
          startDate: '2026-05-22',
          endDate: '2026-06-04',
          payday: '2026-05-22',
          nextPayday: '2026-06-05',
          payFrequency: 'biweekly',
          incomePence: 79800,
          status: 'active',
          createdAt: '2026-05-22T00:00:00.000Z',
          updatedAt: '2026-05-22T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'applecare',
          name: 'AppleCare',
          amountPence: 1000,
          dueDay: 19,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'important',
          active: true,
          createdAt: '2026-05-01T00:00:00.000Z',
          updatedAt: '2026-05-01T00:00:00.000Z',
        },
        {
          id: 'insurance',
          name: 'Car Insurance',
          amountPence: 8500,
          dueDay: 1,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'essential',
          active: true,
          createdAt: '2026-05-01T00:00:00.000Z',
          updatedAt: '2026-05-01T00:00:00.000Z',
        },
        {
          id: 'fuel',
          name: 'Fuel',
          amountPence: 14000,
          dueDay: 1,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'important',
          active: true,
          createdAt: '2026-05-01T00:00:00.000Z',
          updatedAt: '2026-05-01T00:00:00.000Z',
        },
        {
          id: 'gym',
          name: 'Gym',
          amountPence: 2500,
          dueDay: 1,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'optional',
          active: true,
          createdAt: '2026-05-01T00:00:00.000Z',
          updatedAt: '2026-05-01T00:00:00.000Z',
        },
      ],
      potAllocations: [
        {
          id: 'allocation-insurance',
          payPeriodId: 'period-current',
          potId: 'pot-bills',
          amountPence: 8500,
          source: 'recurring',
          recurringPaymentId: 'insurance',
          createdAt: '2026-05-22T00:00:00.000Z',
          updatedAt: '2026-05-22T00:00:00.000Z',
        },
        {
          id: 'allocation-fuel',
          payPeriodId: 'period-current',
          potId: 'pot-bills',
          amountPence: 14000,
          source: 'recurring',
          recurringPaymentId: 'fuel',
          createdAt: '2026-05-22T00:00:00.000Z',
          updatedAt: '2026-05-22T00:00:00.000Z',
        },
        {
          id: 'allocation-gym',
          payPeriodId: 'period-current',
          potId: 'pot-bills',
          amountPence: 2500,
          source: 'recurring',
          recurringPaymentId: 'gym',
          createdAt: '2026-05-22T00:00:00.000Z',
          updatedAt: '2026-05-22T00:00:00.000Z',
        },
      ],
    })

    render(<DashboardPage snapshot={snapshot} onViewChange={vi.fn()} />)

    const currentPeriod = screen.getByRole('region', { name: 'Current pay period' })
    expect(within(currentPeriod).getByText('Pay received')).toBeInTheDocument()
    expect(within(currentPeriod).getByText('Total payments due')).toBeInTheDocument()
    expect(within(currentPeriod).getByText('Money left')).toBeInTheDocument()
    expect(within(currentPeriod).getByText('£798.00')).toBeInTheDocument()
    expect(within(currentPeriod).getAllByText('£250.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getByText('£548.00')).toBeInTheDocument()
    expect(screen.queryByText('Safe today')).not.toBeInTheDocument()
    expect(screen.queryByText('Available after bills')).not.toBeInTheDocument()
  })

  it('keeps projection and daily average metrics off the simplified dashboard', () => {
    const snapshot = createSnapshot({
      payPeriods: [
        {
          id: 'period-current',
          startDate: '2026-05-16',
          endDate: '2026-05-29',
          payday: '2026-05-16',
          nextPayday: '2026-05-30',
          incomePence: 90000,
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      transactions: [
        {
          id: 'txn-food',
          potId: 'pot-food',
          payPeriodId: 'period-current',
          amountPence: 1250,
          type: 'spending',
          date: '2026-05-18',
          note: 'Lunch',
          createdAt: '2026-05-18T00:00:00.000Z',
          updatedAt: '2026-05-18T00:00:00.000Z',
        },
      ],
    })

    render(<DashboardPage snapshot={snapshot} onViewChange={vi.fn()} />)

    expect(screen.queryByRole('region', { name: 'Budget insights' })).not.toBeInTheDocument()
    expect(screen.queryByText('Daily average')).not.toBeInTheDocument()
    expect(screen.queryByText('Projected spend')).not.toBeInTheDocument()
  })
})

describe('history page', () => {
  it('deletes a paycheck plan from history after confirmation', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true)

    render(
      <HistoryPage
        snapshot={createSnapshot({
          payPeriods: [
            {
              id: 'period-current',
              startDate: '2026-05-16',
              endDate: '2026-05-29',
              payday: '2026-05-16',
              nextPayday: '2026-05-30',
              incomePence: 90000,
              status: 'active',
              createdAt: '2026-05-16T00:00:00.000Z',
              updatedAt: '2026-05-16T00:00:00.000Z',
            },
          ],
        })}
        actions={actions}
      />,
    )

    await user.click(screen.getByRole('button', { name: 'Delete paycheck plan for 2026-05-16' }))

    expect(confirmSpy).toHaveBeenCalledWith('Delete paycheck plan for 2026-05-16?')
    expect(actions.deletePayPeriod).toHaveBeenCalledWith('period-current')

    confirmSpy.mockRestore()
  })
})

describe('debts page', () => {
  it('records a debt payment against the selected debt', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const today = toIsoDate(new Date())
    const snapshot = createSnapshot({
      debts: [
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
      ],
    })

    render(<DebtsPage snapshot={snapshot} actions={actions} />)

    const paymentPanel = screen.getByRole('region', { name: 'Record debt payment' })
    await user.selectOptions(within(paymentPanel).getByLabelText('Debt'), 'debt-card')
    await user.type(within(paymentPanel).getByLabelText('Payment amount'), '25.00')
    await user.type(within(paymentPanel).getByLabelText('Payment note'), 'Extra payment')
    await user.click(within(paymentPanel).getByRole('button', { name: 'Record payment' }))

    expect(actions.addDebtPayment).toHaveBeenCalledWith({
      amountPence: 2500,
      date: today,
      debtId: 'debt-card',
      note: 'Extra payment',
    })
  })

  it('creates a new debt with amount, due date, lender, and minimum payment', async () => {
    const user = userEvent.setup()
    const actions = createActions()

    render(<DebtsPage snapshot={createSnapshot()} actions={actions} />)

    const debtPanel = screen.getByRole('region', { name: 'Add debt' })
    await user.type(within(debtPanel).getByLabelText('Debt name'), 'Car finance')
    await user.type(within(debtPanel).getByLabelText('Lender'), 'Finance Co')
    await user.type(within(debtPanel).getByLabelText('Current balance'), '4000')
    await user.type(within(debtPanel).getByLabelText('Minimum payment'), '120')
    await user.clear(within(debtPanel).getByLabelText('Due date'))
    await user.type(within(debtPanel).getByLabelText('Due date'), '2026-06-01')
    await user.click(within(debtPanel).getByRole('button', { name: 'Add debt' }))

    expect(actions.addDebt).toHaveBeenCalledWith({
      currentBalancePence: 400000,
      dueDate: '2026-06-01',
      interestRateApr: null,
      lender: 'Finance Co',
      minimumPaymentPence: 12000,
      name: 'Car finance',
      note: '',
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
    addDebt: vi.fn(async () => {}),
    updateDebt: vi.fn(async () => {}),
    deleteDebt: vi.fn(async () => {}),
    addDebtPayment: vi.fn(async () => {}),
    deleteDebtPayment: vi.fn(async () => {}),
    createPaycheckPlan: vi.fn(async () => {}),
    deletePayPeriod: vi.fn(async () => {}),
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
      defaultHoursWorked: 72,
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
    debts: [],
    debtPayments: [],
    ...overrides,
  }
}
