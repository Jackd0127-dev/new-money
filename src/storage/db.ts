import Dexie, { type Table } from 'dexie'

import type {
  PayPeriod,
  Paycheck,
  Pot,
  PotAllocation,
  RecurringPayment,
  Settings,
  Transaction,
} from '../types/models'

export class PlannerDatabase extends Dexie {
  settings!: Table<Settings, string>
  pots!: Table<Pot, string>
  recurringPayments!: Table<RecurringPayment, string>
  payPeriods!: Table<PayPeriod, string>
  paychecks!: Table<Paycheck, string>
  potAllocations!: Table<PotAllocation, string>
  transactions!: Table<Transaction, string>

  constructor() {
    super('privatePaycheckPlanner')

    this.version(1).stores({
      settings: 'id',
      pots: 'id, type, archived',
      recurringPayments: 'id, potId, active, frequency',
      payPeriods: 'id, payday, status',
      paychecks: 'id, payPeriodId',
      potAllocations: 'id, payPeriodId, potId',
      transactions: 'id, potId, payPeriodId, date, type',
    })
  }
}

export const db = new PlannerDatabase()
