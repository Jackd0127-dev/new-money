export type PayFrequency = 'weekly' | 'biweekly' | 'monthly' | 'custom'

export type PotType = 'spending' | 'reserved' | 'saving' | 'investment' | 'buffer'

export type RecurringFrequency = 'weekly' | 'biweekly' | 'monthly' | 'yearly'

export type RecurringPriority = 'essential' | 'important' | 'optional'

export type PayPeriodStatus = 'planned' | 'active' | 'closed'

export type TransactionType = 'spending' | 'allocation' | 'transfer' | 'adjustment'

export type DebtStatus = 'active' | 'paid' | 'archived'

export interface Timestamped {
  createdAt: string
  updatedAt: string
  deletedAt?: string | null
}

export interface Settings extends Timestamped {
  id: 'default'
  currency: 'GBP'
  payFrequency: PayFrequency
  defaultPayPeriodDays: number
  hourlyRatePence: number
  defaultHoursWorked: number
}

export interface Pot extends Timestamped {
  id: string
  name: string
  type: PotType
  balancePence: number
  targetPence: number | null
  color: string
  archived: boolean
}

export interface RecurringPayment extends Timestamped {
  id: string
  name: string
  amountPence: number
  dueDay?: number
  dueDate?: string
  frequency: RecurringFrequency
  potId: string
  priority: RecurringPriority
  active: boolean
}

export interface PayPeriod extends Timestamped {
  id: string
  startDate: string
  endDate: string
  payday: string
  nextPayday: string
  payFrequency?: PayFrequency
  incomePence: number
  status: PayPeriodStatus
}

export interface Paycheck extends Timestamped {
  id: string
  payPeriodId: string
  hoursWorked: number
  hourlyRatePence: number
  calculatedAmountPence: number
  actualAmountPence: number | null
}

export interface PotAllocation extends Timestamped {
  id: string
  payPeriodId: string
  potId: string
  amountPence: number
  source?: 'manual' | 'recurring'
  recurringPaymentId?: string | null
}

export interface Transaction extends Timestamped {
  id: string
  potId: string
  payPeriodId?: string | null
  amountPence: number
  type: TransactionType
  date: string
  note: string
}

export interface Debt extends Timestamped {
  id: string
  name: string
  lender: string
  originalAmountPence: number
  currentBalancePence: number
  minimumPaymentPence: number
  dueDate: string
  interestRateApr: number | null
  note: string
  status: DebtStatus
}

export interface DebtPayment extends Timestamped {
  id: string
  debtId: string
  amountPence: number
  date: string
  note: string
}
