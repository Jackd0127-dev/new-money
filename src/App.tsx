import { useState, type ReactNode } from 'react'

import { AppShell } from './components/AppShell'
import { DashboardPage } from './pages/DashboardPage'
import { DebtsPage } from './pages/DebtsPage'
import { HistoryPage } from './pages/HistoryPage'
import { PaydayWizardPage } from './pages/PaydayWizardPage'
import { PotsPage } from './pages/PotsPage'
import { RecurringPage } from './pages/RecurringPage'
import { SettingsPage } from './pages/SettingsPage'
import { SpendingPage } from './pages/SpendingPage'
import { useCloudSync } from './hooks/useCloudSync'
import { useFirebaseAuth } from './hooks/useFirebaseAuth'
import { usePlannerData } from './hooks/usePlannerData'
import type { ViewKey } from './types/navigation'

function App() {
  const [activeView, setActiveView] = useState<ViewKey>('dashboard')
  const { snapshot, isLoading, error, actions } = usePlannerData()
  const auth = useFirebaseAuth()
  const sync = useCloudSync({
    user: auth.user,
    snapshot,
    refresh: actions.refresh,
  })

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-100 p-6">
        <div className="rounded-lg border border-slate-200 bg-white p-6 text-center shadow-sm">
          <p className="text-sm font-semibold text-slate-950">Loading local planner</p>
          <p className="mt-1 text-sm text-slate-500">Opening your private IndexedDB store.</p>
        </div>
      </div>
    )
  }

  if (error || !snapshot) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-100 p-6">
        <div className="max-w-md rounded-lg border border-red-200 bg-white p-6 shadow-sm">
          <p className="text-sm font-semibold text-red-700">Unable to load planner</p>
          <p className="mt-2 text-sm text-slate-600">{error ?? 'Unknown storage error'}</p>
        </div>
      </div>
    )
  }

  const pages: Record<ViewKey, ReactNode> = {
    dashboard: <DashboardPage snapshot={snapshot} onViewChange={setActiveView} />,
    payday: <PaydayWizardPage snapshot={snapshot} actions={actions} />,
    pots: <PotsPage snapshot={snapshot} actions={actions} />,
    spending: <SpendingPage snapshot={snapshot} actions={actions} />,
    debts: <DebtsPage snapshot={snapshot} actions={actions} />,
    recurring: <RecurringPage snapshot={snapshot} actions={actions} />,
    history: <HistoryPage snapshot={snapshot} />,
    settings: <SettingsPage snapshot={snapshot} actions={actions} auth={auth} sync={sync} />,
  }

  return (
    <AppShell activeView={activeView} onViewChange={setActiveView}>
      {pages[activeView]}
    </AppShell>
  )
}

export default App
