import { useState, type ReactNode } from 'react'
import { clsx } from 'clsx'
import {
  ArrowRight,
  BadgePoundSterling,
  CalendarDays,
  ChevronDown,
  CreditCard,
  Layers3,
  PauseCircle,
  PenLine,
  PiggyBank,
  PlayCircle,
  PlusCircle,
  Repeat,
  Trash2,
  X,
} from 'lucide-react'

import {
  createNextPayPeriod,
  formatPence,
  getAppTodayIso,
  getPayPeriodCostSummary,
  parsePoundsToPence,
  type PayPeriodCostSummary,
} from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import {
  Button,
  Field,
  Panel,
  SectionGrid,
  SelectInput,
  TextInput,
  type CalculationBreakdown,
} from '../components/ui'
import type {
  PayFrequency,
  PayPeriod,
  PotAllocation,
  RecurringFrequency,
  RecurringPayment,
  RecurringPriority,
} from '../types/models'

interface RecurringFormState {
  name: string
  amount: string
  dueDay: string
  dueDate: string
  frequency: RecurringFrequency
  priority: RecurringPriority
  potId: string
  creditCardId: string
}

export function RecurringPage({
  snapshot,
  actions,
  selectedPayPeriod,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
  selectedPayPeriod?: PayPeriod | null
}) {
  const today = getAppTodayIso(snapshot.settings)
  const activePots = snapshot.pots.filter((pot) => !pot.archived)
  const activeCards = snapshot.creditCards.filter((card) => !card.archived)
  const [createForm, setCreateForm] = useState<RecurringFormState>(() =>
    createEmptyRecurringForm(activePots[0]?.id ?? ''),
  )
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [expandedPaymentIds, setExpandedPaymentIds] = useState<Set<string>>(() => new Set())
  const [editingPaymentId, setEditingPaymentId] = useState<string | null>(null)
  const [editForm, setEditForm] = useState<RecurringFormState | null>(null)
  const viewedPeriod = selectedPayPeriod ?? null
  const nextPaydayPeriod = viewedPeriod
    ? getNextPaydayPeriod(viewedPeriod, viewedPeriod.payFrequency ?? snapshot.settings.payFrequency)
    : null
  const nextPaydaySummary = getPayPeriodCostSummary({
    payPeriod: nextPaydayPeriod,
    recurringPayments: snapshot.recurringPayments,
    customPayments: snapshot.customPayments,
    transactions: snapshot.transactions,
    debts: snapshot.debts,
    creditCardRepayments: snapshot.creditCardRepayments,
    creditCardPots: snapshot.creditCardPots,
    debtReserves: snapshot.debtReserves,
    pots: snapshot.pots,
    potAllocations: [
      ...snapshot.potAllocations,
      ...(nextPaydayPeriod ? getPreviewPotTopUps(snapshot, nextPaydayPeriod) : []),
    ],
    asOfDate: today,
  })

  async function submitPayment(form: RecurringFormState, mode: 'create' | 'edit') {
    const amountPence = parsePoundsToPence(form.amount)
    const dueDayNumber = Number.parseInt(form.dueDay, 10)
    const usesIntervalAnchor = isIntervalFrequency(form.frequency)

    if (
      !form.name.trim() ||
      amountPence <= 0 ||
      (!usesIntervalAnchor && (dueDayNumber < 1 || dueDayNumber > 31)) ||
      (usesIntervalAnchor && !isIsoDateInput(form.dueDate))
    ) {
      return
    }
    const dueDay = usesIntervalAnchor ? null : dueDayNumber
    const dueDate = usesIntervalAnchor ? form.dueDate : null

    if (mode === 'edit' && editingPaymentId) {
      const currentPayment = snapshot.recurringPayments.find((candidate) => candidate.id === editingPaymentId)
      const updateInput = {
        name: form.name.trim(),
        amountPence,
        dueDay,
        dueDate,
        frequency: form.frequency,
        potId: form.potId || null,
        priority: form.priority,
        ...(form.creditCardId || currentPayment?.creditCardId
          ? {
              creditCardId: form.creditCardId || null,
            }
          : {}),
      }

      await actions.updateRecurringPayment(editingPaymentId, updateInput)
      closeEditModal()
      return
    }

    const addInput = {
      name: form.name.trim(),
      amountPence,
      dueDay,
      dueDate,
      frequency: form.frequency,
      potId: form.potId || null,
      priority: form.priority,
      ...(form.creditCardId
        ? {
            creditCardId: form.creditCardId,
          }
        : {}),
    }

    await actions.addRecurringPayment(addInput)
    resetCreateForm()
    setIsCreateOpen(false)
  }

  function startEditingPayment(paymentId: string) {
    const payment = snapshot.recurringPayments.find((candidate) => candidate.id === paymentId)

    if (!payment) {
      return
    }

    setEditingPaymentId(payment.id)
    setEditForm({
      name: payment.name,
      amount: (payment.amountPence / 100).toFixed(2),
      dueDay: String(payment.dueDay ?? 1),
      dueDate: payment.dueDate ?? '',
      frequency: payment.frequency,
      priority: payment.priority,
      potId: payment.potId ?? '',
      creditCardId: payment.creditCardId ?? '',
    })
  }

  function resetCreateForm() {
    setCreateForm(createEmptyRecurringForm(activePots[0]?.id ?? ''))
  }

  function closeEditModal() {
    setEditingPaymentId(null)
    setEditForm(null)
  }

  function togglePaymentDetails(paymentId: string) {
    setExpandedPaymentIds((current) => {
      const next = new Set(current)

      if (next.has(paymentId)) {
        next.delete(paymentId)
      } else {
        next.add(paymentId)
      }

      return next
    })
  }

  const recurringStats = getRecurringStats(snapshot.recurringPayments)
  const paymentGroups = getRecurringPaymentGroups(snapshot.recurringPayments)

  return (
    <div className="space-y-4">
      <RecurringSummaryBar
        stats={recurringStats}
        isCreateOpen={isCreateOpen}
        onToggleCreate={() => setIsCreateOpen((isOpen) => !isOpen)}
      />

      <SectionGrid variant="wideLeft" className="gap-4">
        <div className="space-y-4">
          {isCreateOpen && (
            <Panel
              title="Add recurring payment"
              accent="violet"
              density="compact"
            >
              <div className="space-y-3">
                <RecurringPaymentFormFields
                  form={createForm}
                  activePots={activePots}
                  activeCards={activeCards}
                  onChange={setCreateForm}
                />
                <div className="flex flex-wrap gap-2">
                  <Button className="min-h-9 px-3" onClick={() => void submitPayment(createForm, 'create')}>
                    Add recurring payment
                  </Button>
                  <Button
                    className="min-h-9 px-3"
                    variant="secondary"
                    onClick={() => setIsCreateOpen(false)}
                  >
                    Close
                  </Button>
                </div>
              </div>
            </Panel>
          )}

          <Panel
            title="Recurring payments"
            accent="blue"
            density="compact"
          >
            <div className="space-y-3 xl:max-h-[690px] xl:overflow-y-auto xl:pr-1">
              {snapshot.recurringPayments.length > 0 ? (
                paymentGroups.map((group) => (
                  <RecurringPaymentSection
                    key={group.id}
                    label={group.label}
                    payments={group.payments}
                    pots={snapshot.pots}
                    creditCards={snapshot.creditCards}
                    expandedPaymentIds={expandedPaymentIds}
                    onToggleDetails={togglePaymentDetails}
                    onToggleActive={(payment) => actions.toggleRecurringPayment(payment)}
                    onEdit={startEditingPayment}
                    onDelete={(payment) => {
                      if (window.confirm(`Delete ${payment.name}?`)) {
                        void actions.deleteRecurringPayment(payment.id)
                      }
                    }}
                  />
                ))
              ) : (
                <p className="rounded-lg border border-dashed border-slate-200/90 bg-slate-50/80 p-3 text-sm text-slate-500">No recurring payments yet.</p>
              )}
            </div>
          </Panel>
        </div>

        <NextPaydayOwedPanel period={nextPaydayPeriod} summary={nextPaydaySummary} />
      </SectionGrid>

      {editingPaymentId && editForm && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/50 p-4 backdrop-blur-sm">
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Edit recurring payment"
            className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-2xl border border-slate-200/90 bg-white/[0.96] p-5 shadow-[0_26px_80px_rgba(15,23,42,0.22)] backdrop-blur"
          >
            <div className="mb-4 flex items-start justify-between gap-4 border-b border-slate-100 pb-4">
              <div>
                <h2 className="text-base font-semibold text-slate-950">Edit recurring payment</h2>
                <p className="mt-1 text-sm text-slate-500">Update this bill without changing the add-payment form.</p>
              </div>
              <Button variant="ghost" onClick={closeEditModal} aria-label="Close edit recurring payment">
                <X size={18} />
              </Button>
            </div>
            <div className="space-y-3">
              <RecurringPaymentFormFields
                form={editForm}
                activePots={activePots}
                activeCards={activeCards}
                onChange={setEditForm}
              />
              <div className="flex flex-wrap gap-3">
                <Button onClick={() => void submitPayment(editForm, 'edit')}>Save recurring payment</Button>
                <Button variant="secondary" onClick={closeEditModal}>
                  Cancel
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function createEmptyRecurringForm(defaultPotId: string): RecurringFormState {
  return {
    name: '',
    amount: '',
    dueDay: '1',
    dueDate: '',
    frequency: 'monthly',
    priority: 'essential',
    potId: defaultPotId,
    creditCardId: '',
  }
}

function RecurringSummaryBar({
  stats,
  isCreateOpen,
  onToggleCreate,
}: {
  stats: RecurringStats
  isCreateOpen: boolean
  onToggleCreate: () => void
}) {
  return (
    <section
      aria-label="Recurring overview"
      className="overflow-hidden rounded-2xl border border-slate-900 bg-[linear-gradient(135deg,#020617,#071526_54%,#0f2d36)] text-white shadow-[0_24px_70px_rgba(15,23,42,0.18)]"
    >
      <div className="grid gap-5 p-5 lg:grid-cols-[minmax(0,1fr)_minmax(320px,0.55fr)] lg:items-end">
        <div className="min-w-0">
          <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-cyan-200">
            <Repeat size={15} />
            Recurring control
          </div>
          <p className="mt-4 text-4xl font-semibold tracking-[-0.04em] text-white">{formatPence(stats.activeTotalPence)}</p>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
            {stats.activeCount} active payment{stats.activeCount === 1 ? '' : 's'} across {stats.totalCount} saved recurring item{stats.totalCount === 1 ? '' : 's'}.
          </p>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <CompactStat icon={<Layers3 size={16} />} label="Active" value={`${stats.activeCount}/${stats.totalCount}`} />
          <CompactStat icon={<CalendarDays size={16} />} label="Monthly" value={String(stats.monthlyCount)} />
          <CompactStat icon={<CreditCard size={16} />} label="On cards" value={String(stats.cardLinkedCount)} />
          <CompactStat icon={<BadgePoundSterling size={16} />} label="Active total" value={formatPence(stats.activeTotalPence)} />
        </div>
      </div>
      <div className="flex flex-col gap-3 border-t border-white/10 bg-white/[0.06] p-4 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-300">
          {stats.totalCount > 0 ? 'Payments stay tucked into compact cards below' : 'Add the first repeating payment'}
        </p>
        <Button
          className="min-h-9 justify-center px-3 sm:min-w-36"
          variant={isCreateOpen ? 'secondary' : 'primary'}
          onClick={onToggleCreate}
        >
          <PlusCircle size={16} />
          New payment
        </Button>
      </div>
      {stats.totalCount > 0 && (
        <div className="grid gap-4 border-t border-white/10 bg-white/[0.04] p-4 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
          <div className="rounded-2xl border border-white/10 bg-slate-950/25 p-4">
            <div className="mb-3 flex items-center justify-between gap-3 text-xs font-semibold uppercase tracking-wide text-slate-300">
              <span>Schedule mix</span>
              <span>{stats.activeCount} active</span>
            </div>
            <div className="grid gap-2 sm:grid-cols-4">
              <RecurringMixNode label="Weekly" count={stats.weeklyCount} total={stats.totalCount} tone="cyan" />
              <RecurringMixNode label="Biweekly" count={stats.biweeklyCount} total={stats.totalCount} tone="emerald" />
              <RecurringMixNode label="Monthly" count={stats.monthlyCount} total={stats.totalCount} tone="amber" />
              <RecurringMixNode label="Yearly" count={stats.yearlyCount} total={stats.totalCount} tone="rose" />
            </div>
          </div>
          <div className="rounded-2xl border border-white/10 bg-slate-950/25 p-4">
            <div className="mb-3 flex items-center justify-between gap-3 text-xs font-semibold uppercase tracking-wide text-slate-300">
              <span>Payment route</span>
              <span>{formatPence(stats.activeTotalPence)}</span>
            </div>
            <div className="grid gap-3 md:grid-cols-[1fr_auto_1fr_auto_1fr] md:items-center">
              <RecurringRouteNode label="Direct" value={formatPence(stats.directTotalPence)} />
              <ArrowRight className="hidden text-cyan-200 md:block" size={18} />
              <RecurringRouteNode label="Via pots" value={formatPence(stats.potLinkedTotalPence)} />
              <ArrowRight className="hidden text-cyan-200 md:block" size={18} />
              <RecurringRouteNode label="On cards" value={formatPence(stats.cardLinkedTotalPence)} />
            </div>
          </div>
        </div>
      )}
    </section>
  )
}

function RecurringMixNode({
  label,
  count,
  total,
  tone,
}: {
  label: string
  count: number
  total: number
  tone: 'cyan' | 'emerald' | 'amber' | 'rose'
}) {
  const percent = total > 0 ? Math.round((count / total) * 100) : 0
  const toneClassName =
    tone === 'emerald'
      ? 'bg-emerald-300'
      : tone === 'amber'
        ? 'bg-amber-300'
        : tone === 'rose'
          ? 'bg-rose-300'
          : 'bg-cyan-300'

  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.07] p-3">
      <div className="flex items-center justify-between gap-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">{label}</p>
        <p className="text-sm font-semibold text-white">{count}</p>
      </div>
      <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-white/10">
        <div className={`h-full rounded-full ${toneClassName}`} style={{ width: `${Math.min(100, Math.max(0, percent))}%` }} />
      </div>
    </div>
  )
}

function RecurringRouteNode({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0 rounded-xl border border-white/10 bg-white/[0.07] p-3">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">{label}</p>
      <p className="mt-1 text-sm font-semibold text-white">{value}</p>
    </div>
  )
}

function CompactStat({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.08] p-3 text-slate-200 shadow-inner shadow-white/5">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-300">
        {icon}
        {label}
      </div>
      <p className="mt-2 truncate text-lg font-semibold tracking-[-0.02em] text-white">{value}</p>
    </div>
  )
}

interface RecurringStats {
  totalCount: number
  activeCount: number
  weeklyCount: number
  biweeklyCount: number
  monthlyCount: number
  yearlyCount: number
  cardLinkedCount: number
  potLinkedTotalPence: number
  cardLinkedTotalPence: number
  directTotalPence: number
  activeTotalPence: number
}

function getRecurringStats(payments: RecurringPayment[]): RecurringStats {
  const activePayments = payments.filter((payment) => payment.active)

  return {
    totalCount: payments.length,
    activeCount: activePayments.length,
    weeklyCount: payments.filter((payment) => payment.frequency === 'weekly').length,
    biweeklyCount: payments.filter((payment) => payment.frequency === 'biweekly').length,
    monthlyCount: payments.filter((payment) => payment.frequency === 'monthly').length,
    yearlyCount: payments.filter((payment) => payment.frequency === 'yearly').length,
    cardLinkedCount: payments.filter((payment) => Boolean(payment.creditCardId)).length,
    potLinkedTotalPence: activePayments
      .filter((payment) => Boolean(payment.potId) && !payment.creditCardId)
      .reduce((total, payment) => total + payment.amountPence, 0),
    cardLinkedTotalPence: activePayments
      .filter((payment) => Boolean(payment.creditCardId))
      .reduce((total, payment) => total + payment.amountPence, 0),
    directTotalPence: activePayments
      .filter((payment) => !payment.potId && !payment.creditCardId)
      .reduce((total, payment) => total + payment.amountPence, 0),
    activeTotalPence: activePayments.reduce((total, payment) => total + payment.amountPence, 0),
  }
}

function getRecurringPaymentGroups(payments: RecurringPayment[]): Array<{
  id: string
  label: string
  payments: RecurringPayment[]
}> {
  return [
    {
      id: 'active',
      label: 'Active',
      payments: payments.filter((payment) => payment.active),
    },
    {
      id: 'paused',
      label: 'Paused',
      payments: payments.filter((payment) => !payment.active),
    },
  ].filter((group) => group.payments.length > 0)
}

function RecurringPaymentSection({
  label,
  payments,
  pots,
  creditCards,
  expandedPaymentIds,
  onToggleDetails,
  onToggleActive,
  onEdit,
  onDelete,
}: {
  label: string
  payments: RecurringPayment[]
  pots: PlannerSnapshot['pots']
  creditCards: PlannerSnapshot['creditCards']
  expandedPaymentIds: Set<string>
  onToggleDetails: (paymentId: string) => void
  onToggleActive: (payment: RecurringPayment) => void
  onEdit: (paymentId: string) => void
  onDelete: (payment: RecurringPayment) => void
}) {
  return (
    <section aria-label={`${label} recurring payments`} className="space-y-2">
      <div className="flex items-center justify-between gap-3">
        <h3 className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</h3>
        <p className="text-xs font-semibold text-slate-500">{payments.length}</p>
      </div>
      <div className="grid gap-2 2xl:grid-cols-2">
        {payments.map((payment) => {
          const pot = pots.find((candidate) => candidate.id === payment.potId)
          const card = creditCards.find((candidate) => candidate.id === payment.creditCardId)
          const cardLabel = getRecurringCreditCardLabel(payment.creditCardId, card)
          const isExpanded = expandedPaymentIds.has(payment.id)

          return (
            <RecurringPaymentCard
              key={payment.id}
              payment={payment}
              pot={pot}
              cardLabel={cardLabel}
              isExpanded={isExpanded}
              onToggleDetails={() => onToggleDetails(payment.id)}
              onToggleActive={() => onToggleActive(payment)}
              onEdit={() => onEdit(payment.id)}
              onDelete={() => onDelete(payment)}
            />
          )
        })}
      </div>
    </section>
  )
}

function RecurringPaymentCard({
  payment,
  pot,
  cardLabel,
  isExpanded,
  onToggleDetails,
  onToggleActive,
  onEdit,
  onDelete,
}: {
  payment: RecurringPayment
  pot: PlannerSnapshot['pots'][number] | undefined
  cardLabel: string | null
  isExpanded: boolean
  onToggleDetails: () => void
  onToggleActive: () => void
  onEdit: () => void
  onDelete: () => void
}) {
  const potLabel = payment.potId ? pot?.name ?? 'Archived pot' : 'No pot'

  return (
    <article className="rounded-lg border border-slate-200/90 bg-white/95 p-3 shadow-[0_12px_30px_rgba(15,23,42,0.05)] transition hover:-translate-y-0.5 hover:border-slate-300">
      <div className="grid gap-2 sm:grid-cols-[1fr_auto] sm:items-start">
        <div className="min-w-0">
          <div className="flex min-w-0 items-center gap-2">
            <span className={payment.active ? 'size-2 rounded-full bg-emerald-500' : 'size-2 rounded-full bg-slate-300'} />
            <h3 className="min-w-0 truncate text-sm font-semibold text-slate-950">{payment.name}</h3>
            <span className="shrink-0 rounded-md border border-slate-200/80 bg-white/80 px-1.5 py-0.5 text-[11px] font-semibold capitalize text-slate-600 shadow-sm shadow-slate-200/50">
              {payment.priority}
            </span>
          </div>
          <p className="mt-1 truncate text-xs text-slate-500">
            {getRecurringScheduleLabel(payment)} · {payment.frequency}
          </p>
          <div className="mt-2 flex flex-wrap gap-1.5">
            <CompactMetaPill icon={<PiggyBank size={12} />} label={potLabel} muted={!payment.potId} />
            {cardLabel && <CompactMetaPill icon={<CreditCard size={12} />} label={cardLabel} />}
          </div>
        </div>
        <div className="flex items-center justify-between gap-2 sm:justify-end">
          <p className="text-sm font-semibold text-slate-950">{formatPence(payment.amountPence)}</p>
          <div className="flex items-center gap-1">
            <IconButton
              onClick={onToggleDetails}
              ariaLabel={`${isExpanded ? 'Hide' : 'Show'} ${payment.name} details`}
              title={`${isExpanded ? 'Hide' : 'Show'} ${payment.name} details`}
            >
              <ChevronDown size={15} className={clsx('transition', isExpanded && 'rotate-180')} />
            </IconButton>
            <IconButton
              onClick={onToggleActive}
              ariaLabel={`${payment.active ? 'Pause' : 'Resume'} ${payment.name}`}
              title={`${payment.active ? 'Pause' : 'Resume'} ${payment.name}`}
            >
              {payment.active ? <PauseCircle size={16} /> : <PlayCircle size={16} />}
            </IconButton>
            <IconButton onClick={onEdit} ariaLabel={`Edit ${payment.name}`} title={`Edit ${payment.name}`}>
              <PenLine size={15} />
            </IconButton>
            <IconButton
              onClick={onDelete}
              ariaLabel={`Delete ${payment.name}`}
              title={`Delete ${payment.name}`}
              tone="danger"
            >
              <Trash2 size={15} />
            </IconButton>
          </div>
        </div>
      </div>

      {isExpanded && (
        <div className="mt-3 grid gap-2 border-t border-slate-100 pt-3 text-xs sm:grid-cols-2">
          <CompactDetail label="Schedule" value={`${getRecurringScheduleLabel(payment)} · ${payment.frequency}`} />
          <CompactDetail label="Amount" value={formatPence(payment.amountPence)} />
          <CompactDetail label="Pot" value={payment.potId ? `Paid from ${pot?.name ?? 'Archived pot'}` : 'No pot linked'} />
          <CompactDetail label="Card" value={cardLabel ? `Charged to ${cardLabel}` : 'No card linked'} />
        </div>
      )}
    </article>
  )
}

function CompactMetaPill({ icon, label, muted = false }: { icon: ReactNode; label: string; muted?: boolean }) {
  return (
    <span
      className={clsx(
        'inline-flex max-w-full items-center gap-1 rounded-md border px-1.5 py-0.5 text-[11px] font-semibold',
        muted
          ? 'border-slate-200 bg-slate-50 text-slate-500'
          : 'border-blue-100 bg-blue-50 text-blue-700',
      )}
    >
      <span className="shrink-0">{icon}</span>
      <span className="truncate">{label}</span>
    </span>
  )
}

function CompactDetail({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-slate-200/80 bg-white/80 px-2.5 py-2 shadow-sm shadow-slate-200/50">
      <p className="font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-0.5 font-semibold text-slate-950">{value}</p>
    </div>
  )
}

function IconButton({
  children,
  onClick,
  ariaLabel,
  title,
  tone = 'neutral',
}: {
  children: ReactNode
  onClick: () => void
  ariaLabel: string
  title: string
  tone?: 'neutral' | 'danger'
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={ariaLabel}
      title={title}
      className={clsx(
        'inline-flex size-7 items-center justify-center rounded-md transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2',
        tone === 'neutral' &&
          'border border-slate-200/90 bg-white/90 text-slate-600 shadow-sm shadow-slate-200/60 hover:-translate-y-0.5 hover:bg-white hover:text-slate-950 focus-visible:outline-slate-400',
        tone === 'danger' && 'bg-red-600 text-white hover:bg-red-700 focus-visible:outline-red-600',
      )}
    >
      {children}
    </button>
  )
}

function getRecurringScheduleLabel(payment: { dueDay?: number | null; dueDate?: string | null; frequency: RecurringFrequency }): string {
  if (isIntervalFrequency(payment.frequency)) {
    return payment.dueDate ? `First due ${payment.dueDate}` : 'First due date missing'
  }

  return payment.dueDay ? `Due day ${payment.dueDay}` : 'Due day missing'
}

function getRecurringCreditCardLabel(
  creditCardId: string | null | undefined,
  card: PlannerSnapshot['creditCards'][number] | undefined,
): string | null {
  if (!creditCardId) {
    return null
  }

  return card ? card.name : `missing card ${creditCardId}`
}

function isIntervalFrequency(frequency: RecurringFrequency): boolean {
  return frequency === 'weekly' || frequency === 'biweekly'
}

function isIsoDateInput(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value)
}

function RecurringPaymentFormFields({
  form,
  activePots,
  activeCards,
  onChange,
}: {
  form: RecurringFormState
  activePots: PlannerSnapshot['pots']
  activeCards: PlannerSnapshot['creditCards']
  onChange: (form: RecurringFormState) => void
}) {
  const usesIntervalAnchor = isIntervalFrequency(form.frequency)

  return (
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      <div className="sm:col-span-2 xl:col-span-1">
        <Field label="Name">
          <TextInput
            className="h-9"
            value={form.name}
            onChange={(event) => onChange({ ...form, name: event.target.value })}
            placeholder="Phone bill"
          />
        </Field>
      </div>
      <Field label="Amount">
        <TextInput
          className="h-9"
          inputMode="decimal"
          value={form.amount}
          onChange={(event) => onChange({ ...form, amount: event.target.value })}
          placeholder="22.00"
        />
      </Field>
      <div className="grid gap-3 sm:contents">
        {usesIntervalAnchor ? (
          <Field label="First due date">
            <TextInput
              className="h-9"
              type="date"
              value={form.dueDate}
              onChange={(event) => onChange({ ...form, dueDate: event.target.value })}
            />
          </Field>
        ) : (
          <Field label="Due day">
            <TextInput
              className="h-9"
              inputMode="numeric"
              value={form.dueDay}
              onChange={(event) => onChange({ ...form, dueDay: event.target.value })}
            />
          </Field>
        )}
        <Field label="Frequency">
          <SelectInput
            className="h-9"
            value={form.frequency}
            onChange={(event) => onChange({ ...form, frequency: event.target.value as RecurringFrequency })}
          >
            <option value="weekly">Weekly</option>
            <option value="biweekly">Biweekly</option>
            <option value="monthly">Monthly</option>
            <option value="yearly">Yearly</option>
          </SelectInput>
        </Field>
      </div>
      <Field label="Paid from pot">
        <SelectInput
          className="h-9"
          value={form.potId}
          onChange={(event) => onChange({ ...form, potId: event.target.value })}
        >
          <option value="">No pot</option>
          {activePots.map((pot) => (
            <option key={pot.id} value={pot.id}>
              {pot.name}
            </option>
          ))}
        </SelectInput>
      </Field>
      <Field label="Paid on credit card">
        <SelectInput
          className="h-9"
          value={form.creditCardId}
          onChange={(event) => onChange({ ...form, creditCardId: event.target.value })}
        >
          <option value="">Unlinked</option>
          {activeCards.map((card) => (
            <option key={card.id} value={card.id}>
              {card.name} ({card.provider})
            </option>
          ))}
        </SelectInput>
      </Field>
      <Field label="Priority">
        <SelectInput
          className="h-9"
          value={form.priority}
          onChange={(event) => onChange({ ...form, priority: event.target.value as RecurringPriority })}
        >
          <option value="essential">Essential</option>
          <option value="important">Important</option>
          <option value="optional">Optional</option>
        </SelectInput>
      </Field>
    </div>
  )
}

function NextPaydayOwedPanel({
  period,
  summary,
}: {
  period: PayPeriod | null
  summary: PayPeriodCostSummary
}) {
  return (
    <Panel
      title="What you owe next payday"
      accent="amber"
      density="compact"
      description={
        period
          ? `${period.startDate} to ${period.endDate}`
          : 'Create a paycheck plan to preview the next payday period.'
      }
    >
      {period ? (
        <div className="space-y-3">
          <div className="grid gap-2">
            <CompactPreviewMetric
              label="Total owed next payday"
              value={formatPence(summary.totalCostsPence)}
              tone={summary.totalCostsPence > 0 ? 'warning' : 'neutral'}
            />
            <CompactPreviewMetric
              label="Debt due"
              value={formatPence(summary.debtMinimumsPence)}
              tone={summary.debtMinimumsPence > 0 ? 'warning' : 'neutral'}
            />
            <CompactPreviewMetric
              label="Money left estimate"
              value={formatPence(summary.moneyLeftPence)}
              tone={summary.moneyLeftPence < 0 ? 'bad' : 'good'}
            />
          </div>

          <CompactBreakdownDetails title="Cost calculation" breakdown={getNextPaydayOwedBreakdown(summary, period)} />

          <details className="rounded-2xl border border-slate-200/90 bg-white/95 shadow-[0_14px_35px_rgba(15,23,42,0.05)]">
            <summary className="cursor-pointer list-none px-3 py-2.5">
              <div className="flex items-center justify-between gap-3">
                <span className="inline-flex items-center gap-2 text-sm font-semibold text-slate-950">
                  <CalendarDays size={15} />
                  Dated items
                </span>
                <span className="text-xs font-semibold text-slate-500">{summary.items.length}</span>
              </div>
            </summary>
            <div className="max-h-72 space-y-2 overflow-y-auto border-t border-slate-100 p-2.5">
              {summary.items.length > 0 ? (
                summary.items.map((item) => (
                  <div
                    key={item.id}
                    className="grid gap-2 rounded-lg border border-slate-200/80 bg-slate-50/80 px-3 py-2 text-sm shadow-sm shadow-slate-200/50 transition hover:bg-white sm:grid-cols-[1fr_auto]"
                  >
                    <div>
                      <p className="font-medium text-slate-800">{item.label}</p>
                      <p className="mt-0.5 text-xs text-slate-500">
                        {item.date} · {formatCostSource(item.source)}
                      </p>
                    </div>
                    <p className={item.amountPence < 0 ? 'font-semibold text-emerald-700' : 'font-semibold text-slate-950'}>
                      {item.amountPence < 0 ? '-' : ''}
                      {formatPence(Math.abs(item.amountPence))}
                    </p>
                  </div>
                ))
              ) : (
                <p className="rounded-lg border border-dashed border-slate-200/90 bg-slate-50/80 px-3 py-2 text-sm text-slate-500">
                  Nothing is dated inside the next payday period yet.
                </p>
              )}
            </div>
          </details>
        </div>
      ) : (
        <p className="rounded-lg border border-dashed border-slate-200/90 bg-slate-50/80 p-3 text-sm text-slate-500">
          No payday plan is available to build a next-period preview.
        </p>
      )}
    </Panel>
  )
}

function CompactPreviewMetric({
  label,
  value,
  tone,
}: {
  label: string
  value: string
  tone: 'neutral' | 'good' | 'warning' | 'bad'
}) {
  return (
    <div
      className={clsx(
        'flex items-center justify-between gap-3 rounded-lg border px-3 py-2 shadow-sm',
        tone === 'neutral' && 'border-slate-200/90 bg-white/95',
        tone === 'good' && 'border-emerald-200 bg-emerald-50 bg-[linear-gradient(135deg,#ffffff,#ecfdf5)]',
        tone === 'warning' && 'border-amber-200 bg-amber-50 bg-[linear-gradient(135deg,#ffffff,#fffbeb)]',
        tone === 'bad' && 'border-red-200 bg-red-50 bg-[linear-gradient(135deg,#ffffff,#fef2f2)]',
      )}
    >
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <p className="text-sm font-semibold text-slate-950">{value}</p>
    </div>
  )
}

function CompactBreakdownDetails({
  title,
  breakdown,
}: {
  title: string
  breakdown: CalculationBreakdown
}) {
  return (
    <details className="rounded-lg border border-slate-200/90 bg-white/95 shadow-sm shadow-slate-200/60">
      <summary className="cursor-pointer list-none px-3 py-2.5">
        <div className="flex items-center justify-between gap-3">
          <p className="text-sm font-semibold text-slate-950">{title}</p>
          <ChevronDown size={15} className="text-slate-500" />
        </div>
      </summary>
      <div className="space-y-2 border-t border-slate-100 p-2.5">
        {breakdown.formula && <p className="text-xs leading-5 text-slate-500">{breakdown.formula}</p>}
        <div className="space-y-1">
          {breakdown.lines.map((line) => (
            <div key={`${line.label}-${line.value}`} className="flex items-start justify-between gap-3 rounded-lg border border-slate-200/80 bg-white/90 px-2.5 py-2 shadow-sm shadow-slate-200/50">
              <div className="min-w-0">
                <p className="truncate text-xs font-semibold text-slate-700">{line.label}</p>
                {line.detail && <p className="mt-0.5 text-xs leading-4 text-slate-500">{line.detail}</p>}
              </div>
              <p className="shrink-0 text-xs font-semibold text-slate-950">{line.value}</p>
            </div>
          ))}
        </div>
        {breakdown.note && <p className="text-xs leading-5 text-slate-500">{breakdown.note}</p>}
      </div>
    </details>
  )
}

function getNextPaydayOwedBreakdown(
  summary: PayPeriodCostSummary,
  period: PayPeriod,
): CalculationBreakdown {
  return {
    formula: 'Total owed next payday = recurring + saved payments + manual spending + pot top-ups + debt reserves + debt due + credit pots + credit-card net.',
    lines: [
      {
        label: 'Recurring not on cards',
        value: formatPence(summary.directRecurringPence),
        detail: `Due from ${period.startDate} to ${period.endDate}.`,
        tone: 'add',
      },
      {
        label: 'Saved payments not on cards',
        value: formatPence(summary.savedPaymentsPence),
        detail: 'One-off saved payments due in this next pay period.',
        tone: 'add',
      },
      {
        label: 'Manual spending not on cards',
        value: formatPence(summary.manualSpendingPence),
        detail: 'Manual spending already dated inside this next pay period.',
        tone: 'add',
      },
      {
        label: 'Pot payday top-ups',
        value: formatPence(summary.potAllocationsPence),
        detail: 'Automatic pot money already planned for this next period.',
        tone: 'add',
      },
      {
        label: 'Debt reserves',
        value: formatPence(summary.debtReservesPence),
        detail: 'Accepted set-asides already planned for this next period.',
        tone: 'add',
      },
      {
        label: 'Debt due',
        value: formatPence(summary.debtMinimumsPence),
        detail: 'Remaining outstanding balances overdue or due by this next period end.',
        tone: 'add',
      },
      {
        label: 'Credit card pots',
        value: formatPence(summary.creditCardPotsPence),
        detail: 'Paycheck-funded credit pots planned inside this next pay period.',
        tone: 'add',
      },
      {
        label: 'Credit-card charges',
        value: formatPence(summary.creditCardChargesPence),
        detail: 'Recurring, saved, and manual spends linked to cards.',
        tone: 'add',
      },
      {
        label: 'Card repayments',
        value: `-${formatPence(summary.creditCardRepaymentsPence)}`,
        detail: 'Repayments dated inside this next pay period.',
        tone: 'subtract',
      },
      {
        label: 'Credit-card net used',
        value: formatPence(summary.creditCardNetPence),
        detail: 'Card charges minus repayments, never below zero.',
        tone: 'result',
      },
      {
        label: 'Total owed next payday',
        value: formatPence(summary.totalCostsPence),
        tone: 'result',
      },
    ],
    note: `${summary.items.length} dated items feed this next-payday preview.`,
  }
}

function getNextPaydayPeriod(currentPeriod: PayPeriod, frequency: PayFrequency): PayPeriod {
  const nextDates = createNextPayPeriod(currentPeriod.nextPayday, frequency)

  return {
    id: 'next-payday-preview',
    startDate: nextDates.startDate,
    endDate: nextDates.endDate,
    payday: currentPeriod.nextPayday,
    nextPayday: nextDates.nextPayday,
    payFrequency: frequency,
    incomePence: currentPeriod.incomePence,
    status: 'planned',
    createdAt: currentPeriod.updatedAt,
    updatedAt: currentPeriod.updatedAt,
  }
}

function getPreviewPotTopUps(snapshot: PlannerSnapshot, period: PayPeriod): PotAllocation[] {
  const existingAutoPotIds = new Set(
    snapshot.potAllocations
      .filter((allocation) => allocation.payPeriodId === period.id && allocation.source === 'pot_auto')
      .map((allocation) => allocation.potId),
  )

  return snapshot.pots
    .filter((pot) => !pot.archived && (pot.targetPence ?? 0) > 0 && !existingAutoPotIds.has(pot.id))
    .map((pot) => ({
      id: `preview-pot-${period.id}-${pot.id}`,
      payPeriodId: period.id,
      potId: pot.id,
      amountPence: pot.targetPence ?? 0,
      source: 'pot_auto' as const,
      recurringPaymentId: null,
      createdAt: period.createdAt,
      updatedAt: period.updatedAt,
    }))
}

function formatCostSource(source: PayPeriodCostSummary['items'][number]['source']): string {
  if (source === 'recurring') {
    return 'Recurring'
  }

  if (source === 'saved_payment') {
    return 'Saved payment'
  }

  if (source === 'manual_spend') {
    return 'Manual spend'
  }

  if (source === 'pot_allocation') {
    return 'Pot top-up'
  }

  if (source === 'debt_minimum') {
    return 'Debt due'
  }

  if (source === 'debt_reserve') {
    return 'Debt reserve'
  }

  if (source === 'credit_card_pot') {
    return 'Credit pot'
  }

  return 'Card repayment'
}
