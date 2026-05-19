import { useCallback, useEffect, useMemo, useState } from 'react'

import {
  addCreditCard,
  addCreditCardRepayment,
  addCustomPayment,
  addDailyBrief,
  addDebt,
  addDebtPayment,
  addPot,
  addRecurringPayment,
  addTransaction,
  archiveCreditCard,
  archivePot,
  createPaycheckPlan,
  deleteDebt,
  deleteDebtPayment,
  deleteCreditCardRepayment,
  deletePayPeriod,
  deleteRecurringPayment,
  deleteTransaction,
  getPlannerSnapshot,
  resetPlannerData,
  toggleRecurringPayment,
  updateDebt,
  updateCustomPayment,
  updateRecurringPayment,
  updateSettings,
  updateTransaction,
  type CreditCardInput,
  type CreditCardRepaymentInput,
  type CustomPaymentInput,
  type CustomPaymentUpdateInput,
  type DailyBriefInput,
  type DebtInput,
  type DebtPaymentInput,
  type DebtUpdateInput,
  type PaycheckPlanInput,
  type PlannerSnapshot,
  type PotInput,
  type RecurringPaymentInput,
  type RecurringPaymentUpdateInput,
  type TransactionInput,
  type TransactionUpdateInput,
} from '../storage/repository'
import type { RecurringPayment } from '../types/models'

export interface PlannerActions {
  refresh: () => Promise<void>
  updateSettings: typeof updateSettings
  addPot: typeof addPot
  archivePot: typeof archivePot
  addCreditCard: typeof addCreditCard
  archiveCreditCard: typeof archiveCreditCard
  addCustomPayment: typeof addCustomPayment
  updateCustomPayment: typeof updateCustomPayment
  addCreditCardRepayment: typeof addCreditCardRepayment
  deleteCreditCardRepayment: typeof deleteCreditCardRepayment
  addDailyBrief: typeof addDailyBrief
  addRecurringPayment: typeof addRecurringPayment
  updateRecurringPayment: typeof updateRecurringPayment
  toggleRecurringPayment: typeof toggleRecurringPayment
  deleteRecurringPayment: typeof deleteRecurringPayment
  addTransaction: typeof addTransaction
  updateTransaction: typeof updateTransaction
  deleteTransaction: typeof deleteTransaction
  addDebt: typeof addDebt
  updateDebt: typeof updateDebt
  deleteDebt: typeof deleteDebt
  addDebtPayment: typeof addDebtPayment
  deleteDebtPayment: typeof deleteDebtPayment
  createPaycheckPlan: typeof createPaycheckPlan
  deletePayPeriod: typeof deletePayPeriod
  resetPlannerData: typeof resetPlannerData
}

export function usePlannerData() {
  const [snapshot, setSnapshot] = useState<PlannerSnapshot | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    setError(null)
    const nextSnapshot = await getPlannerSnapshot()
    setSnapshot(nextSnapshot)
    setIsLoading(false)
  }, [])

  useEffect(() => {
    const timeout = window.setTimeout(() => {
      refresh().catch((caughtError: unknown) => {
        setError(caughtError instanceof Error ? caughtError.message : 'Unable to load planner data')
        setIsLoading(false)
      })
    }, 0)

    return () => window.clearTimeout(timeout)
  }, [refresh])

  const actions = useMemo<PlannerActions>(
    () => ({
      refresh,
      updateSettings: withRefresh(updateSettings, refresh),
      addPot: withRefresh(addPot, refresh),
      archivePot: withRefresh(archivePot, refresh),
      addCreditCard: withRefresh(addCreditCard, refresh),
      archiveCreditCard: withRefresh(archiveCreditCard, refresh),
      addCustomPayment: withRefresh(addCustomPayment, refresh),
      updateCustomPayment: withRefresh(updateCustomPayment, refresh),
      addCreditCardRepayment: withRefresh(addCreditCardRepayment, refresh),
      deleteCreditCardRepayment: withRefresh(deleteCreditCardRepayment, refresh),
      addDailyBrief: withRefresh(addDailyBrief, refresh),
      addRecurringPayment: withRefresh(addRecurringPayment, refresh),
      updateRecurringPayment: withRefresh(updateRecurringPayment, refresh),
      toggleRecurringPayment: withRefresh(toggleRecurringPayment, refresh),
      deleteRecurringPayment: withRefresh(deleteRecurringPayment, refresh),
      addTransaction: withRefresh(addTransaction, refresh),
      updateTransaction: withRefresh(updateTransaction, refresh),
      deleteTransaction: withRefresh(deleteTransaction, refresh),
      addDebt: withRefresh(addDebt, refresh),
      updateDebt: withRefresh(updateDebt, refresh),
      deleteDebt: withRefresh(deleteDebt, refresh),
      addDebtPayment: withRefresh(addDebtPayment, refresh),
      deleteDebtPayment: withRefresh(deleteDebtPayment, refresh),
      createPaycheckPlan: withRefresh(createPaycheckPlan, refresh),
      deletePayPeriod: withRefresh(deletePayPeriod, refresh),
      resetPlannerData: withRefresh(resetPlannerData, refresh),
    }),
    [refresh],
  )

  return {
    snapshot,
    isLoading,
    error,
    actions,
  }
}

function withRefresh<Args extends unknown[]>(
  action: (...args: Args) => Promise<void>,
  refresh: () => Promise<void>,
) {
  return async (...args: Args) => {
    await action(...args)
    await refresh()
  }
}

export type {
  CreditCardInput,
  CreditCardRepaymentInput,
  CustomPaymentInput,
  CustomPaymentUpdateInput,
  DailyBriefInput,
  DebtInput,
  DebtPaymentInput,
  DebtUpdateInput,
  PaycheckPlanInput,
  PlannerSnapshot,
  PotInput,
  RecurringPayment,
  RecurringPaymentInput,
  RecurringPaymentUpdateInput,
  TransactionInput,
  TransactionUpdateInput,
}
