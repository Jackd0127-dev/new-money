import { doc, getDoc, serverTimestamp, setDoc } from 'firebase/firestore'

import { defaultSettings } from '../data/defaults'
import { firebaseDb } from './client'
import type { PlannerSnapshot } from '../storage/repository'

export interface CloudPlannerRecord {
  snapshot: PlannerSnapshot
  updatedAtIso: string | null
}

interface CloudPlannerDocument {
  version: 1
  updatedAtIso: string
  snapshot: PlannerSnapshot
}

export async function getCloudPlannerSnapshot(userId: string): Promise<CloudPlannerRecord | null> {
  const document = await getDoc(getSnapshotRef(userId))

  if (!document.exists()) {
    return null
  }

  const data = document.data() as Partial<CloudPlannerDocument>

  if (!data.snapshot) {
    return null
  }

  return {
    snapshot: normalizePlannerSnapshot(data.snapshot),
    updatedAtIso: data.updatedAtIso ?? null,
  }
}

export async function saveCloudPlannerSnapshot(
  userId: string,
  snapshot: PlannerSnapshot,
): Promise<string> {
  const updatedAtIso = new Date().toISOString()

  await setDoc(getSnapshotRef(userId), {
    version: 1,
    updatedAt: serverTimestamp(),
    updatedAtIso,
    snapshot: pruneUndefined(snapshot),
  })

  return updatedAtIso
}

export function getSnapshotSignature(snapshot: PlannerSnapshot): string {
  return JSON.stringify(pruneUndefined(snapshot))
}

export function hasMeaningfulPlannerData(snapshot: PlannerSnapshot): boolean {
  return (
    snapshot.recurringPayments.length > 0 ||
    snapshot.payPeriods.length > 0 ||
    snapshot.paychecks.length > 0 ||
    snapshot.potAllocations.length > 0 ||
    snapshot.transactions.length > 0 ||
    snapshot.pots.some((pot) => pot.balancePence !== 0 || pot.archived)
  )
}

function getSnapshotRef(userId: string) {
  const firestore = requireFirestore()
  return doc(firestore, 'users', userId, 'planner', 'snapshot')
}

function requireFirestore() {
  if (!firebaseDb) {
    throw new Error('Firebase is not configured for this build.')
  }

  return firebaseDb
}

function normalizePlannerSnapshot(snapshot: Partial<PlannerSnapshot>): PlannerSnapshot {
  return {
    settings: snapshot.settings ?? defaultSettings,
    pots: snapshot.pots ?? [],
    recurringPayments: snapshot.recurringPayments ?? [],
    payPeriods: snapshot.payPeriods ?? [],
    paychecks: snapshot.paychecks ?? [],
    potAllocations: snapshot.potAllocations ?? [],
    transactions: snapshot.transactions ?? [],
  }
}

function pruneUndefined<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}
