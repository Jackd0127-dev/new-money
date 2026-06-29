import { beforeEach, describe, expect, it, vi } from 'vitest'

import {
  getSnapshotSignature,
  hasMeaningfulPlannerData,
  saveCloudPlannerSnapshot,
} from './cloudPlanner'
import type { PlannerSnapshot } from '../storage/repository'

const firestoreMock = vi.hoisted(() => {
  const db = { kind: 'firestore' }
  const currentSnapshotRef = { path: 'users/user-1/planner/snapshot' }
  const backupsCollectionRef = { path: 'users/user-1/planner/snapshot/backups' }
  const backupRef = { path: 'users/user-1/planner/snapshot/backups/generated-backup-id' }
  const batch = {
    set: vi.fn(),
    commit: vi.fn(async () => undefined),
  }

  return {
    db,
    currentSnapshotRef,
    backupsCollectionRef,
    backupRef,
    batch,
    collection: vi.fn(() => backupsCollectionRef),
    doc: vi.fn((parent: unknown, ...pathSegments: string[]) => {
      if (parent === db && pathSegments.join('/') === 'users/user-1/planner/snapshot') {
        return currentSnapshotRef
      }

      if (parent === backupsCollectionRef && pathSegments.length === 0) {
        return backupRef
      }

      return { path: pathSegments.join('/') }
    }),
    getDoc: vi.fn(),
    serverTimestamp: vi.fn(() => 'server-time'),
    setDoc: vi.fn(),
    writeBatch: vi.fn(() => batch),
  }
})

vi.mock('firebase/firestore', () => ({
  collection: firestoreMock.collection,
  doc: firestoreMock.doc,
  getDoc: firestoreMock.getDoc,
  serverTimestamp: firestoreMock.serverTimestamp,
  setDoc: firestoreMock.setDoc,
  writeBatch: firestoreMock.writeBatch,
}))

vi.mock('./client', () => ({
  firebaseDb: firestoreMock.db,
}))

describe('cloud planner helpers', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('removes undefined optional fields from the cloud snapshot signature', () => {
    const signature = getSnapshotSignature({
      ...createSnapshot(),
      recurringPayments: [
        {
          id: 'rec-phone',
          name: 'Phone',
          amountPence: 2200,
          dueDay: 23,
          dueDate: undefined,
          frequency: 'monthly',
          potId: 'pot-bills',
          priority: 'important',
          active: true,
          createdAt: '2026-05-16T00:00:00.000Z',
          updatedAt: '2026-05-16T00:00:00.000Z',
        },
      ],
    })

    expect(signature).not.toContain('dueDate')
  })

  it('detects whether a local starter snapshot has user data', () => {
    expect(hasMeaningfulPlannerData(createSnapshot())).toBe(false)

    expect(
      hasMeaningfulPlannerData({
        ...createSnapshot(),
        transactions: [
          {
            id: 'txn-food',
            potId: 'pot-food',
            amountPence: 900,
            type: 'spending',
            date: '2026-05-18',
            note: 'Lunch',
            createdAt: '2026-05-18T00:00:00.000Z',
            updatedAt: '2026-05-18T00:00:00.000Z',
          },
        ],
      }),
    ).toBe(true)
  })

  it('writes each cloud save to a recoverable backup and the current snapshot', async () => {
    const snapshot = createSnapshot()

    const updatedAtIso = await saveCloudPlannerSnapshot('user-1', snapshot)

    expect(firestoreMock.writeBatch).toHaveBeenCalledWith(firestoreMock.db)
    expect(firestoreMock.collection).toHaveBeenCalledWith(
      firestoreMock.db,
      'users',
      'user-1',
      'planner',
      'snapshot',
      'backups',
    )
    expect(firestoreMock.doc).toHaveBeenCalledWith(firestoreMock.backupsCollectionRef)
    expect(firestoreMock.doc).toHaveBeenCalledWith(
      firestoreMock.db,
      'users',
      'user-1',
      'planner',
      'snapshot',
    )
    expect(firestoreMock.batch.set).toHaveBeenCalledTimes(2)
    expect(firestoreMock.batch.set).toHaveBeenNthCalledWith(
      1,
      firestoreMock.backupRef,
      expect.objectContaining({
        version: 1,
        backupVersion: 1,
        updatedAt: 'server-time',
        updatedAtIso,
        snapshot,
      }),
    )
    expect(firestoreMock.batch.set).toHaveBeenNthCalledWith(
      2,
      firestoreMock.currentSnapshotRef,
      expect.objectContaining({
        version: 1,
        updatedAt: 'server-time',
        updatedAtIso,
        snapshot,
      }),
    )
    expect(firestoreMock.batch.commit).toHaveBeenCalledTimes(1)
    expect(firestoreMock.setDoc).not.toHaveBeenCalled()
  })
})

function createSnapshot(): PlannerSnapshot {
  const timestamp = '2026-05-16T00:00:00.000Z'

  return {
    settings: {
      id: 'default',
      currency: 'GBP',
      payFrequency: 'biweekly',
      defaultPayPeriodDays: 14,
      hourlyRatePence: 1250,
      defaultHoursWorked: 72,
      appDateMode: 'automatic',
      manualTodayIso: null,
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
        balancePence: 0,
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
        balancePence: 0,
        targetPence: null,
        color: '#16a34a',
        archived: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    ],
    recurringPayments: [],
    payPeriods: [],
    paychecks: [],
    potAllocations: [],
    transactions: [],
    debts: [],
    debtPayments: [],
    debtReserves: [],
    creditCards: [],
    creditCardPots: [],
    customPayments: [],
    creditCardRepayments: [],
    dailyBriefs: [],
  }
}
