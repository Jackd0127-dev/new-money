import { useCallback, useEffect, useMemo, useState } from 'react'

import {
  addPot,
  addRecurringPayment,
  addTransaction,
  archivePot,
  createPaycheckPlan,
  deleteRecurringPayment,
  deleteTransaction,
  getPlannerSnapshot,
  resetPlannerData,
  toggleRecurringPayment,
  updateSettings,
  type PaycheckPlanInput,
  type PlannerSnapshot,
  type PotInput,
  type RecurringPaymentInput,
  type TransactionInput,
} from '../storage/repository'
import type { RecurringPayment } from '../types/models'

export interface PlannerActions {
  refresh: () => Promise<void>
  updateSettings: typeof updateSettings
  addPot: typeof addPot
  archivePot: typeof archivePot
  addRecurringPayment: typeof addRecurringPayment
  toggleRecurringPayment: typeof toggleRecurringPayment
  deleteRecurringPayment: typeof deleteRecurringPayment
  addTransaction: typeof addTransaction
  deleteTransaction: typeof deleteTransaction
  createPaycheckPlan: typeof createPaycheckPlan
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
      addRecurringPayment: withRefresh(addRecurringPayment, refresh),
      toggleRecurringPayment: withRefresh(toggleRecurringPayment, refresh),
      deleteRecurringPayment: withRefresh(deleteRecurringPayment, refresh),
      addTransaction: withRefresh(addTransaction, refresh),
      deleteTransaction: withRefresh(deleteTransaction, refresh),
      createPaycheckPlan: withRefresh(createPaycheckPlan, refresh),
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

export type { PaycheckPlanInput, PlannerSnapshot, PotInput, RecurringPayment, RecurringPaymentInput, TransactionInput }
