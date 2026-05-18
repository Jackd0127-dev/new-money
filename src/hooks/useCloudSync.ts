import { useCallback, useEffect, useRef, useState } from 'react'
import type { User } from 'firebase/auth'

import {
  getCloudPlannerSnapshot,
  getSnapshotSignature,
  hasMeaningfulPlannerData,
  saveCloudPlannerSnapshot,
  type CloudPlannerRecord,
} from '../firebase/cloudPlanner'
import { isFirebaseConfigured } from '../firebase/client'
import {
  replacePlannerSnapshot,
  type PlannerSnapshot,
} from '../storage/repository'

export type CloudSyncStatus =
  | 'disabled'
  | 'signed-out'
  | 'checking'
  | 'choice-needed'
  | 'syncing'
  | 'synced'
  | 'error'

export interface CloudSyncController {
  status: CloudSyncStatus
  message: string
  cloudUpdatedAtIso: string | null
  isBusy: boolean
  canDownloadCloud: boolean
  uploadLocalToCloud: () => Promise<void>
  downloadCloudToLocal: () => Promise<void>
  retryCloudCheck: () => Promise<void>
}

export function useCloudSync({
  user,
  snapshot,
  refresh,
}: {
  user: User | null
  snapshot: PlannerSnapshot | null
  refresh: () => Promise<void>
}): CloudSyncController {
  const [status, setStatus] = useState<CloudSyncStatus>(
    isFirebaseConfigured ? 'signed-out' : 'disabled',
  )
  const [message, setMessage] = useState(
    isFirebaseConfigured
      ? 'Sign in to sync this browser with the cloud.'
      : 'Firebase is not configured for this build.',
  )
  const [cloudUpdatedAtIso, setCloudUpdatedAtIso] = useState<string | null>(null)
  const [autoSyncEnabled, setAutoSyncEnabled] = useState(false)
  const pendingCloudRecordRef = useRef<CloudPlannerRecord | null>(null)
  const lastUploadedSignatureRef = useRef<string | null>(null)
  const checkedUserRef = useRef<string | null>(null)

  const checkCloud = useCallback(async () => {
    if (!isFirebaseConfigured) {
      setStatus('disabled')
      setMessage('Firebase is not configured for this build.')
      setAutoSyncEnabled(false)
      return
    }

    if (!user) {
      setStatus('signed-out')
      setMessage('Sign in to sync this browser with the cloud.')
      setCloudUpdatedAtIso(null)
      setAutoSyncEnabled(false)
      pendingCloudRecordRef.current = null
      lastUploadedSignatureRef.current = snapshot ? getSnapshotSignature(snapshot) : null
      return
    }

    if (!snapshot) {
      return
    }

    setStatus('checking')
    setMessage('Checking for cloud data.')
    setAutoSyncEnabled(false)

    try {
      const cloudRecord = await getCloudPlannerSnapshot(user.uid)

      if (!cloudRecord) {
        const updatedAtIso = await saveCloudPlannerSnapshot(user.uid, snapshot)
        lastUploadedSignatureRef.current = getSnapshotSignature(snapshot)
        pendingCloudRecordRef.current = null
        setCloudUpdatedAtIso(updatedAtIso)
        setStatus('synced')
        setMessage('Cloud sync is ready. This browser was backed up.')
        setAutoSyncEnabled(true)
        return
      }

      const localSignature = getSnapshotSignature(snapshot)
      const cloudSignature = getSnapshotSignature(cloudRecord.snapshot)
      setCloudUpdatedAtIso(cloudRecord.updatedAtIso)

      if (localSignature === cloudSignature) {
        pendingCloudRecordRef.current = null
        lastUploadedSignatureRef.current = localSignature
        setStatus('synced')
        setMessage('Cloud sync is up to date.')
        setAutoSyncEnabled(true)
        return
      }

      if (!hasMeaningfulPlannerData(snapshot)) {
        await replacePlannerSnapshot(cloudRecord.snapshot)
        await refresh()
        pendingCloudRecordRef.current = null
        lastUploadedSignatureRef.current = cloudSignature
        setStatus('synced')
        setMessage('Cloud data was downloaded to this browser.')
        setAutoSyncEnabled(true)
        return
      }

      pendingCloudRecordRef.current = cloudRecord
      setStatus('choice-needed')
      setMessage('Cloud data already exists. Choose whether this browser or the cloud should win.')
    } catch (caughtError) {
      setStatus('error')
      setMessage(toSyncMessage(caughtError))
    }
  }, [refresh, snapshot, user])

  useEffect(() => {
    const timeout = window.setTimeout(() => {
      if (!isFirebaseConfigured) {
        void checkCloud()
        return
      }

      if (!user) {
        checkedUserRef.current = null
        void checkCloud()
        return
      }

      if (!snapshot || checkedUserRef.current === user.uid) {
        return
      }

      checkedUserRef.current = user.uid
      void checkCloud()
    }, 0)

    return () => window.clearTimeout(timeout)
  }, [checkCloud, snapshot, user])

  useEffect(() => {
    if (!autoSyncEnabled || !user || !snapshot) {
      return undefined
    }

    const signature = getSnapshotSignature(snapshot)

    if (signature === lastUploadedSignatureRef.current) {
      return undefined
    }

    const timeout = window.setTimeout(() => {
      setStatus('syncing')
      setMessage('Uploading the latest local changes.')

      saveCloudPlannerSnapshot(user.uid, snapshot)
        .then((updatedAtIso) => {
          lastUploadedSignatureRef.current = signature
          setCloudUpdatedAtIso(updatedAtIso)
          setStatus('synced')
          setMessage('Cloud sync is up to date.')
        })
        .catch((caughtError) => {
          setStatus('error')
          setMessage(toSyncMessage(caughtError))
        })
    }, 800)

    return () => window.clearTimeout(timeout)
  }, [autoSyncEnabled, snapshot, user])

  const uploadLocalToCloud = useCallback(async () => {
    if (!user || !snapshot) {
      return
    }

    setStatus('syncing')
    setMessage('Uploading this browser to the cloud.')

    try {
      const updatedAtIso = await saveCloudPlannerSnapshot(user.uid, snapshot)
      lastUploadedSignatureRef.current = getSnapshotSignature(snapshot)
      pendingCloudRecordRef.current = null
      setCloudUpdatedAtIso(updatedAtIso)
      setStatus('synced')
      setMessage('This browser is now the cloud version.')
      setAutoSyncEnabled(true)
    } catch (caughtError) {
      setStatus('error')
      setMessage(toSyncMessage(caughtError))
    }
  }, [snapshot, user])

  const downloadCloudToLocal = useCallback(async () => {
    if (!user) {
      return
    }

    setStatus('syncing')
    setMessage('Downloading cloud data to this browser.')
    setAutoSyncEnabled(false)

    try {
      const cloudRecord = pendingCloudRecordRef.current ?? (await getCloudPlannerSnapshot(user.uid))

      if (!cloudRecord) {
        setStatus('synced')
        setMessage('No cloud data was found yet.')
        setAutoSyncEnabled(true)
        return
      }

      await replacePlannerSnapshot(cloudRecord.snapshot)
      await refresh()
      lastUploadedSignatureRef.current = getSnapshotSignature(cloudRecord.snapshot)
      pendingCloudRecordRef.current = null
      setCloudUpdatedAtIso(cloudRecord.updatedAtIso)
      setStatus('synced')
      setMessage('Cloud data was downloaded to this browser.')
      setAutoSyncEnabled(true)
    } catch (caughtError) {
      setStatus('error')
      setMessage(toSyncMessage(caughtError))
    }
  }, [refresh, user])

  return {
    status,
    message,
    cloudUpdatedAtIso,
    isBusy: status === 'checking' || status === 'syncing',
    canDownloadCloud: Boolean(user),
    uploadLocalToCloud,
    downloadCloudToLocal,
    retryCloudCheck: checkCloud,
  }
}

function toSyncMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message
  }

  return 'Cloud sync failed.'
}
