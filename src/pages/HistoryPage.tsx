import { Trash2 } from 'lucide-react'

import { formatPence } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Panel } from '../components/ui'

export function HistoryPage({
  snapshot,
  actions,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
}) {
  async function deletePeriod(periodId: string, payday: string) {
    if (window.confirm(`Delete paycheck plan for ${payday}?`)) {
      await actions.deletePayPeriod(periodId)
    }
  }

  return (
    <Panel title="Pay period history" description="Previous paycheck plans and their allocations.">
      <div className="overflow-hidden rounded-lg border border-slate-200">
        <table className="w-full min-w-[720px] border-collapse text-left text-sm">
          <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
            <tr>
              <th className="px-4 py-3 font-semibold">Payday</th>
              <th className="px-4 py-3 font-semibold">Period</th>
              <th className="px-4 py-3 font-semibold">Income</th>
              <th className="px-4 py-3 font-semibold">Allocated</th>
              <th className="px-4 py-3 font-semibold">Status</th>
              <th className="px-4 py-3 font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-200 bg-white">
            {snapshot.payPeriods.length > 0 ? (
              snapshot.payPeriods.map((period) => {
                const allocated = snapshot.potAllocations
                  .filter((allocation) => allocation.payPeriodId === period.id)
                  .reduce((total, allocation) => total + allocation.amountPence, 0)

                return (
                  <tr key={period.id}>
                    <td className="px-4 py-3 font-medium text-slate-950">{period.payday}</td>
                    <td className="px-4 py-3 text-slate-600">
                      {period.startDate} to {period.endDate}
                    </td>
                    <td className="px-4 py-3 text-slate-950">{formatPence(period.incomePence)}</td>
                    <td className="px-4 py-3 text-slate-950">{formatPence(allocated)}</td>
                    <td className="px-4 py-3 capitalize text-slate-600">{period.status}</td>
                    <td className="px-4 py-3">
                      <Button
                        variant="danger"
                        onClick={() => void deletePeriod(period.id, period.payday)}
                        aria-label={`Delete paycheck plan for ${period.payday}`}
                      >
                        <Trash2 size={16} />
                      </Button>
                    </td>
                  </tr>
                )
              })
            ) : (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-slate-500">
                  No paycheck history yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </Panel>
  )
}
