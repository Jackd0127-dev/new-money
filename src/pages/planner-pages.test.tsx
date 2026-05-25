import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { DashboardPage } from './DashboardPage'
import { DebtsPage } from './DebtsPage'
import { HistoryPage } from './HistoryPage'
import { AiPlanPage } from './AiPlanPage'
import { AllocatingPaymentsPage } from './AllocatingPaymentsPage'
import { CalendarPage } from './CalendarPage'
import { PaydayWizardPage } from './PaydayWizardPage'
import { PotsPage } from './PotsPage'
import { RecurringPage } from './RecurringPage'
import { SavingsInvestmentsPage } from './SavingsInvestmentsPage'
import { SettingsPage } from './SettingsPage'
import { SpendingPage } from './SpendingPage'
import { AppAssistant } from '../components/AppAssistant'
import { AppShell } from '../components/AppShell'
import { creditCardDesigns } from '../domain/creditCardDesigns'
import { toIsoDate } from '../domain/money'
import type { FirebaseAuthController } from '../hooks/useFirebaseAuth'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import type { RecurringPayment, Transaction } from '../types/models'

type TestActions = PlannerActions & {
  addDebt: ReturnType<typeof vi.fn>
  addDebtPayment: ReturnType<typeof vi.fn>
  addCreditCard: ReturnType<typeof vi.fn>
  addCreditCardPot: ReturnType<typeof vi.fn>
  addCustomPayment: ReturnType<typeof vi.fn>
  addCreditCardRepayment: ReturnType<typeof vi.fn>
  applyCreditCardPot: ReturnType<typeof vi.fn>
  deletePot: ReturnType<typeof vi.fn>
  deleteCreditCardPot: ReturnType<typeof vi.fn>
  deletePayPeriod: ReturnType<typeof vi.fn>
  updateCreditCard: ReturnType<typeof vi.fn>
  updateCreditCardPot: ReturnType<typeof vi.fn>
  updateCreditCardRepayment: ReturnType<typeof vi.fn>
  updateCustomPayment: ReturnType<typeof vi.fn>
  updatePot: ReturnType<typeof vi.fn>
  upsertPaycheckPotAllocation: ReturnType<typeof vi.fn>
  deletePaycheckPotAllocation: ReturnType<typeof vi.fn>
  updateRecurringPayment: ReturnType<typeof vi.fn>
  updateTransaction: ReturnType<typeof vi.fn>
  addDebtReserve: ReturnType<typeof vi.fn>
  updateDebtReserve: ReturnType<typeof vi.fn>
  cancelDebtReserve: ReturnType<typeof vi.fn>
  skipDebtReserve: ReturnType<typeof vi.fn>
  applyDebtReserve: ReturnType<typeof vi.fn>
}

describe('app shell navigation', () => {
  it('orders tabs around the main paycheck workflow', () => {
    render(
      <AppShell activeView="dashboard" onViewChange={vi.fn()}>
        <div>Page content</div>
      </AppShell>,
    )

    const sidebarNav = screen.getAllByRole('navigation')[0]
    const labels = within(sidebarNav).getAllByRole('button').map((button) => button.textContent)

    expect(labels).toEqual([
      'Dashboard',
      'Pay day',
      'Spending',
      'Allocating Payments',
      'Recurring',
      'Pots',
      'Savings & Investments',
      'Debts',
      'Calendar',
      'AI',
      'Settings',
    ])
  })
})

describe('savings and investments page', () => {
  it('sets aside selected paycheck money into a savings pot', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const selectedPayPeriod = createPayPeriod({
      id: 'period-current',
      startDate: '2026-05-16',
      endDate: '2026-05-29',
      payday: '2026-05-16',
      nextPayday: '2026-05-30',
      incomePence: 90000,
    })
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      pots: [
        {
          id: 'pot-emergency',
          name: 'Emergency fund',
          type: 'saving',
          category: 'Savings',
          icon: 'savings',
          balancePence: 10000,
          targetPence: 100000,
          color: '#16a34a',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
        {
          id: 'pot-index',
          name: 'Index fund',
          type: 'investment',
          category: 'Investments',
          icon: 'target',
          balancePence: 25000,
          targetPence: null,
          color: '#7c3aed',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
        {
          id: 'pot-food',
          name: 'Food',
          type: 'spending',
          balancePence: 12000,
          targetPence: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(
      <SavingsInvestmentsPage
        snapshot={snapshot}
        actions={actions}
        selectedPayPeriod={selectedPayPeriod}
      />,
    )

    expect(screen.getAllByText('Emergency fund').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Index fund').length).toBeGreaterThan(0)
    expect(screen.queryByText('Food')).not.toBeInTheDocument()

    await user.selectOptions(screen.getByLabelText('Savings or investment pot'), 'pot-emergency')
    await user.type(screen.getByLabelText('Amount to set aside'), '35.00')
    await user.click(screen.getByRole('button', { name: 'Set aside money' }))

    expect(actions.upsertPaycheckPotAllocation).toHaveBeenCalledWith({
      id: 'savings-investments-period-current-pot-emergency',
      payPeriodId: 'period-current',
      potId: 'pot-emergency',
      amountPence: 3500,
    })
  })

  it('adds to the existing savings allocation for the selected paycheck', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const selectedPayPeriod = createPayPeriod({
      id: 'period-current',
      startDate: '2026-05-16',
      endDate: '2026-05-29',
      payday: '2026-05-16',
      nextPayday: '2026-05-30',
      incomePence: 90000,
    })
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      pots: [
        {
          id: 'pot-index',
          name: 'Index fund',
          type: 'investment',
          category: 'Investments',
          icon: 'target',
          balancePence: 25000,
          targetPence: null,
          color: '#7c3aed',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      potAllocations: [
        {
          id: 'savings-investments-period-current-pot-index',
          payPeriodId: 'period-current',
          potId: 'pot-index',
          amountPence: 2000,
          source: 'manual',
          recurringPaymentId: null,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(
      <SavingsInvestmentsPage
        snapshot={snapshot}
        actions={actions}
        selectedPayPeriod={selectedPayPeriod}
      />,
    )

    await user.selectOptions(screen.getByLabelText('Savings or investment pot'), 'pot-index')
    await user.type(screen.getByLabelText('Amount to set aside'), '15.00')
    await user.click(screen.getByRole('button', { name: 'Set aside money' }))

    expect(actions.upsertPaycheckPotAllocation).toHaveBeenCalledWith({
      id: 'savings-investments-period-current-pot-index',
      payPeriodId: 'period-current',
      potId: 'pot-index',
      amountPence: 3500,
    })
  })
})

describe('calendar page', () => {
  it('opens a day overview with every money event attached to the clicked date', async () => {
    const user = userEvent.setup()
    const selectedPayPeriod = createPayPeriod({
      id: 'period-current',
      startDate: '2026-05-16',
      endDate: '2026-05-29',
      payday: '2026-05-22',
      nextPayday: '2026-06-05',
      incomePence: 90000,
    })
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      recurringPayments: [
        {
          id: 'rec-phone',
          name: 'Phone',
          amountPence: 2200,
          dueDay: 22,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'important',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      creditCards: [
        {
          id: 'card-amex',
          name: 'Everyday Amex',
          provider: 'Amex',
          limitPence: 100000,
          dueDay: null,
          dueDate: '2026-05-22',
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      customPayments: [
        {
          id: 'custom-mot',
          name: 'MOT',
          amountPence: 4500,
          dueDate: '2026-05-22',
          creditCardId: 'card-amex',
          status: 'unpaid',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      debts: [
        {
          id: 'debt-card',
          name: 'Card balance',
          lender: 'Card Provider',
          originalAmountPence: 30000,
          currentBalancePence: 30000,
          minimumPaymentPence: 0,
          dueDate: '2026-05-22',
          interestRateApr: null,
          note: '',
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      debtReserves: [
        {
          id: 'reserve-card',
          debtId: 'debt-card',
          payPeriodId: 'period-current',
          payday: '2026-05-22',
          periodStartDate: '2026-05-16',
          periodEndDate: '2026-05-29',
          amountPence: 10000,
          status: 'planned',
          source: 'assistant',
          note: 'Set aside before due date',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      debtPayments: [
        {
          id: 'payment-card',
          debtId: 'debt-card',
          amountPence: 5000,
          date: '2026-05-22',
          note: 'Actual payment',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      creditCardRepayments: [
        {
          id: 'repayment-amex',
          creditCardId: 'card-amex',
          amountPence: 2500,
          date: '2026-05-22',
          note: 'Card autopay',
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
      transactions: [
        {
          id: 'txn-lunch',
          potId: 'pot-food',
          payPeriodId: 'period-current',
          amountPence: 1250,
          type: 'spending',
          date: '2026-05-22',
          note: 'Lunch',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<CalendarPage snapshot={snapshot} selectedPayPeriod={selectedPayPeriod} />)

    await user.click(screen.getByRole('button', { name: 'Open 22 May 2026' }))

    expect(screen.getByRole('heading', { name: /Friday.*22 May 2026/ })).toBeInTheDocument()
    expect(screen.getByText('Paycheck received')).toBeInTheDocument()
    expect(screen.getByText('Phone')).toBeInTheDocument()
    expect(screen.getByText('MOT')).toBeInTheDocument()
    expect(screen.getByText('Card balance')).toBeInTheDocument()
    expect(screen.getByText('Card balance reserve')).toBeInTheDocument()
    expect(screen.getByText('Card balance payment')).toBeInTheDocument()
    expect(screen.getByText('Everyday Amex repayment')).toBeInTheDocument()
    expect(screen.getByText('Food allocation')).toBeInTheDocument()
    expect(screen.getByText('Lunch')).toBeInTheDocument()
    expect(screen.getAllByText('Everyday Amex').length).toBeGreaterThan(0)
    expect(screen.getByText('Actual payment')).toBeInTheDocument()
    expect(screen.getByText('Card autopay')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Back to calendar' })).toBeInTheDocument()
  })
})

describe('settings page', () => {
  it('confirms when settings are saved', async () => {
    const user = userEvent.setup()
    const actions = createActions()

    render(<SettingsPage snapshot={createSnapshot()} actions={actions} />)

    expect(screen.queryByText('Settings saved')).not.toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Account' })).toBeInTheDocument()
    expect(screen.getByText('Local planner')).toBeInTheDocument()
    expect(screen.queryByText(/Cloud sync/i)).not.toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Planner data' })).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Save settings' }))

    expect(actions.updateSettings).toHaveBeenCalledWith({
      defaultHoursWorked: 72,
      hourlyRatePence: 1250,
      payFrequency: 'biweekly',
      aiInstructions: '',
      aiProvider: 'gemini',
    })
    expect(screen.getByText('Settings saved')).toBeVisible()
    expect(screen.getByRole('button', { name: 'Save settings' })).toBeDisabled()
  })

  it('saves custom AI instructions with the normal settings form', async () => {
    const user = userEvent.setup()
    const actions = createActions()

    render(<SettingsPage snapshot={createSnapshot()} actions={actions} />)

    fireEvent.change(screen.getByLabelText('Custom AI instructions'), {
      target: { value: 'Be blunt and prioritise debt deadlines.' },
    })
    await user.click(screen.getByRole('button', { name: 'Save settings' }))

    expect(actions.updateSettings).toHaveBeenCalledWith({
      defaultHoursWorked: 72,
      hourlyRatePence: 1250,
      payFrequency: 'biweekly',
      aiInstructions: 'Be blunt and prioritise debt deadlines.',
      aiProvider: 'gemini',
    })
  })

  it('saves the selected AI provider', async () => {
    const user = userEvent.setup()
    const actions = createActions()

    render(<SettingsPage snapshot={createSnapshot()} actions={actions} />)

    await user.selectOptions(screen.getByLabelText('AI provider'), 'openrouter')
    await user.click(screen.getByRole('button', { name: 'Save settings' }))

    expect(actions.updateSettings).toHaveBeenCalledWith({
      defaultHoursWorked: 72,
      hourlyRatePence: 1250,
      payFrequency: 'biweekly',
      aiInstructions: '',
      aiProvider: 'openrouter',
    })
  })

  it('sends a password reset email from account actions', async () => {
    const user = userEvent.setup()
    const auth = createAuth({
      user: createAuthUser({ email: 'money@example.com' }),
    })

    render(<SettingsPage snapshot={createSnapshot()} actions={createActions()} auth={auth} />)

    await user.click(screen.getByRole('button', { name: 'Change password' }))

    expect(auth.sendPasswordResetEmail).toHaveBeenCalledWith('money@example.com')
    expect(screen.getByText('Password reset email sent to money@example.com.')).toBeVisible()
  })

  it('deletes the signed-in account after confirmation', async () => {
    const user = userEvent.setup()
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true)
    const auth = createAuth({
      user: createAuthUser({ email: 'money@example.com' }),
    })

    render(<SettingsPage snapshot={createSnapshot()} actions={createActions()} auth={auth} />)

    await user.click(screen.getByRole('button', { name: 'Delete account' }))

    expect(confirmSpy).toHaveBeenCalledWith(
      'Delete money@example.com? This cannot be undone. Local app data on this device will stay available.',
    )
    expect(auth.deleteAccount).toHaveBeenCalled()
    expect(screen.getByText('Account deleted. Local app data remains on this device.')).toBeVisible()

    confirmSpy.mockRestore()
  })
})

describe('AI page', () => {
  let restoreLocalStorage: (() => void) | null = null

  beforeEach(() => {
    restoreLocalStorage = mockLocalStorage()
  })

  afterEach(() => {
    restoreLocalStorage?.()
    restoreLocalStorage = null
  })

  it('shows the messaging surface without debt-plan controls', () => {
    const selectedPayPeriod = createPayPeriod()

    render(
      <AiPlanPage
        snapshot={createSnapshot({ payPeriods: [selectedPayPeriod] })}
        selectedPayPeriod={selectedPayPeriod}
        user={null}
        actions={createActions()}
      />,
    )

    expect(screen.getByRole('textbox', { name: 'Message AI' })).toHaveClass('min-h-12')
    expect(screen.getByRole('button', { name: 'Send message' })).toBeDisabled()
    expect(screen.getByText('Saved money chats with confirmable actions.')).toBeInTheDocument()
    expect(screen.getByText('Chats')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'New' })).toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Debt recommendations' })).not.toBeInTheDocument()
    expect(screen.queryByText('Set aside this paycheck')).not.toBeInTheDocument()
    expect(screen.queryByText(/Reserve £/)).not.toBeInTheDocument()
  })

  it('sends any user question to the assistant endpoint and shows the answer', async () => {
    const user = userEvent.setup()
    const fetchSpy = vi.spyOn(window, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({
        answer: 'Use the spare cash for the highest-impact move first.',
        highlights: ['Hidden fees'],
        actions: ['Check balances'],
        confidence: 'high',
      }),
    } as Response)
    const authUser = {
      getIdToken: vi.fn(async () => 'test-token'),
    }
    const selectedPayPeriod = createPayPeriod({
      id: 'period-jan-02',
      payday: '2026-01-02',
      startDate: '2026-01-02',
      endDate: '2026-01-15',
      nextPayday: '2026-01-16',
      incomePence: 80000,
    })
    const snapshot = createSnapshot({ payPeriods: [selectedPayPeriod] })

    render(
      <AiPlanPage
        snapshot={snapshot}
        selectedPayPeriod={selectedPayPeriod}
        user={authUser}
        actions={createActions()}
      />,
    )

    await user.type(screen.getByRole('textbox', { name: 'Message AI' }), 'Can I afford my cards this month?')
    await user.click(screen.getByRole('button', { name: 'Send message' }))

    expect(authUser.getIdToken).toHaveBeenCalled()
    expect(fetchSpy).toHaveBeenCalledWith('/api/ai-assistant', expect.objectContaining({
      method: 'POST',
      headers: expect.objectContaining({ Authorization: 'Bearer test-token' }),
      body: expect.stringContaining('Can I afford my cards this month?'),
    }))
    expect(screen.getByText(/Use the spare cash for the highest-impact move first/)).toBeInTheDocument()
    expect(screen.queryByText(/Confidence:/)).not.toBeInTheDocument()

    fetchSpy.mockRestore()
  })

  it('saves conversations and lets users reopen them after leaving the AI page', async () => {
    const user = userEvent.setup()
    const snapshot = createSnapshot()
    const actions = createActions()
    const { unmount } = render(
      <AiPlanPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} user={null} actions={actions} />,
    )

    await user.type(screen.getByRole('textbox', { name: 'Message AI' }), 'How much can I move to savings?')
    await user.click(screen.getByRole('button', { name: 'Send message' }))

    const messages = screen.getByRole('log', { name: 'AI conversation messages' })

    expect(within(messages).getByText('How much can I move to savings?')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Open conversation How much can I move to savings?' })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'New' }))

    const newMessages = screen.getByRole('log', { name: 'AI conversation messages' })

    expect(within(newMessages).queryByText('How much can I move to savings?')).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Open conversation How much can I move to savings?' }))

    expect(within(screen.getByRole('log', { name: 'AI conversation messages' })).getByText('How much can I move to savings?')).toBeInTheDocument()

    unmount()

    render(<AiPlanPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} user={null} actions={actions} />)

    expect(within(screen.getByRole('log', { name: 'AI conversation messages' })).getByText('How much can I move to savings?')).toBeInTheDocument()
  })

  it('customizes the AI name and avatar across the AI page and floating assistant', async () => {
    const user = userEvent.setup()
    const snapshot = createSnapshot()
    const actions = createActions()

    render(
      <>
        <AiPlanPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} user={null} actions={actions} />
        <AppAssistant
          snapshot={snapshot}
          activeView="aiPlan"
          selectedPayPeriod={snapshot.payPeriods[0]}
          actions={actions}
          user={null}
        />
      </>,
    )

    await user.click(screen.getByRole('button', { name: 'Customize' }))
    fireEvent.change(screen.getByLabelText('AI name'), { target: { value: 'Nova' } })
    fireEvent.change(screen.getByLabelText('PFP / initials'), { target: { value: 'NV' } })

    expect(screen.getByRole('heading', { name: 'Nova' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Open AI helper' })).toHaveTextContent('Ask Nova')
    expect(screen.getAllByText('NV').length).toBeGreaterThan(0)
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
    expect(screen.queryByRole('region', { name: 'Payday allocation' })).not.toBeInTheDocument()
    expect(screen.queryByLabelText('Food')).not.toBeInTheDocument()

    await user.clear(screen.getByLabelText('Hours worked'))
    await user.type(screen.getByLabelText('Hours worked'), '86')
    await user.click(screen.getByRole('button', { name: 'Update paycheck plan' }))

    expect(actions.createPaycheckPlan).toHaveBeenCalledWith({
      payday: '2026-05-16',
      payFrequency: 'biweekly',
      hoursWorked: 86,
      hourlyRatePence: 1350,
      actualAmountPence: 120000,
      allocations: [],
    })
  })
})

describe('spending page', () => {
  it('saves quick spend without a pot or credit card link', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const today = toIsoDate(new Date())

    render(<SpendingPage snapshot={createSnapshot()} actions={actions} />)

    await user.click(screen.getByRole('button', { name: '£10.00' }))
    await user.click(screen.getByRole('button', { name: 'Log spending' }))

    expect(actions.addTransaction).toHaveBeenCalledWith({
      amountPence: 1000,
      creditCardId: null,
      date: today,
      note: 'Manual spend',
      payPeriodId: null,
      potId: null,
      type: 'spending',
    })
  })

  it('uses quick amount buttons for faster manual spending entry with an optional note', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const today = toIsoDate(new Date())

    render(<SpendingPage snapshot={createSnapshot()} actions={actions} />)

    await user.click(screen.getByRole('button', { name: '£10.00' }))
    await user.type(screen.getByLabelText('Note'), 'Coffee')
    await user.click(screen.getByRole('button', { name: 'Log spending' }))

    expect(actions.addTransaction).toHaveBeenCalledWith({
      amountPence: 1000,
      creditCardId: null,
      date: today,
      note: 'Coffee',
      payPeriodId: null,
      potId: null,
      type: 'spending',
    })
  })

  it('logs spending against a pot when a pot link is selected', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const today = toIsoDate(new Date())

    render(<SpendingPage snapshot={createSnapshot()} actions={actions} />)

    await user.click(screen.getByRole('button', { name: '£5.00' }))
    await user.selectOptions(screen.getByLabelText('Link spend to'), 'pot')
    await user.selectOptions(screen.getByLabelText('Pot'), 'pot-food')
    await user.click(screen.getByRole('button', { name: 'Log spending' }))

    expect(actions.addTransaction).toHaveBeenCalledWith({
      amountPence: 500,
      creditCardId: null,
      date: today,
      note: 'Manual spend',
      payPeriodId: null,
      paymentMethod: 'pot',
      potId: 'pot-food',
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
      creditCardId: null,
      date: '2026-05-16',
      note: 'Dinner',
      paymentMethod: 'pot',
      potId: 'pot-food',
    })
  })

  it('logs spending against a credit card when credit card payment method is selected', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const today = toIsoDate(new Date())

    render(
      <SpendingPage
        snapshot={createSnapshot({
          creditCards: [
            {
              id: 'card-amex',
              name: 'Everyday Amex',
              provider: 'Amex',
              limitPence: 100000,
              dueDay: 12,
              dueDate: null,
              color: '#2563eb',
              archived: false,
              createdAt: '2026-05-16T00:00:00.000Z',
              updatedAt: '2026-05-16T00:00:00.000Z',
            },
          ],
        })}
        actions={actions}
      />,
    )

    await user.click(screen.getByRole('button', { name: '£20.00' }))
    await user.selectOptions(screen.getByLabelText('Link spend to'), 'credit_card')
    await user.selectOptions(screen.getByLabelText('Credit card'), 'card-amex')
    await user.type(screen.getByLabelText('Note'), 'Groceries')
    await user.click(screen.getByRole('button', { name: 'Log spending' }))

    expect(actions.addTransaction).toHaveBeenCalledWith({
      amountPence: 2000,
      creditCardId: 'card-amex',
      date: today,
      note: 'Groceries',
      paymentMethod: 'credit_card',
      payPeriodId: null,
      potId: null,
      type: 'spending',
    })
  })
})

describe('allocating payments page', () => {
  it('creates a credit card and records a card repayment without showing credit pot controls', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const selectedPayPeriod = createPayPeriod({
      id: 'period-current',
      payday: '2026-05-22',
      startDate: '2026-05-22',
      endDate: '2026-06-04',
      nextPayday: '2026-06-05',
      incomePence: 80000,
    })
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      creditCards: [
        {
          id: 'card-amex',
          name: 'Everyday Amex',
          provider: 'Amex',
          limitPence: 100000,
          dueDay: 12,
          dueDate: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<AllocatingPaymentsPage snapshot={snapshot} actions={actions} selectedPayPeriod={selectedPayPeriod} />)

    const cardPanel = screen.getByRole('region', { name: 'Add credit card' })
    await user.type(within(cardPanel).getByLabelText('Card name'), 'Gold Card')
    await user.type(within(cardPanel).getByLabelText('Provider'), 'Capital One')
    await user.type(within(cardPanel).getByLabelText('Limit'), '1200')
    await user.type(within(cardPanel).getByLabelText('Existing balance'), '250')
    await user.clear(within(cardPanel).getByLabelText('Due date'))
    await user.type(within(cardPanel).getByLabelText('Due date'), '9')
    await user.click(within(cardPanel).getByRole('button', { name: 'Card design' }))
    await user.click(within(screen.getByRole('dialog', { name: 'Card design' })).getByRole('button', { name: 'Blue Card' }))
    await user.click(within(cardPanel).getByRole('button', { name: 'Add card' }))

    expect(actions.addCreditCard).toHaveBeenCalledWith({
      color: '#2563eb',
      designId: 'cart-gradient-12',
      dueDate: null,
      dueDay: 9,
      limitPence: 120000,
      name: 'Gold Card',
      openingBalancePence: 25000,
      provider: 'Capital One',
    })

    expect(screen.queryByRole('region', { name: 'Add saved payment' })).not.toBeInTheDocument()

    expect(screen.queryByRole('region', { name: 'Credit Pots' })).not.toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Credit pots' })).not.toBeInTheDocument()

    const repaymentPanel = screen.getByRole('region', { name: 'Record card repayment' })
    await user.type(within(repaymentPanel).getByLabelText('Amount'), '12.50')
    await user.type(within(repaymentPanel).getByLabelText('Note'), 'Part payment')
    await user.click(within(repaymentPanel).getByRole('button', { name: 'Record repayment' }))

    expect(actions.addCreditCardRepayment).toHaveBeenCalledWith({
      amountPence: 1250,
      creditCardId: 'card-amex',
      date: toIsoDate(new Date()),
      note: 'Part payment',
    })
    expect(actions.addCreditCardPot).not.toHaveBeenCalled()
  })

  it('shows credit card diagrams and paycheck impact from linked payments', () => {
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
      creditCards: [
        {
          id: 'card-amex',
          name: 'Everyday Amex',
          provider: 'Amex',
          limitPence: 100000,
          dueDay: 12,
          dueDate: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'rec-phone',
          name: 'Phone',
          amountPence: 2200,
          dueDay: 23,
          frequency: 'monthly',
          potId: 'pot-bills',
          creditCardId: 'card-amex',
          priority: 'important',
          active: true,
          createdAt: '2026-05-01T00:00:00.000Z',
          updatedAt: '2026-05-01T00:00:00.000Z',
        },
      ],
      transactions: [
        {
          id: 'txn-card',
          potId: 'pot-food',
          payPeriodId: 'period-current',
          amountPence: 5000,
          type: 'spending',
          paymentMethod: 'credit_card',
          creditCardId: 'card-amex',
          date: '2026-05-18',
          note: 'Groceries',
          createdAt: '2026-05-18T00:00:00.000Z',
          updatedAt: '2026-05-18T00:00:00.000Z',
        },
      ],
    })

    render(
      <AllocatingPaymentsPage
        snapshot={snapshot}
        actions={createActions()}
        selectedPayPeriod={snapshot.payPeriods[0]}
      />,
    )

    expect(screen.getByRole('button', { name: 'Open Everyday Amex card details' })).toBeInTheDocument()
    const cardVisual = screen.getByLabelText('Everyday Amex credit card')
    expect(cardVisual).toHaveAttribute('data-figma-design', 'cart-minimal-11')
    expect(cardVisual).toHaveAttribute('data-node-id', '3114:376')
    expect(screen.getAllByText('Everyday Amex').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Day 12').length).toBeGreaterThan(0)
    expect(screen.getAllByText('£1,000.00').length).toBeGreaterThan(0)
    expect(screen.getAllByText('£72.00').length).toBeGreaterThan(0)
    expect(screen.getAllByText('£928.00').length).toBeGreaterThan(0)
    expect(screen.queryByText('Pay left after cards')).not.toBeInTheDocument()
    expect(screen.getAllByText('Groceries').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Phone').length).toBeGreaterThan(0)
  })

  it('orders and expands credit summary cards independently', async () => {
    const user = userEvent.setup()
    const selectedPayPeriod = createPayPeriod()
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      creditCards: [
        {
          id: 'card-amex',
          name: 'Everyday Amex',
          provider: 'Amex',
          limitPence: 100000,
          openingBalancePence: 20000,
          dueDay: 12,
          dueDate: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<AllocatingPaymentsPage snapshot={snapshot} actions={createActions()} selectedPayPeriod={selectedPayPeriod} />)

    const summaryPanel = screen.getByRole('region', { name: 'Credit card summary' })
    const metricLabels = within(summaryPanel)
      .getAllByText(/Selected pay|Credit pots|Cards owed/)
      .filter((element) => element.closest('summary'))
      .map((element) => element.textContent)

    expect(metricLabels).toEqual(['Selected pay', 'Credit pots', 'Cards owed'])

    const selectedPay = getMetricDetails(summaryPanel, 'Selected pay')
    const creditPots = getMetricDetails(summaryPanel, 'Credit pots')
    const cardsOwed = getMetricDetails(summaryPanel, 'Cards owed')

    await user.click(within(selectedPay).getByText('Show calculation'))
    expect(selectedPay).toHaveAttribute('open')
    expect(creditPots).not.toHaveAttribute('open')
    expect(cardsOwed).not.toHaveAttribute('open')

    await user.click(within(creditPots).getByText('Show calculation'))
    expect(selectedPay).not.toHaveAttribute('open')
    expect(creditPots).toHaveAttribute('open')
    expect(cardsOwed).not.toHaveAttribute('open')

    await user.click(within(cardsOwed).getByText('Show calculation'))
    expect(selectedPay).not.toHaveAttribute('open')
    expect(creditPots).not.toHaveAttribute('open')
    expect(cardsOwed).toHaveAttribute('open')
  })

  it('offers and renders the teal credit card design', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const selectedPayPeriod = createPayPeriod()
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      creditCards: [
        {
          id: 'card-mint',
          name: 'Mint Travel',
          provider: 'Mastercard',
          limitPence: 200000,
          openingBalancePence: 34550,
          designId: 'cart-geometric-4',
          dueDay: 2,
          dueDate: null,
          color: '#14b8a6',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    const { container } = render(
      <AllocatingPaymentsPage snapshot={snapshot} actions={actions} selectedPayPeriod={selectedPayPeriod} />,
    )

    const cardVisual = screen.getByLabelText('Mint Travel credit card')
    expect(cardVisual).toHaveAttribute('data-figma-design', 'cart-geometric-4')
    expect(cardVisual).toHaveAttribute('data-node-id', '1730:4631')
    expect(container.querySelector('img[src="/figma-assets/cart-geometric-4/mastercard-logo.svg"]')).not.toBeNull()
    expect(container.querySelector('img[src="/figma-assets/cart-geometric-4/bottom-panel.svg"]')).not.toBeNull()

    const cardPanel = screen.getByRole('region', { name: 'Add credit card' })
    await user.type(within(cardPanel).getByLabelText('Card name'), 'Mint Reserve')
    await user.type(within(cardPanel).getByLabelText('Provider'), 'Mastercard')
    await user.type(within(cardPanel).getByLabelText('Limit'), '900')
    await user.click(within(cardPanel).getByRole('button', { name: 'Card design' }))
    await user.click(within(screen.getByRole('dialog', { name: 'Card design' })).getByRole('button', { name: 'Teal Card' }))
    await user.click(within(cardPanel).getByRole('button', { name: 'Add card' }))

    expect(actions.addCreditCard).toHaveBeenCalledWith(expect.objectContaining({ designId: 'cart-geometric-4' }))
  })

  it('offers clean colorway names as separate card designs', async () => {
    const geometric4Colorways = [
      ['cart-geometric-4-blue', 'Royal Blue Card'],
      ['cart-geometric-4-red', 'Red Card'],
      ['cart-geometric-4-black', 'Black Card'],
      ['cart-geometric-4-orange', 'Orange Card'],
      ['cart-geometric-4-gray', 'Grey Card'],
      ['cart-geometric-4-gold', 'Gold Card'],
      ['cart-geometric-4-light-blue', 'Light Blue Card'],
      ['cart-geometric-4-teal', 'Deep Teal Card'],
      ['cart-geometric-4-maroon', 'Maroon Card'],
      ['cart-geometric-4-violet', 'Violet Card'],
    ]
    const user = userEvent.setup()
    const actions = createActions()
    const selectedPayPeriod = createPayPeriod()
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      creditCards: [
        {
          id: 'card-maroon',
          name: 'Maroon Travel',
          provider: 'Mastercard',
          limitPence: 180000,
          openingBalancePence: 0,
          designId: 'cart-geometric-4-maroon',
          dueDay: 11,
          dueDate: null,
          color: '#7f1d1d',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    for (const [id, label] of geometric4Colorways) {
      expect(creditCardDesigns).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            assetPath: `/figma-assets/${id}`,
            id,
            label,
            network: 'mastercard',
            nodeId: '1730:4631',
          }),
        ]),
      )
    }

    const { container } = render(
      <AllocatingPaymentsPage snapshot={snapshot} actions={actions} selectedPayPeriod={selectedPayPeriod} />,
    )

    const cardVisual = screen.getByLabelText('Maroon Travel credit card')
    expect(cardVisual).toHaveAttribute('data-figma-design', 'cart-geometric-4-maroon')
    expect(container.querySelector('img[src="/figma-assets/cart-geometric-4-maroon/mastercard-logo.svg"]')).not.toBeNull()
    expect(container.querySelector('img[src="/figma-assets/cart-geometric-4-maroon/bottom-panel.svg"]')).toBeNull()

    const cardPanel = screen.getByRole('region', { name: 'Add credit card' })

    expect(within(cardPanel).queryByRole('button', { name: 'Gold Card' })).not.toBeInTheDocument()
    await user.click(within(cardPanel).getByRole('button', { name: 'Card design' }))
    const designDialog = screen.getByRole('dialog', { name: 'Card design' })

    for (const [, label] of geometric4Colorways) {
      expect(within(designDialog).getByRole('button', { name: label })).toBeInTheDocument()
    }
    expect(designDialog.querySelector('img[src$="/reference.png"]')).toBeNull()
    expect(designDialog.querySelector('.credit-card-design-picker__art')).not.toBeNull()
    await user.click(within(designDialog).getByRole('button', { name: 'Gold Card' }))

    await user.type(within(cardPanel).getByLabelText('Card name'), 'Gold Reserve')
    await user.type(within(cardPanel).getByLabelText('Provider'), 'Mastercard')
    await user.type(within(cardPanel).getByLabelText('Limit'), '900')
    await user.click(within(cardPanel).getByRole('button', { name: 'Add card' }))

    expect(actions.addCreditCard).toHaveBeenCalledWith(expect.objectContaining({ designId: 'cart-geometric-4-gold' }))
  })

  it('offers and renders the bright blue credit card design', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const selectedPayPeriod = createPayPeriod()
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      creditCards: [
        {
          id: 'card-blue',
          name: 'Blue Travel',
          provider: 'Visa',
          limitPence: 150000,
          openingBalancePence: 20000,
          designId: 'cart-geometric-1',
          dueDay: 5,
          dueDate: null,
          color: '#0e8bff',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    const { container } = render(
      <AllocatingPaymentsPage snapshot={snapshot} actions={actions} selectedPayPeriod={selectedPayPeriod} />,
    )

    const cardVisual = screen.getByLabelText('Blue Travel credit card')
    expect(cardVisual).toHaveAttribute('data-figma-design', 'cart-geometric-1')
    expect(cardVisual).toHaveAttribute('data-node-id', '1730:3774')
    expect(container.querySelector('img[src="/figma-assets/cart-geometric-1/visa-logo.svg"]')).not.toBeNull()

    const cardPanel = screen.getByRole('region', { name: 'Add credit card' })
    await user.type(within(cardPanel).getByLabelText('Card name'), 'Blue Reserve')
    await user.type(within(cardPanel).getByLabelText('Provider'), 'Visa')
    await user.type(within(cardPanel).getByLabelText('Limit'), '900')
    await user.click(within(cardPanel).getByRole('button', { name: 'Card design' }))
    await user.click(within(screen.getByRole('dialog', { name: 'Card design' })).getByRole('button', { name: 'Bright Blue Card' }))
    await user.click(within(cardPanel).getByRole('button', { name: 'Add card' }))

    expect(actions.addCreditCard).toHaveBeenCalledWith(expect.objectContaining({ designId: 'cart-geometric-1' }))
  })

  it('uses a simplified card details view with a card edit dialog', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const snapshot = createSnapshot({
      payPeriods: [createPayPeriod()],
      creditCards: [
        {
          id: 'card-amex',
          name: 'Everyday Amex',
          provider: 'Amex',
          limitPence: 100000,
          openingBalancePence: 20000,
          designId: 'cart-geometric-15',
          dueDay: 12,
          dueDate: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      transactions: [
        {
          id: 'txn-card',
          potId: 'pot-food',
          payPeriodId: 'period-current',
          amountPence: 5000,
          type: 'spending',
          paymentMethod: 'credit_card',
          creditCardId: 'card-amex',
          date: '2026-05-18',
          note: 'Groceries',
          createdAt: '2026-05-18T00:00:00.000Z',
          updatedAt: '2026-05-18T00:00:00.000Z',
        },
      ],
    })

    render(<AllocatingPaymentsPage snapshot={snapshot} actions={actions} selectedPayPeriod={snapshot.payPeriods[0]} />)

    await user.click(screen.getByRole('button', { name: 'Open Everyday Amex card details' }))

    expect(screen.getByRole('region', { name: 'Card activity' })).toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Credit pots for this card' })).not.toBeInTheDocument()
    expect(screen.getAllByText('Balance').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Available').length).toBeGreaterThan(0)

    await user.click(screen.getByRole('button', { name: 'Edit card' }))

    const dialog = screen.getByRole('dialog', { name: 'Edit credit card' })
    await user.clear(within(dialog).getByLabelText('Card name'))
    await user.type(within(dialog).getByLabelText('Card name'), 'Updated Amex')
    await user.click(within(dialog).getByRole('button', { name: 'Save card' }))

    expect(actions.updateCreditCard).toHaveBeenCalledWith('card-amex', {
      color: '#2563eb',
      designId: 'cart-geometric-15',
      dueDate: null,
      dueDay: 12,
      limitPence: 100000,
      name: 'Updated Amex',
      openingBalancePence: 20000,
      provider: 'Amex',
    })
  })
})

describe('pots page', () => {
  it('edits and deletes pots after confirmation', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true)

    render(<PotsPage snapshot={createSnapshot()} actions={actions} />)

    await user.click(screen.getByRole('button', { name: 'Edit Food' }))

    expect(screen.queryByRole('dialog', { name: 'Create pot' })).not.toBeInTheDocument()
    const editDialog = screen.getByRole('dialog', { name: 'Edit pot' })
    await user.clear(within(editDialog).getByLabelText('Pot name'))
    await user.type(within(editDialog).getByLabelText('Pot name'), 'Groceries')
    await user.click(within(editDialog).getByRole('button', { name: 'Save pot' }))

    expect(actions.updatePot).toHaveBeenCalledWith('pot-food', {
      balancePence: 12000,
      category: 'Spending',
      color: '#16a34a',
      icon: 'food',
      linkedCreditCardId: null,
      linkedDebtId: null,
      name: 'Groceries',
      targetPence: null,
      type: 'spending',
    })
    expect(screen.queryByRole('dialog', { name: 'Edit pot' })).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Delete Food' }))

    expect(confirmSpy).toHaveBeenCalledWith('Delete Food?')
    expect(actions.deletePot).toHaveBeenCalledWith('pot-food')

    confirmSpy.mockRestore()
  })

  it('creates a pot linked to a credit card reserve target', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const snapshot = createSnapshot({
      creditCards: [
        {
          id: 'card-amex',
          name: 'Everyday Amex',
          provider: 'Amex',
          limitPence: 80000,
          openingBalancePence: 60000,
          dueDay: 1,
          dueDate: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<PotsPage snapshot={snapshot} actions={actions} />)

    await user.click(screen.getByRole('button', { name: 'Create pot' }))
    const createDialog = screen.getByRole('dialog', { name: 'Create pot' })
    await user.type(within(createDialog).getByLabelText('Pot name'), 'Amex reserve')
    await user.type(within(createDialog).getByLabelText(/Current balance/), '400.00')
    await user.selectOptions(within(createDialog).getByLabelText('Link this pot to'), 'credit_card')
    await user.selectOptions(within(createDialog).getByLabelText('Credit card'), 'card-amex')
    await user.click(within(createDialog).getByRole('button', { name: 'Add pot' }))

    expect(actions.addPot).toHaveBeenCalledWith({
      balancePence: 40000,
      category: 'Spending',
      color: '#2563eb',
      icon: 'wallet',
      linkedCreditCardId: 'card-amex',
      linkedDebtId: null,
      name: 'Amex reserve',
      targetPence: null,
      type: 'spending',
    })
  })

  it('creates a custom pot section and saves the selected symbol', async () => {
    const user = userEvent.setup()
    const actions = createActions()

    render(<PotsPage snapshot={createSnapshot()} actions={actions} />)

    await user.click(screen.getByRole('button', { name: 'Add pot category' }))
    await user.type(screen.getByLabelText('New pot category'), 'Travel')
    await user.click(screen.getByRole('button', { name: 'Add section' }))

    expect(screen.getByRole('button', { name: 'Travel' })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Create pot' }))
    const createDialog = screen.getByRole('dialog', { name: 'Create pot' })
    await user.type(within(createDialog).getByLabelText('Pot name'), 'Holiday')
    await user.click(within(createDialog).getByRole('button', { name: 'Use Shield symbol' }))
    await user.click(within(createDialog).getByRole('button', { name: 'Add pot' }))

    expect(actions.addPot).toHaveBeenCalledWith({
      balancePence: 0,
      category: 'Travel',
      color: '#2563eb',
      icon: 'shield',
      linkedCreditCardId: null,
      linkedDebtId: null,
      name: 'Holiday',
      targetPence: null,
      type: 'spending',
    })
  })

  it('tops up a pot from the selected paycheck allocation', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const selectedPayPeriod = createPayPeriod({
      id: 'period-current',
      startDate: '2026-05-16',
      endDate: '2026-05-29',
      payday: '2026-05-16',
      nextPayday: '2026-05-30',
      incomePence: 90000,
    })

    render(
      <PotsPage
        snapshot={createSnapshot({ payPeriods: [selectedPayPeriod] })}
        actions={actions}
        selectedPayPeriod={selectedPayPeriod}
      />,
    )

    await user.selectOptions(screen.getByLabelText('Pot to top up'), 'pot-food')
    await user.type(screen.getByLabelText('Top up amount'), '25.00')
    await user.click(screen.getByRole('button', { name: 'Top up pot' }))

    expect(actions.upsertPaycheckPotAllocation).toHaveBeenCalledWith({
      id: 'pot-top-up-period-current-pot-food',
      payPeriodId: 'period-current',
      potId: 'pot-food',
      amountPence: 2500,
    })
  })

  it('adds another top-up to the existing paycheck pot allocation', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const selectedPayPeriod = createPayPeriod({
      id: 'period-current',
      startDate: '2026-05-16',
      endDate: '2026-05-29',
      payday: '2026-05-16',
      nextPayday: '2026-05-30',
      incomePence: 90000,
    })

    render(
      <PotsPage
        snapshot={createSnapshot({
          payPeriods: [selectedPayPeriod],
          potAllocations: [
            {
              id: 'pot-top-up-period-current-pot-food',
              payPeriodId: 'period-current',
              potId: 'pot-food',
              amountPence: 1000,
              source: 'manual',
              recurringPaymentId: null,
              createdAt: '2026-05-16T00:00:00.000Z',
              updatedAt: '2026-05-16T00:00:00.000Z',
            },
          ],
        })}
        actions={actions}
        selectedPayPeriod={selectedPayPeriod}
      />,
    )

    await user.selectOptions(screen.getByLabelText('Pot to top up'), 'pot-food')
    await user.type(screen.getByLabelText('Top up amount'), '15.00')
    await user.click(screen.getByRole('button', { name: 'Top up pot' }))

    expect(actions.upsertPaycheckPotAllocation).toHaveBeenCalledWith({
      id: 'pot-top-up-period-current-pot-food',
      payPeriodId: 'period-current',
      potId: 'pot-food',
      amountPence: 2500,
    })
  })

  it('shows the linked debt balance as the pot target', () => {
    const snapshot = createSnapshot({
      pots: [
        {
          id: 'pot-airbnb',
          name: 'AIRBNB',
          type: 'reserved',
          category: 'Bills',
          icon: 'home',
          balancePence: 12500,
          targetPence: null,
          color: '#2563eb',
          linkedCreditCardId: null,
          linkedDebtId: 'debt-airbnb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      debts: [
        {
          id: 'debt-airbnb',
          name: 'AIRBNB',
          lender: 'AIRBNB',
          originalAmountPence: 50000,
          currentBalancePence: 50000,
          minimumPaymentPence: 0,
          dueDate: '2026-06-10',
          interestRateApr: null,
          note: '',
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<PotsPage snapshot={snapshot} actions={createActions()} />)

    expect(screen.getByText('Target £500.00')).toBeInTheDocument()
    expect(screen.getByText('25%')).toBeInTheDocument()
  })

  it('shows the true percentage when a pot is over target', () => {
    const snapshot = createSnapshot({
      pots: [
        {
          id: 'pot-emergency',
          name: 'Emergency fund',
          type: 'saving',
          category: 'Savings',
          icon: 'savings',
          balancePence: 11400,
          targetPence: 10000,
          color: '#16a34a',
          linkedCreditCardId: null,
          linkedDebtId: null,
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<PotsPage snapshot={snapshot} actions={createActions()} />)

    expect(screen.getByText('114%')).toBeInTheDocument()
    expect(screen.queryByText('100%')).not.toBeInTheDocument()
  })

  it('shows the true percentage for over-target savings and investments pots', () => {
    const snapshot = createSnapshot({
      pots: [
        {
          id: 'pot-emergency',
          name: 'Emergency fund',
          type: 'saving',
          category: 'Savings',
          icon: 'savings',
          balancePence: 11400,
          targetPence: 10000,
          color: '#16a34a',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<SavingsInvestmentsPage snapshot={snapshot} actions={createActions()} selectedPayPeriod={null} />)

    expect(screen.getByText('114%')).toBeInTheDocument()
    expect(screen.queryByText('100%')).not.toBeInTheDocument()
  })

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
    expect(within(activity).getAllByText('Lunch').length).toBeGreaterThan(0)
    expect(within(activity).getAllByText('Spending · 2026-05-17').length).toBeGreaterThan(0)
    expect(within(activity).getAllByText('-£12.50').length).toBeGreaterThan(0)
    expect(within(activity).getAllByText('Paycheck allocation').length).toBeGreaterThan(0)
    expect(within(activity).getAllByText('Allocation · 2026-05-16').length).toBeGreaterThan(0)
    expect(within(activity).getAllByText('+£75.00').length).toBeGreaterThan(0)
    expect(within(activity).getAllByText('Meal kit').length).toBeGreaterThan(0)
    expect(within(activity).getByText('Linked recurring payments')).toBeInTheDocument()
    expect(within(activity).getByText('monthly · due day 20')).toBeInTheDocument()
    expect(within(activity).getByText('£18.00')).toBeInTheDocument()
    expect(within(activity).queryByText('Direct debit')).not.toBeInTheDocument()
  })

  it('shows pot card progress from linked recurring, credit card, and debt obligations', () => {
    const snapshot = createSnapshot({
      pots: [
        {
          id: 'pot-car',
          name: 'Car Insurance',
          type: 'reserved',
          category: 'Bills',
          icon: 'shield',
          balancePence: 8711,
          targetPence: null,
          color: '#7c3aed',
          linkedCreditCardId: null,
          linkedDebtId: null,
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
        {
          id: 'pot-card',
          name: 'Capital One',
          type: 'spending',
          category: 'Spending',
          icon: 'card',
          balancePence: 40000,
          targetPence: null,
          color: '#ea580c',
          linkedCreditCardId: 'card-capital-one',
          linkedDebtId: null,
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
        {
          id: 'pot-debt',
          name: 'AIRBNB',
          type: 'reserved',
          category: 'Bills',
          icon: 'home',
          balancePence: 34678,
          targetPence: null,
          color: '#2563eb',
          linkedCreditCardId: null,
          linkedDebtId: 'debt-airbnb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'rec-car',
          name: 'Car insurance',
          amountPence: 8711,
          dueDay: 1,
          frequency: 'monthly',
          potId: 'pot-car',
          creditCardId: null,
          priority: 'essential',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      creditCards: [
        {
          id: 'card-capital-one',
          name: 'Capital One',
          provider: 'Capital One',
          limitPence: 80000,
          openingBalancePence: 60000,
          dueDay: 5,
          dueDate: null,
          color: '#ea580c',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      debts: [
        {
          id: 'debt-airbnb',
          name: 'AIRBNB',
          lender: 'AIRBNB',
          originalAmountPence: 55741,
          currentBalancePence: 55741,
          minimumPaymentPence: 0,
          dueDate: '2026-06-05',
          interestRateApr: null,
          note: '',
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<PotsPage snapshot={snapshot} actions={createActions()} />)

    expect(screen.getByText('100%')).toBeInTheDocument()
    expect(screen.getByText('Target £87.11')).toBeInTheDocument()
    expect(screen.getByText('67%')).toBeInTheDocument()
    expect(screen.getByText('Target £600.00')).toBeInTheDocument()
    expect(screen.getByText('62%')).toBeInTheDocument()
    expect(screen.getByText('Target £557.41')).toBeInTheDocument()
  })
})

describe('recurring page', () => {
  it('removes the recurring calendar and keeps the payment list visible', () => {
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
        {
          id: 'rec-broadband',
          name: 'Broadband',
          amountPence: 3200,
          dueDay: 15,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'important',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<RecurringPage snapshot={snapshot} actions={createActions()} />)

    expect(screen.queryByRole('region', { name: 'Recurring calendar' })).not.toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Recurring payments' })).toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'What you owe next payday' })).toBeInTheDocument()
    expect(screen.getAllByText('Phone').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Broadband').length).toBeGreaterThan(0)
  })

  it('shows a next payday owed dropdown with the next pay period costs', () => {
    const snapshot = createSnapshot({
      pots: [
        {
          id: 'pot-bills',
          name: 'Bills',
          type: 'reserved',
          balancePence: 0,
          targetPence: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'rec-rent',
          name: 'Rent',
          amountPence: 65000,
          dueDay: 1,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'essential',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      customPayments: [
        {
          id: 'custom-mot',
          name: 'MOT',
          amountPence: 4500,
          dueDate: '2026-06-02',
          creditCardId: null,
          status: 'unpaid',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      debts: [
        {
          id: 'debt-loan',
          name: 'Loan',
          lender: 'Finance Co',
          originalAmountPence: 100000,
          currentBalancePence: 80000,
          minimumPaymentPence: 4000,
          dueDate: '2026-06-03',
          interestRateApr: null,
          note: '',
          status: 'active',
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
          payFrequency: 'biweekly',
          incomePence: 90000,
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<RecurringPage snapshot={snapshot} actions={createActions()} selectedPayPeriod={snapshot.payPeriods[0]} />)

    const nextPaydayPanel = screen.getByRole('region', { name: 'What you owe next payday' })
    expect(within(nextPaydayPanel).getAllByText('Total owed next payday').length).toBeGreaterThan(0)
    expect(within(nextPaydayPanel).getByText('2026-05-30 to 2026-06-12')).toBeInTheDocument()
    expect(within(nextPaydayPanel).getAllByText('£1,495.00').length).toBeGreaterThan(0)
    expect(within(nextPaydayPanel).getByText('Rent')).toBeInTheDocument()
    expect(within(nextPaydayPanel).getByText('MOT')).toBeInTheDocument()
    expect(within(nextPaydayPanel).getByText('Loan')).toBeInTheDocument()
  })

  it('creates a card-linked recurring payment without a pot', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const snapshot = createSnapshot({
      creditCards: [
        {
          id: 'card-aqua',
          name: 'Aqua',
          provider: 'Aqua',
          limitPence: 80000,
          dueDay: 5,
          dueDate: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<RecurringPage snapshot={snapshot} actions={actions} />)

    await user.type(screen.getByLabelText('Name'), 'Spotify')
    await user.type(screen.getByLabelText('Amount'), '11.99')
    await user.clear(screen.getByLabelText('Due day'))
    await user.type(screen.getByLabelText('Due day'), '12')
    await user.selectOptions(screen.getByLabelText('Paid from pot'), '')
    await user.selectOptions(screen.getByLabelText('Paid on credit card'), 'card-aqua')
    await user.click(screen.getByRole('button', { name: 'Add recurring payment' }))

    expect(actions.addRecurringPayment).toHaveBeenCalledWith({
      amountPence: 1199,
      creditCardId: 'card-aqua',
      dueDay: 12,
      frequency: 'monthly',
      name: 'Spotify',
      potId: null,
      priority: 'essential',
    })
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

    const editDialog = screen.getByRole('dialog', { name: 'Edit recurring payment' })
    await user.clear(within(editDialog).getByLabelText('Amount'))
    await user.type(within(editDialog).getByLabelText('Amount'), '25.50')
    await user.selectOptions(within(editDialog).getByLabelText('Frequency'), 'yearly')
    await user.click(within(editDialog).getByRole('button', { name: 'Save recurring payment' }))

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
  it('lets the selected pay period change from the dashboard selector', async () => {
    const user = userEvent.setup()
    const onPayPeriodChange = vi.fn()
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
        {
          id: 'period-next',
          startDate: '2026-05-30',
          endDate: '2026-06-12',
          payday: '2026-05-30',
          nextPayday: '2026-06-13',
          incomePence: 95000,
          status: 'planned',
          createdAt: '2026-05-30T00:00:00.000Z',
          updatedAt: '2026-05-30T00:00:00.000Z',
        },
      ],
    })

    render(
      <DashboardPage
        snapshot={snapshot}
        selectedPayPeriod={snapshot.payPeriods[0]}
        onPayPeriodChange={onPayPeriodChange}
        onViewChange={vi.fn()}
      />,
    )

    await user.selectOptions(screen.getByRole('combobox', { name: 'Viewing pay period' }), 'period-next')

    expect(onPayPeriodChange).toHaveBeenCalledWith('period-next')
  })

  it('shows one clear pay summary with correct current period maths', () => {
    const snapshot = createSnapshot({
      pots: [
        {
          id: 'pot-bills',
          name: 'Bills',
          type: 'reserved',
          balancePence: 0,
          targetPence: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
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

    render(<DashboardPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} onViewChange={vi.fn()} />)

    const currentPeriod = screen.getByRole('region', { name: 'Selected pay period' })
    expect(within(currentPeriod).getAllByText('Total pay').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('Total costs').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('Money left').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£798.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£250.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£548.00').length).toBeGreaterThan(0)
    expect(screen.queryByText('Safe today')).not.toBeInTheDocument()
    expect(screen.queryByText('Available after bills')).not.toBeInTheDocument()
  })

  it('shows a per-paycheck to-do list and marks set-asides complete', async () => {
    const user = userEvent.setup()
    const restoreLocalStorage = mockLocalStorage()
    const snapshot = createSnapshot({
      payPeriods: [createPayPeriod({ id: 'period-current', incomePence: 120000 })],
      pots: [
        {
          id: 'pot-bills',
          name: 'Bills',
          type: 'reserved',
          balancePence: 0,
          targetPence: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
        {
          id: 'pot-food',
          name: 'Food',
          type: 'spending',
          balancePence: 12000,
          targetPence: null,
          color: '#16a34a',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'insurance',
          name: 'Car Insurance',
          amountPence: 8500,
          dueDay: 1,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'essential',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
        {
          id: 'council-tax',
          name: 'Council Tax',
          amountPence: 6000,
          dueDay: 20,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'essential',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      potAllocations: [
        {
          id: 'allocation-food',
          payPeriodId: 'period-current',
          potId: 'pot-food',
          amountPence: 14000,
          source: 'manual',
          recurringPaymentId: null,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
        {
          id: 'allocation-insurance',
          payPeriodId: 'period-current',
          potId: 'pot-bills',
          amountPence: 8500,
          source: 'recurring',
          recurringPaymentId: 'insurance',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
        {
          id: 'allocation-savings-topup',
          payPeriodId: 'period-current',
          potId: 'pot-bills',
          amountPence: 2211,
          source: 'pot_auto',
          recurringPaymentId: null,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      debts: [
        {
          id: 'debt-loan',
          name: 'Loan',
          lender: 'Finance Co',
          originalAmountPence: 100000,
          currentBalancePence: 80000,
          minimumPaymentPence: 4000,
          dueDate: '2026-05-25',
          interestRateApr: null,
          note: '',
          status: 'active',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      debtReserves: [
        {
          id: 'reserve-loan',
          debtId: 'debt-loan',
          payPeriodId: 'period-current',
          payday: '2026-05-16',
          periodStartDate: '2026-05-16',
          periodEndDate: '2026-05-29',
          amountPence: 20000,
          status: 'planned',
          source: 'manual',
          note: 'Loan reserve',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      creditCards: [
        {
          id: 'card-amex',
          name: 'Everyday Amex',
          provider: 'Amex',
          limitPence: 100000,
          dueDay: 1,
          dueDate: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      creditCardPots: [
        {
          id: 'credit-pot-amex',
          creditCardId: 'card-amex',
          payPeriodId: 'period-current',
          payday: '2026-05-16',
          periodStartDate: '2026-05-16',
          periodEndDate: '2026-05-29',
          name: 'Amex payoff',
          amountPence: 5000,
          source: 'paycheck',
          status: 'active',
          note: 'Card set-aside',
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    const { unmount } = render(
      <DashboardPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} onViewChange={vi.fn()} />,
    )

    const todoList = screen.getByRole('region', { name: 'Paycheck to-do list' })
    expect(within(todoList).getByText('0 of 7 done.', { exact: false })).toBeInTheDocument()
    expect(within(todoList).getByText('Set aside £140.00 into "Food" pot')).toBeInTheDocument()
    expect(within(todoList).getByText('Set aside £85.00 into "Bills" pot for "Car Insurance"')).toBeInTheDocument()
    expect(within(todoList).getByText('Set aside £60.00 into "Bills" pot for "Council Tax"')).toBeInTheDocument()
    expect(within(todoList).getByText('Set aside £22.11 into "Bills" pot')).toBeInTheDocument()
    expect(within(todoList).getByText('Set aside £200.00 for "Loan" debt')).toBeInTheDocument()
    expect(within(todoList).getByText('Pay £600.00 toward "Loan" debt')).toBeInTheDocument()
    expect(within(todoList).getByText('Set aside £50.00 for "Everyday Amex" card')).toBeInTheDocument()

    const foodCheckbox = within(todoList).getByRole('checkbox', {
      name: /Set aside £140\.00 into "Food" pot/,
    })
    await user.click(foodCheckbox)

    expect(foodCheckbox).toBeChecked()
    expect(foodCheckbox.closest('li')).toHaveClass('bg-emerald-50')
    expect(within(todoList).getByText('1 of 7 done.', { exact: false })).toBeInTheDocument()

    unmount()

    render(<DashboardPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} onViewChange={vi.fn()} />)

    expect(screen.getByRole('checkbox', { name: /Set aside £140\.00 into "Food" pot/ })).toBeChecked()
    restoreLocalStorage()
  })

  it('moves money into a pot when a dashboard set-aside is checked', async () => {
    const user = userEvent.setup()
    const actions = createActions()
    const restoreLocalStorage = mockLocalStorage()
    const selectedPayPeriod = createPayPeriod({
      id: 'period-current',
      startDate: '2026-05-16',
      endDate: '2026-05-29',
      payday: '2026-05-16',
      nextPayday: '2026-05-30',
      incomePence: 100000,
    })
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      pots: [
        {
          id: 'pot-bills',
          name: 'Bills',
          type: 'reserved',
          balancePence: 0,
          targetPence: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'council-tax',
          name: 'Council Tax',
          amountPence: 14800,
          dueDay: 20,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'essential',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(
      <DashboardPage
        snapshot={snapshot}
        selectedPayPeriod={selectedPayPeriod}
        actions={actions}
        onViewChange={vi.fn()}
      />,
    )

    await user.click(screen.getByRole('checkbox', { name: /Set aside £148\.00 into "Bills" pot/ }))

    expect(actions.upsertPaycheckPotAllocation).toHaveBeenCalledWith({
      id: 'dashboard-todo-period-current-recurring-council-tax-2026-05-20',
      payPeriodId: 'period-current',
      potId: 'pot-bills',
      amountPence: 14800,
    })

    restoreLocalStorage()
  })

  it('ignores a checklist payment for the selected paycheck maths', async () => {
    const user = userEvent.setup()
    const restoreLocalStorage = mockLocalStorage()
    const snapshot = createSnapshot({
      payPeriods: [createPayPeriod({ id: 'period-current', incomePence: 100000 })],
      pots: [
        {
          id: 'pot-bills',
          name: 'Bills',
          type: 'reserved',
          balancePence: 0,
          targetPence: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'council-tax',
          name: 'Council Tax',
          amountPence: 6000,
          dueDay: 20,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'essential',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    const { unmount } = render(
      <DashboardPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} onViewChange={vi.fn()} />,
    )

    const currentPeriod = screen.getByRole('region', { name: 'Selected pay period' })
    const todoList = screen.getByRole('region', { name: 'Paycheck to-do list' })

    expect(within(currentPeriod).getAllByText('£60.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£940.00').length).toBeGreaterThan(0)

    await user.click(within(todoList).getByRole('button', { name: 'Ignore Payment for Council Tax' }))

    expect(within(todoList).getByRole('button', { name: 'Ignore Payment for Council Tax' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
    expect(within(todoList).getByText('Ignored for this paycheck')).toBeInTheDocument()
    expect(within(currentPeriod).getAllByText('£0.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£1,000.00').length).toBeGreaterThan(0)

    unmount()

    render(<DashboardPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} onViewChange={vi.fn()} />)

    expect(screen.getByRole('button', { name: 'Ignore Payment for Council Tax' })).toHaveAttribute(
      'aria-pressed',
      'true',
    )
    expect(screen.getByText('Ignored for this paycheck')).toBeInTheDocument()
    expect(
      within(screen.getByRole('region', { name: 'Selected pay period' })).getAllByText('£1,000.00').length,
    ).toBeGreaterThan(0)
    restoreLocalStorage()
  })

  it('does not ask for a recurring pot set-aside when the linked pot already covers it', () => {
    const selectedPayPeriod = createPayPeriod({
      startDate: '2026-05-22',
      endDate: '2026-06-04',
      payday: '2026-05-22',
      nextPayday: '2026-06-05',
      incomePence: 100000,
    })
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      pots: [
        {
          id: 'pot-car-insurance',
          name: 'Car Insurance',
          type: 'reserved',
          balancePence: 8711,
          targetPence: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      recurringPayments: [
        {
          id: 'car-insurance',
          name: 'Car Insurance',
          amountPence: 8711,
          dueDay: 1,
          frequency: 'monthly',
          potId: 'pot-car-insurance',
          priority: 'essential',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<DashboardPage snapshot={snapshot} selectedPayPeriod={selectedPayPeriod} onViewChange={vi.fn()} />)

    const currentPeriod = screen.getByRole('region', { name: 'Selected pay period' })
    const todoList = screen.getByRole('region', { name: 'Paycheck to-do list' })

    expect(within(currentPeriod).getAllByText('£0.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£1,000.00').length).toBeGreaterThan(0)
    expect(
      within(todoList).queryByText('Set aside £87.11 into "Car Insurance" pot for "Car Insurance"'),
    ).not.toBeInTheDocument()
    expect(within(todoList).getByText('No set-asides for this paycheck')).toBeInTheDocument()
  })

  it('shows linked credit card amounts owed as pot set-asides', () => {
    const selectedPayPeriod = createPayPeriod({ incomePence: 100000 })
    const snapshot = createSnapshot({
      payPeriods: [selectedPayPeriod],
      pots: [
        {
          id: 'pot-card-reserve',
          name: 'Card Reserve',
          type: 'reserved',
          balancePence: 40000,
          targetPence: null,
          color: '#2563eb',
          archived: false,
          linkedCreditCardId: 'card-amex',
          linkedDebtId: null,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
      creditCards: [
        {
          id: 'card-amex',
          name: 'Everyday Amex',
          provider: 'Amex',
          limitPence: 100000,
          openingBalancePence: 60000,
          dueDay: 12,
          dueDate: null,
          color: '#2563eb',
          archived: false,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    render(<DashboardPage snapshot={snapshot} selectedPayPeriod={selectedPayPeriod} onViewChange={vi.fn()} />)

    const currentPeriod = screen.getByRole('region', { name: 'Selected pay period' })
    const todoList = screen.getByRole('region', { name: 'Paycheck to-do list' })

    expect(within(currentPeriod).getAllByText('£200.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£800.00').length).toBeGreaterThan(0)
    expect(
      within(todoList).getByText('Set aside £200.00 into "Card Reserve" pot for "Everyday Amex" card amount owed'),
    ).toBeInTheDocument()
    expect(within(todoList).getByText('Linked card balance still owed')).toBeInTheDocument()
  })

  it('expands only one dashboard summary card at a time', async () => {
    const user = userEvent.setup()
    const snapshot = createSnapshot({
      payPeriods: [createPayPeriod({ incomePence: 90000 })],
    })

    render(<DashboardPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} onViewChange={vi.fn()} />)

    const currentPeriod = screen.getByRole('region', { name: 'Selected pay period' })
    const totalPay = getMetricDetails(currentPeriod, 'Total pay')
    const totalCosts = getMetricDetails(currentPeriod, 'Total costs')
    const moneyLeft = getMetricDetails(currentPeriod, 'Money left')

    await user.click(within(totalPay).getByText('Show calculation'))

    expect(totalPay).toHaveAttribute('open')
    expect(totalCosts).not.toHaveAttribute('open')
    expect(moneyLeft).not.toHaveAttribute('open')

    await user.click(within(totalCosts).getByText('Show calculation'))

    expect(totalPay).not.toHaveAttribute('open')
    expect(totalCosts).toHaveAttribute('open')
    expect(moneyLeft).not.toHaveAttribute('open')

    await user.click(within(moneyLeft).getByText('Show calculation'))

    expect(totalPay).not.toHaveAttribute('open')
    expect(totalCosts).not.toHaveAttribute('open')
    expect(moneyLeft).toHaveAttribute('open')
  })

  it('deducts planned debt reserves and only counts the unreserved debt due amount', () => {
    const snapshot = createSnapshot({
      payPeriods: [
        {
          id: 'period-current',
          startDate: '2026-05-22',
          endDate: '2026-06-04',
          payday: '2026-05-22',
          nextPayday: '2026-06-05',
          payFrequency: 'biweekly',
          incomePence: 100000,
          status: 'active',
          createdAt: '2026-05-22T00:00:00.000Z',
          updatedAt: '2026-05-22T00:00:00.000Z',
        },
      ],
      debts: [
        {
          id: 'debt-card',
          name: 'Card balance',
          lender: 'Card Provider',
          originalAmountPence: 50000,
          currentBalancePence: 50000,
          minimumPaymentPence: 0,
          dueDate: '2026-05-30',
          interestRateApr: null,
          note: '',
          status: 'active',
          createdAt: '2026-05-20T00:00:00.000Z',
          updatedAt: '2026-05-20T00:00:00.000Z',
        },
      ],
      debtReserves: [
        {
          id: 'reserve-card',
          debtId: 'debt-card',
          payPeriodId: 'period-current',
          payday: '2026-05-22',
          periodStartDate: '2026-05-22',
          periodEndDate: '2026-06-04',
          amountPence: 20000,
          status: 'planned',
          source: 'assistant',
          note: 'Reserve part of the debt',
          createdAt: '2026-05-22T00:00:00.000Z',
          updatedAt: '2026-05-22T00:00:00.000Z',
        },
      ],
    })

    render(<DashboardPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} onViewChange={vi.fn()} />)

    const currentPeriod = screen.getByRole('region', { name: 'Selected pay period' })
    expect(within(currentPeriod).getAllByText('£500.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£200.00').length).toBeGreaterThan(0)
    expect(within(currentPeriod).getAllByText('£300.00').length).toBeGreaterThan(0)
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

    render(<DashboardPage snapshot={snapshot} selectedPayPeriod={snapshot.payPeriods[0]} onViewChange={vi.fn()} />)

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

  it('allows an active debt without a minimum payment', async () => {
    const user = userEvent.setup()
    const actions = createActions()

    render(<DebtsPage snapshot={createSnapshot()} actions={actions} />)

    const debtPanel = screen.getByRole('region', { name: 'Add debt' })
    await user.type(within(debtPanel).getByLabelText('Debt name'), 'Store card')
    await user.type(within(debtPanel).getByLabelText('Lender'), 'Retail Bank')
    await user.type(within(debtPanel).getByLabelText('Current balance'), '300')
    await user.clear(within(debtPanel).getByLabelText('Due date'))
    await user.type(within(debtPanel).getByLabelText('Due date'), '2026-05-23')

    expect(within(debtPanel).getByRole('button', { name: 'Add debt' })).toBeEnabled()
    await user.click(within(debtPanel).getByRole('button', { name: 'Add debt' }))

    expect(actions.addDebt).toHaveBeenCalledWith({
      currentBalancePence: 30000,
      dueDate: '2026-05-23',
      interestRateApr: null,
      lender: 'Retail Bank',
      minimumPaymentPence: 0,
      name: 'Store card',
      note: '',
    })
  })

  it('shows the full balance as due for active debts even when minimum payment is zero', () => {
    render(
      <DebtsPage
        snapshot={createSnapshot({
          payPeriods: [
            {
              id: 'period-current',
              startDate: '2026-05-16',
              endDate: '2026-05-29',
              payday: '2026-05-16',
              nextPayday: '2026-05-30',
              payFrequency: 'biweekly',
              incomePence: 90000,
              status: 'active',
              createdAt: '2026-05-16T00:00:00.000Z',
              updatedAt: '2026-05-16T00:00:00.000Z',
            },
          ],
          debts: [
            {
              id: 'debt-zero-minimum',
              name: 'Store card',
              lender: 'Retail Bank',
              originalAmountPence: 30000,
              currentBalancePence: 30000,
              minimumPaymentPence: 0,
              dueDate: '2026-05-23',
              interestRateApr: null,
              note: '',
              status: 'active',
              createdAt: '2026-05-20T00:00:00.000Z',
              updatedAt: '2026-05-20T00:00:00.000Z',
            },
            {
              id: 'debt-next-period',
              name: 'Next period debt',
              lender: 'Retail Bank',
              originalAmountPence: 50000,
              currentBalancePence: 50000,
              minimumPaymentPence: 0,
              dueDate: '2026-06-02',
              interestRateApr: null,
              note: '',
              status: 'active',
              createdAt: '2026-05-20T00:00:00.000Z',
              updatedAt: '2026-05-20T00:00:00.000Z',
            },
          ],
        })}
        actions={createActions()}
      />,
    )

    const debtDueMetric = screen.getAllByText('Debt due this pay period')[0].closest('details')

    expect(debtDueMetric).not.toBeNull()
    expect(within(debtDueMetric as HTMLElement).getAllByText('£300.00').length).toBeGreaterThan(0)
    expect(within(debtDueMetric as HTMLElement).queryByText('Next period debt')).not.toBeInTheDocument()
    expect(screen.getAllByText('Due amount').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Optional').length).toBeGreaterThan(0)
  })

  it('counts linked debt pot balances in each debt card progress bar', () => {
    render(
      <DebtsPage
        snapshot={createSnapshot({
          pots: [
            {
              id: 'pot-airbnb',
              name: 'AIRBNB pot',
              type: 'reserved',
              balancePence: 34678,
              targetPence: null,
              color: '#f59e0b',
              linkedDebtId: 'debt-airbnb',
              archived: false,
              createdAt: '2026-05-16T00:00:00.000Z',
              updatedAt: '2026-05-16T00:00:00.000Z',
            },
          ],
          debts: [
            {
              id: 'debt-airbnb',
              name: 'AIRBNB',
              lender: 'AIRBNB',
              originalAmountPence: 55741,
              currentBalancePence: 55741,
              minimumPaymentPence: 0,
              dueDate: '2026-06-05',
              interestRateApr: null,
              note: '',
              status: 'active',
              createdAt: '2026-05-20T00:00:00.000Z',
              updatedAt: '2026-05-20T00:00:00.000Z',
            },
          ],
        })}
        actions={createActions()}
      />,
    )

    const debtList = screen.getByRole('region', { name: 'Debt list' })

    expect(within(debtList).getAllByText('£346.78').length).toBeGreaterThan(0)
    expect(within(debtList).getByText('£346.78 covered')).toBeInTheDocument()
    expect(within(debtList).getAllByText('62%').length).toBeGreaterThan(0)
    expect(debtList.querySelector('.bg-emerald-500')).toHaveStyle({ width: '62%' })
    expect(within(debtList).queryByText('£0.00 paid')).not.toBeInTheDocument()
  })

  it('does not treat a future paycheck plan as the current pay period', () => {
    render(
      <DebtsPage
        snapshot={createSnapshot({
          payPeriods: [
            {
              id: 'period-next',
              startDate: '2026-06-05',
              endDate: '2026-06-18',
              payday: '2026-06-05',
              nextPayday: '2026-06-19',
              payFrequency: 'biweekly',
              incomePence: 90000,
              status: 'planned',
              createdAt: '2026-05-20T00:00:00.000Z',
              updatedAt: '2026-05-20T00:00:00.000Z',
            },
          ],
          debts: [
            {
              id: 'debt-future-period',
              name: 'Future period debt',
              lender: 'Retail Bank',
              originalAmountPence: 30000,
              currentBalancePence: 30000,
              minimumPaymentPence: 0,
              dueDate: '2026-06-06',
              interestRateApr: null,
              note: '',
              status: 'active',
              createdAt: '2026-05-20T00:00:00.000Z',
              updatedAt: '2026-05-20T00:00:00.000Z',
            },
          ],
        })}
        actions={createActions()}
      />,
    )

    const debtDueMetric = screen.getAllByText('Debt due this pay period')[0].closest('details')

    expect(debtDueMetric).not.toBeNull()
    expect(within(debtDueMetric as HTMLElement).getAllByText('£0.00').length).toBeGreaterThan(0)
    expect(within(debtDueMetric as HTMLElement).getByText('No active pay period today')).toBeInTheDocument()
    expect(within(debtDueMetric as HTMLElement).getByText(/Next saved period starts 2026-06-05/)).toBeInTheDocument()
    expect(within(debtDueMetric as HTMLElement).queryByText('Future period debt')).not.toBeInTheDocument()
  })
})

function getMetricDetails(container: HTMLElement, label: string): HTMLElement {
  const details = within(container).getAllByText(label)[0].closest('details')

  expect(details).not.toBeNull()

  return details as HTMLElement
}

function createActions(): TestActions {
  return {
    refresh: vi.fn(async () => {}),
    updateSettings: vi.fn(async () => {}),
    addPot: vi.fn(async () => {}),
    updatePot: vi.fn(async () => {}),
    upsertPaycheckPotAllocation: vi.fn(async () => {}),
    deletePaycheckPotAllocation: vi.fn(async () => {}),
    deletePot: vi.fn(async () => {}),
    addCreditCard: vi.fn(async () => {}),
    updateCreditCard: vi.fn(async () => {}),
    archiveCreditCard: vi.fn(async () => {}),
    addCreditCardPot: vi.fn(async () => {}),
    updateCreditCardPot: vi.fn(async () => {}),
    deleteCreditCardPot: vi.fn(async () => {}),
    applyCreditCardPot: vi.fn(async () => {}),
    addCustomPayment: vi.fn(async () => {}),
    updateCustomPayment: vi.fn(async () => {}),
    deleteCustomPayment: vi.fn(async () => {}),
    addCreditCardRepayment: vi.fn(async () => {}),
    updateCreditCardRepayment: vi.fn(async () => {}),
    deleteCreditCardRepayment: vi.fn(async () => {}),
    addDailyBrief: vi.fn(async () => {}),
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
    addDebtReserve: vi.fn(async () => {}),
    updateDebtReserve: vi.fn(async () => {}),
    cancelDebtReserve: vi.fn(async () => {}),
    skipDebtReserve: vi.fn(async () => {}),
    applyDebtReserve: vi.fn(async () => {}),
    createPaycheckPlan: vi.fn(async () => {}),
    deletePayPeriod: vi.fn(async () => {}),
    resetPlannerData: vi.fn(async () => {}),
  }
}

function createAuth(overrides: Partial<FirebaseAuthController> = {}): FirebaseAuthController {
  return {
    user: null,
    isConfigured: true,
    isAppleEnabled: true,
    isLoading: false,
    error: null,
    clearError: vi.fn(),
    signInWithGoogle: vi.fn(async () => true),
    signInWithApple: vi.fn(async () => true),
    signInWithEmail: vi.fn(async () => true),
    createEmailAccount: vi.fn(async () => true),
    sendPasswordResetEmail: vi.fn(async () => true),
    deleteAccount: vi.fn(async () => true),
    signOut: vi.fn(async () => true),
    ...overrides,
  }
}

function createAuthUser(
  overrides: Partial<NonNullable<FirebaseAuthController['user']>> = {},
): NonNullable<FirebaseAuthController['user']> {
  return {
    uid: 'user-1',
    email: 'user@example.com',
    providerData: [{ providerId: 'password' }],
    ...overrides,
  } as NonNullable<FirebaseAuthController['user']>
}

function mockLocalStorage(): () => void {
  const storedItems = new Map<string, string>()
  const originalDescriptor = Object.getOwnPropertyDescriptor(window, 'localStorage')

  Object.defineProperty(window, 'localStorage', {
    configurable: true,
    value: {
      getItem: vi.fn((key: string) => storedItems.get(key) ?? null),
      setItem: vi.fn((key: string, value: string) => {
        storedItems.set(key, value)
      }),
      removeItem: vi.fn((key: string) => {
        storedItems.delete(key)
      }),
      clear: vi.fn(() => {
        storedItems.clear()
      }),
    },
  })

  return () => {
    if (originalDescriptor) {
      Object.defineProperty(window, 'localStorage', originalDescriptor)
    }
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
      aiInstructions: '',
      aiProvider: 'gemini',
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
    debtReserves: [],
    creditCards: [],
    creditCardPots: [],
    customPayments: [],
    creditCardRepayments: [],
    dailyBriefs: [],
    ...overrides,
  }
}

function createPayPeriod(overrides: Partial<PlannerSnapshot['payPeriods'][number]> = {}): PlannerSnapshot['payPeriods'][number] {
  const timestamp = '2026-05-16T00:00:00.000Z'

  return {
    id: 'period-current',
    startDate: '2026-05-16',
    endDate: '2026-05-29',
    payday: '2026-05-16',
    nextPayday: '2026-05-30',
    payFrequency: 'biweekly',
    incomePence: 90000,
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
    ...overrides,
  }
}
