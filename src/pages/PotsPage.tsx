import { useMemo, useState } from 'react'
import { clsx } from 'clsx'
import {
  Banknote,
  Car,
  CreditCard,
  Dumbbell,
  Fuel,
  Gift,
  Heart,
  Home,
  PenLine,
  Phone,
  PiggyBank,
  Plane,
  Plus,
  Shield,
  Target,
  Trash2,
  Utensils,
  Wallet,
  X,
  Zap,
  type LucideIcon,
} from 'lucide-react'

import {
  findPayPeriodForDate,
  formatPence,
  getAppTodayIso,
  getCreditCardAllocationSummary,
  parsePoundsToPence,
  toIsoDate,
} from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import {
  Button,
  CalculationDetails,
  Field,
  Panel,
  SelectInput,
  TextInput,
  type CalculationBreakdown,
} from '../components/ui'
import type { PayPeriod, Pot, PotAllocation, PotType, RecurringPayment, Transaction } from '../types/models'

const colors = ['#2563eb', '#16a34a', '#ea580c', '#7c3aed', '#0f766e', '#4338ca', '#475569']
const builtinCategories = ['All Pots', 'Spending', 'Bills', 'Savings'] as const
const customCategoryAll = 'All Pots'

const iconOptions = [
  { key: 'wallet', label: 'Wallet', Icon: Wallet },
  { key: 'home', label: 'Home', Icon: Home },
  { key: 'card', label: 'Card', Icon: CreditCard },
  { key: 'shield', label: 'Shield', Icon: Shield },
  { key: 'car', label: 'Car', Icon: Car },
  { key: 'fuel', label: 'Fuel', Icon: Fuel },
  { key: 'gym', label: 'Gym', Icon: Dumbbell },
  { key: 'food', label: 'Food', Icon: Utensils },
  { key: 'phone', label: 'Phone', Icon: Phone },
  { key: 'zap', label: 'Bolt', Icon: Zap },
  { key: 'gift', label: 'Gift', Icon: Gift },
  { key: 'plane', label: 'Travel', Icon: Plane },
  { key: 'heart', label: 'Heart', Icon: Heart },
  { key: 'target', label: 'Target', Icon: Target },
  { key: 'money', label: 'Money', Icon: Banknote },
  { key: 'savings', label: 'Savings', Icon: PiggyBank },
] satisfies Array<{ key: string; label: string; Icon: LucideIcon }>

type PotLinkType = 'none' | 'credit_card' | 'debt'

interface PotFormState {
  name: string
  type: PotType
  category: string
  icon: string
  paycheckAmount: string
  balance: string
  color: string
  linkType: PotLinkType
  linkedEntityId: string
}

interface PotProgress {
  targetPence: number
  coveredPence: number
  percent: number
  targetLabel: string
  sourceLabels: string[]
  shortfallPence: number
  dueIso: string | null
}

interface PotActivityItem {
  id: string
  title: string
  detail: string
  amountPence: number
}

const emptyPotForm = (): PotFormState => ({
  name: '',
  type: 'spending',
  category: 'Spending',
  icon: 'wallet',
  paycheckAmount: '',
  balance: '',
  color: colors[0],
  linkType: 'none',
  linkedEntityId: '',
})

export function PotsPage({
  snapshot,
  actions,
  selectedPayPeriod,
  isCreateModalOpen,
  onCreateModalOpenChange,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
  selectedPayPeriod?: PayPeriod | null
  isCreateModalOpen?: boolean
  onCreateModalOpenChange?: (isOpen: boolean) => void
}) {
  const today = getAppTodayIso(snapshot.settings)
  const [createForm, setCreateForm] = useState<PotFormState>(emptyPotForm)
  const [editForm, setEditForm] = useState<PotFormState | null>(null)
  const [openPotId, setOpenPotId] = useState<string | null>(null)
  const [editingPotId, setEditingPotId] = useState<string | null>(null)
  const [localCreateModalOpen, setLocalCreateModalOpen] = useState(false)
  const [activeCategory, setActiveCategory] = useState<string>(customCategoryAll)
  const [isAddingCategory, setIsAddingCategory] = useState(false)
  const [newCategory, setNewCategory] = useState('')
  const [customCategories, setCustomCategories] = useState<string[]>([])
  const [topUpPotId, setTopUpPotId] = useState('')
  const [topUpAmount, setTopUpAmount] = useState('')
  const activePots = snapshot.pots.filter((pot) => !pot.archived)
  const categoryOptions = useMemo(() => getPotCategoryOptions(activePots, customCategories), [activePots, customCategories])
  const visiblePots = activePots.filter((pot) => isPotInCategory(pot, activeCategory))
  const isCreateOpen = isCreateModalOpen ?? localCreateModalOpen
  const setCreateOpen = onCreateModalOpenChange ?? setLocalCreateModalOpen
  const topUpAmountPence = parsePoundsToPence(topUpAmount)
  const canTopUpPot = Boolean(selectedPayPeriod && topUpPotId && topUpAmountPence > 0)

  async function submitPot() {
    if (!createForm.name.trim()) {
      return
    }

    await actions.addPot(potFormToPayload(createForm))
    resetCreateForm()
    setCreateOpen(false)
  }

  async function submitEditedPot() {
    if (!editingPotId || !editForm?.name.trim()) {
      return
    }

    await actions.updatePot(editingPotId, potFormToPayload(editForm))
    closeEditModal()
  }

  function startEditingPot(potId: string) {
    const pot = snapshot.pots.find((candidate) => candidate.id === potId)

    if (!pot) {
      return
    }

    setEditingPotId(pot.id)
    setEditForm({
      name: pot.name,
      type: pot.type,
      category: getPotCategory(pot),
      icon: getPotIconKey(pot),
      paycheckAmount: pot.targetPence ? (pot.targetPence / 100).toFixed(2) : '',
      balance: (pot.balancePence / 100).toFixed(2),
      color: pot.color,
      linkType: getPotLinkType(pot),
      linkedEntityId: pot.linkedCreditCardId ?? pot.linkedDebtId ?? '',
    })
  }

  function resetCreateForm() {
    setCreateForm(emptyPotForm())
  }

  function closeEditModal() {
    setEditingPotId(null)
    setEditForm(null)
  }

  function submitCustomCategory() {
    const category = cleanCategory(newCategory)

    if (!category) {
      return
    }

    setCustomCategories((current) => current.some((item) => item.toLowerCase() === category.toLowerCase()) ? current : [...current, category])
    setActiveCategory(category)
    setCreateForm((current) => ({ ...current, category }))
    setNewCategory('')
    setIsAddingCategory(false)
  }

  async function submitPotTopUp() {
    if (!selectedPayPeriod || !topUpPotId || topUpAmountPence <= 0) {
      return
    }

    const allocationId = getPotTopUpAllocationId(selectedPayPeriod.id, topUpPotId)
    const existingTopUpPence = snapshot.potAllocations.find((allocation) => allocation.id === allocationId)?.amountPence ?? 0

    await actions.upsertPaycheckPotAllocation({
      id: allocationId,
      payPeriodId: selectedPayPeriod.id,
      potId: topUpPotId,
      amountPence: existingTopUpPence + topUpAmountPence,
    })

    setTopUpAmount('')
  }

  return (
    <div className="space-y-6">
      <Panel
        title="Top up pots"
        description={selectedPayPeriod ? `Comes out of ${selectedPayPeriod.payday} pay.` : 'Create a paycheck first.'}
        accent="emerald"
        density="compact"
      >
        <div className="grid gap-3 md:grid-cols-[minmax(0,1fr)_10rem_auto]">
          <Field label="Pot to top up">
            <SelectInput value={topUpPotId} onChange={(event) => setTopUpPotId(event.target.value)}>
              <option value="">Choose pot</option>
              {activePots.map((pot) => (
                <option key={pot.id} value={pot.id}>
                  {pot.name}
                </option>
              ))}
            </SelectInput>
          </Field>
          <Field label="Top up amount">
            <TextInput
              inputMode="decimal"
              value={topUpAmount}
              onChange={(event) => setTopUpAmount(event.target.value)}
              placeholder="25.00"
            />
          </Field>
          <div className="flex items-end">
            <Button onClick={submitPotTopUp} disabled={!canTopUpPot}>
              <Plus size={18} />
              Top up pot
            </Button>
          </div>
        </div>
      </Panel>

      <Panel
        title="Pots"
        description="Click a pot to see spending, recurring payments, and allocations tied to it."
        accent="blue"
        density="compact"
        action={
          onCreateModalOpenChange ? undefined : (
            <Button onClick={() => setCreateOpen(true)}>
              <Plus size={18} />
              Create pot
            </Button>
          )
        }
      >
        <div className="space-y-4">
            <div className="flex flex-wrap items-center gap-2">
              {categoryOptions.map((category) => (
                <button
                  key={category}
                  type="button"
                  onClick={() => setActiveCategory(category)}
                  className={clsx(
                    'inline-flex min-h-10 items-center justify-center rounded-lg border px-4 text-sm font-semibold transition',
                    activeCategory === category
                      ? 'border-blue-600 bg-blue-600 text-white shadow-sm shadow-blue-600/25'
                      : 'border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50',
                  )}
                >
                  {category}
                </button>
              ))}
              <button
                type="button"
                aria-label="Add pot category"
                onClick={() => setIsAddingCategory((current) => !current)}
                className="inline-flex size-10 items-center justify-center rounded-lg border border-slate-200 bg-white text-slate-700 transition hover:border-slate-300 hover:bg-slate-50"
              >
                <Plus size={16} />
              </button>
            </div>

            {isAddingCategory && (
              <div className="flex flex-col gap-2 rounded-lg border border-slate-200 bg-slate-50 p-3 sm:flex-row">
                <TextInput
                  value={newCategory}
                  onChange={(event) => setNewCategory(event.target.value)}
                  placeholder="New section name"
                  aria-label="New pot category"
                />
                <Button onClick={submitCustomCategory}>Add section</Button>
              </div>
            )}

            <div className="grid grid-cols-1 items-start gap-4 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4">
              {visiblePots.map((pot) => {
                const isOpen = openPotId === pot.id
                const activityItems = getPotActivityItems(pot.id, snapshot)
                const linkedRecurringPayments = getPotLinkedRecurringPayments(pot.id, snapshot)
                const progress = getPotProgress(pot, snapshot, today)

                return (
                  <PotCard
                    key={pot.id}
                    pot={pot}
                    progress={progress}
                    activityItems={activityItems}
                    linkedRecurringPayments={linkedRecurringPayments}
                    today={today}
                    isOpen={isOpen}
                    onToggle={() => setOpenPotId(isOpen ? null : pot.id)}
                    onEdit={() => startEditingPot(pot.id)}
                    onDelete={() => {
                      if (window.confirm(`Delete ${pot.name}?`)) {
                        void actions.deletePot(pot.id)
                      }
                    }}
                  />
                )
              })}

              {visiblePots.length === 0 && (
                <p className="rounded-lg bg-slate-50 p-4 text-sm text-slate-500 sm:col-span-2 lg:col-span-3 2xl:col-span-4">
                  No pots in this section yet.
                </p>
              )}
            </div>
          </div>
      </Panel>

      {isCreateOpen && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/45 p-4">
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Create pot"
            className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-lg border border-slate-200 bg-white p-5 shadow-xl"
          >
            <div className="mb-4 flex items-start justify-between gap-4 border-b border-slate-100 pb-4">
              <div>
                <h2 className="text-base font-semibold text-slate-950">Create pot</h2>
                <p className="mt-1 text-sm text-slate-500">
                  Add money you already set aside, then linked payments can spend from that pot when due.
                </p>
              </div>
              <Button variant="ghost" onClick={() => setCreateOpen(false)} aria-label="Close create pot">
                <X size={18} />
              </Button>
            </div>
            <div className="space-y-4">
              <PotFormFields
                form={createForm}
                snapshot={snapshot}
                categoryOptions={categoryOptions}
                onChange={setCreateForm}
              />
              <div className="flex flex-wrap gap-3">
                <Button onClick={submitPot}>Add pot</Button>
                <Button
                  variant="secondary"
                  onClick={() => {
                    resetCreateForm()
                    setCreateOpen(false)
                  }}
                >
                  Cancel
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}

      {editingPotId && editForm && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-slate-950/45 p-4">
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Edit pot"
            className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-lg border border-slate-200 bg-white p-5 shadow-xl"
          >
            <div className="mb-4 flex items-start justify-between gap-4 border-b border-slate-100 pb-4">
              <div>
                <h2 className="text-base font-semibold text-slate-950">Edit pot</h2>
                <p className="mt-1 text-sm text-slate-500">Update this pot without replacing the create form.</p>
              </div>
              <Button variant="ghost" onClick={closeEditModal} aria-label="Close edit pot">
                <X size={18} />
              </Button>
            </div>
            <div className="space-y-4">
              <PotFormFields
                form={editForm}
                snapshot={snapshot}
                categoryOptions={categoryOptions}
                onChange={setEditForm}
              />
              <div className="flex flex-wrap gap-3">
                <Button onClick={submitEditedPot}>Save pot</Button>
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

function PotCard({
  pot,
  progress,
  activityItems,
  linkedRecurringPayments,
  today,
  isOpen,
  onToggle,
  onEdit,
  onDelete,
}: {
  pot: Pot
  progress: PotProgress
  activityItems: PotActivityItem[]
  linkedRecurringPayments: RecurringPayment[]
  today: string
  isOpen: boolean
  onToggle: () => void
  onEdit: () => void
  onDelete: () => void
}) {
  const icon = getPotIconOption(pot)
  const Icon = icon.Icon
  const dueLabel = getPotDueLabel(progress, today)
  const progressWidth = `${Math.min(100, Math.max(0, progress.percent))}%`
  const sourceLabels = progress.sourceLabels.slice(0, 2)
  const hiddenSourceLabelCount = Math.max(0, progress.sourceLabels.length - sourceLabels.length)

  return (
    <div
      data-testid="pot-card"
      className={clsx(
        'flex flex-col rounded-xl border border-slate-200 bg-white p-4 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md',
        isOpen ? 'min-h-[330px]' : 'h-[330px]',
      )}
    >
      <div className="flex min-h-[64px] items-start justify-between gap-3">
        <button
          type="button"
          onClick={onToggle}
          aria-expanded={isOpen}
          aria-label={`${isOpen ? 'Hide' : 'View'} ${pot.name} activity`}
          className="grid min-w-0 flex-1 grid-cols-[auto_1fr] items-start gap-3 rounded-lg text-left outline-none focus-visible:ring-4 focus-visible:ring-slate-100"
        >
          <span
            className="flex size-14 shrink-0 items-center justify-center rounded-full"
            style={{
              backgroundColor: withAlpha(pot.color, 0.14),
              color: pot.color,
            }}
          >
            <Icon size={26} strokeWidth={2.4} />
          </span>
          <span className="min-w-0 pt-2">
            <span className="block truncate text-base font-semibold text-slate-950">{pot.name}</span>
            <span className="mt-0.5 block truncate text-sm text-slate-500">{getPotCategory(pot)}</span>
          </span>
        </button>

        <div className="flex shrink-0 items-center gap-1">
          <button
            type="button"
            className="inline-flex size-7 items-center justify-center rounded-md text-slate-500 transition hover:bg-slate-100 hover:text-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-400"
            onClick={onEdit}
            aria-label={`Edit ${pot.name}`}
            title={`Edit ${pot.name}`}
          >
            <PenLine size={14} />
          </button>
          <button
            type="button"
            className="inline-flex size-7 items-center justify-center rounded-md text-red-600 transition hover:bg-red-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600"
            onClick={onDelete}
            aria-label={`Delete ${pot.name}`}
            title={`Delete ${pot.name}`}
          >
            <Trash2 size={14} />
          </button>
        </div>
      </div>

      <p className="mt-5 text-3xl font-semibold tracking-normal text-slate-950">{formatPence(pot.balancePence)}</p>

      <div className="mt-4">
        <div className="h-1.5 overflow-hidden rounded-full bg-slate-100">
          <div
            className="h-full rounded-full transition-all"
            style={{
              width: progress.targetPence > 0 ? progressWidth : '0%',
              backgroundColor: pot.color,
            }}
          />
        </div>
        <div className="mt-3 flex items-center justify-between gap-3 text-sm">
          <span className="font-semibold" style={{ color: pot.color }}>
            {progress.targetPence > 0 ? `${progress.percent}%` : '0%'}
          </span>
          <span className="min-w-0 truncate text-right text-slate-500" title={progress.targetLabel}>
            {progress.targetLabel}
          </span>
        </div>
      </div>

      <div className="mt-auto pt-4">
        <div className="min-h-12">
          {dueLabel && (
            <div
              className="truncate rounded-lg px-3 py-2 text-sm font-medium"
              style={{
                backgroundColor: withAlpha(pot.color, 0.1),
                color: pot.color,
              }}
              title={dueLabel}
            >
              {dueLabel}
            </div>
          )}
        </div>

        <div className="mt-2 flex min-h-7 flex-nowrap gap-1.5 overflow-hidden">
          {sourceLabels.map((label) => (
            <span
              key={label}
              className="max-w-[9rem] truncate rounded-full bg-slate-100 px-2 py-1 text-xs font-medium text-slate-600"
              title={label}
            >
              {label}
            </span>
          ))}
          {hiddenSourceLabelCount > 0 && (
            <span className="shrink-0 rounded-full bg-slate-100 px-2 py-1 text-xs font-medium text-slate-600">
              +{hiddenSourceLabelCount}
            </span>
          )}
        </div>
      </div>

      {isOpen && (
        <div role="region" aria-label={`${pot.name} activity`} className="mt-4 border-t border-slate-100 pt-4">
          <CalculationDetails breakdown={getPotBalanceBreakdown(pot.id, pot.balancePence, activityItems)} />
          {activityItems.length > 0 ? (
            <div className="mt-3 space-y-2">
              {activityItems.map((item) => (
                <div
                  key={item.id}
                  className="grid grid-cols-[1fr_auto] items-center gap-3 rounded-lg bg-slate-50 px-3 py-2"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold text-slate-950">{item.title}</p>
                    <p className="mt-1 text-xs text-slate-500">{item.detail}</p>
                  </div>
                  <p className={clsx('text-sm font-semibold', item.amountPence < 0 ? 'text-red-700' : 'text-emerald-700')}>
                    {formatSignedPence(item.amountPence)}
                  </p>
                </div>
              ))}
            </div>
          ) : (
            <p className="rounded-lg bg-slate-50 p-3 text-sm text-slate-500">
              No activity recorded for this pot yet.
            </p>
          )}
          {linkedRecurringPayments.length > 0 && (
            <div className="mt-4 rounded-lg border border-slate-200 bg-white">
              <div className="border-b border-slate-100 px-3 py-2">
                <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Linked recurring payments</p>
              </div>
              <div className="divide-y divide-slate-100">
                {linkedRecurringPayments.map((payment) => (
                  <div key={payment.id} className="grid grid-cols-[1fr_auto] gap-3 px-3 py-2">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold text-slate-950">{payment.name}</p>
                      <p className="mt-1 text-xs text-slate-500">
                        {payment.frequency} · due day {payment.dueDay ?? 'set date'}
                      </p>
                    </div>
                    <p className="text-sm font-semibold text-slate-950">{formatPence(payment.amountPence)}</p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

function PotFormFields({
  form,
  snapshot,
  categoryOptions,
  onChange,
}: {
  form: PotFormState
  snapshot: PlannerSnapshot
  categoryOptions: string[]
  onChange: (form: PotFormState) => void
}) {
  const creditCards = snapshot.creditCards.filter(
    (card) => !card.archived || card.id === form.linkedEntityId,
  )
  const debts = snapshot.debts.filter(
    (debt) => debt.status !== 'archived' || debt.id === form.linkedEntityId,
  )

  return (
    <>
      <Field label="Pot name">
        <TextInput
          value={form.name}
          onChange={(event) => onChange({ ...form, name: event.target.value })}
          placeholder="Car insurance"
        />
      </Field>
      <Field label="Type">
        <SelectInput
          value={form.type}
          onChange={(event) => {
            const type = event.target.value as PotType
            const currentCategory = cleanCategory(form.category)
            const shouldUseTypeCategory = !currentCategory || isBuiltinPotCategory(currentCategory)

            onChange({
              ...form,
              type,
              category: shouldUseTypeCategory ? defaultCategoryForPotType(type) : form.category,
            })
          }}
        >
          <option value="spending">Spending</option>
          <option value="reserved">Reserved</option>
          <option value="saving">Saving</option>
          <option value="investment">Investment</option>
          <option value="buffer">Buffer</option>
        </SelectInput>
      </Field>
      <Field label="Category" hint="This controls the little section tabs above the pot cards.">
        <TextInput
          value={form.category}
          onChange={(event) => onChange({ ...form, category: event.target.value })}
          placeholder="Spending"
          list="pot-category-options"
        />
        <datalist id="pot-category-options">
          {categoryOptions.filter((category) => category !== customCategoryAll).map((category) => (
            <option key={category} value={category} />
          ))}
        </datalist>
      </Field>
      <Field label="Add each paycheck" hint="This amount is automatically deducted from every confirmed paycheck and added to this pot.">
        <TextInput
          inputMode="decimal"
          value={form.paycheckAmount}
          onChange={(event) => onChange({ ...form, paycheckAmount: event.target.value })}
          placeholder="50.00"
        />
      </Field>
      <Field label="Current balance" hint="Money already set aside in this pot before you started using the app.">
        <TextInput
          inputMode="decimal"
          value={form.balance}
          onChange={(event) => onChange({ ...form, balance: event.target.value })}
          placeholder="0.00"
        />
      </Field>
      <Field label="Link this pot to">
        <SelectInput
          value={form.linkType}
          onChange={(event) =>
            onChange({
              ...form,
              linkType: event.target.value as PotLinkType,
              linkedEntityId: '',
            })
          }
        >
          <option value="none">No link</option>
          <option value="credit_card">Credit card</option>
          <option value="debt">Debt</option>
        </SelectInput>
      </Field>
      {form.linkType === 'credit_card' && (
        <Field label="Credit card">
          <SelectInput
            value={form.linkedEntityId}
            onChange={(event) => onChange({ ...form, linkedEntityId: event.target.value })}
          >
            <option value="">Choose credit card</option>
            {creditCards.map((card) => (
              <option key={card.id} value={card.id}>
                {card.name}
              </option>
            ))}
          </SelectInput>
        </Field>
      )}
      {form.linkType === 'debt' && (
        <Field label="Debt">
          <SelectInput
            value={form.linkedEntityId}
            onChange={(event) => onChange({ ...form, linkedEntityId: event.target.value })}
          >
            <option value="">Choose debt</option>
            {debts.map((debt) => (
              <option key={debt.id} value={debt.id}>
                {debt.name}
              </option>
            ))}
          </SelectInput>
        </Field>
      )}
      <Field label="Symbol">
        <div className="grid grid-cols-4 gap-2 sm:grid-cols-6">
          {iconOptions.map((option) => {
            const Icon = option.Icon

            return (
              <button
                key={option.key}
                type="button"
                aria-label={`Use ${option.label} symbol`}
                onClick={() => onChange({ ...form, icon: option.key })}
                className={clsx(
                  'flex size-10 items-center justify-center rounded-lg border transition',
                  option.key === form.icon
                    ? 'border-slate-950 bg-slate-950 text-white'
                    : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50',
                )}
                title={option.label}
              >
                <Icon size={18} />
              </button>
            )
          })}
        </div>
      </Field>
      <Field label="Colour">
        <div className="flex flex-wrap gap-2">
          {colors.map((option) => (
            <button
              key={option}
              type="button"
              aria-label={`Use colour ${option}`}
              onClick={() => onChange({ ...form, color: option })}
              className="size-8 rounded-full border-2"
              style={{
                backgroundColor: option,
                borderColor: option === form.color ? '#0f172a' : 'white',
                boxShadow: option === form.color ? '0 0 0 2px #cbd5e1' : '0 0 0 1px #e2e8f0',
              }}
            />
          ))}
        </div>
      </Field>
    </>
  )
}

function potFormToPayload(form: PotFormState) {
  return {
    name: form.name.trim(),
    type: form.type,
    category: cleanCategory(form.category) || defaultCategoryForPotType(form.type),
    icon: form.icon,
    balancePence: form.balance ? parsePoundsToPence(form.balance) : 0,
    targetPence: form.paycheckAmount ? parsePoundsToPence(form.paycheckAmount) : null,
    color: form.color,
    linkedCreditCardId: form.linkType === 'credit_card' ? form.linkedEntityId || null : null,
    linkedDebtId: form.linkType === 'debt' ? form.linkedEntityId || null : null,
  }
}

function getPotTopUpAllocationId(payPeriodId: string, potId: string): string {
  return `pot-top-up-${payPeriodId}-${potId}`
}

function getPotLinkType(pot: Pot): PotLinkType {
  if (pot.linkedCreditCardId) {
    return 'credit_card'
  }

  if (pot.linkedDebtId) {
    return 'debt'
  }

  return 'none'
}

function getPotProgress(pot: Pot, snapshot: PlannerSnapshot, today: string): PotProgress {
  const sourceLabels: string[] = []
  let linkedTargetPence = 0
  let dueIso: string | null = null
  let usesForecastTarget = false

  const linkedRecurringPayments = getPotLinkedRecurringPayments(pot.id, snapshot)
  const recurringTargetPence = linkedRecurringPayments.reduce((total, payment) => total + payment.amountPence, 0)

  if (recurringTargetPence > 0) {
    linkedTargetPence += recurringTargetPence
    sourceLabels.push('Recurring')
    dueIso = minIsoDate(dueIso, getEarliestRecurringDueDate(linkedRecurringPayments, today))
  }

  if (pot.linkedCreditCardId) {
    const creditCardPayPeriod = getCurrentOrLatestPayPeriod(snapshot.payPeriods, today)
    const cardSummary = getCreditCardAllocationSummary({
      creditCards: snapshot.creditCards,
      recurringPayments: snapshot.recurringPayments,
      customPayments: snapshot.customPayments,
      transactions: snapshot.transactions,
      repayments: snapshot.creditCardRepayments,
      creditCardPots: snapshot.creditCardPots,
      pots: snapshot.pots,
      payPeriod: creditCardPayPeriod,
      asOfDate: today,
    }).cards.find((summary) => summary.card.id === pot.linkedCreditCardId)

    if (cardSummary) {
      const cardUsesForecastTarget = cardSummary.forecastOwedPence > cardSummary.actualOwedPence
      const cardTargetPence = cardUsesForecastTarget
        ? cardSummary.forecastOwedPence
        : cardSummary.actualOwedPence

      if (cardTargetPence > 0) {
        linkedTargetPence += cardTargetPence
        usesForecastTarget = usesForecastTarget || cardUsesForecastTarget
        sourceLabels.push(`${cardSummary.card.name} card`)
        dueIso = minIsoDate(
          dueIso,
          cardUsesForecastTarget
            ? creditCardPayPeriod?.payday ?? getCreditCardDueIso(cardSummary.card, today)
            : getCreditCardDueIso(cardSummary.card, today),
        )
      }
    }
  }

  if (pot.linkedCreditCardId) {
    const card = snapshot.creditCards.find((candidate) => candidate.id === pot.linkedCreditCardId)

    if (!card) {
      sourceLabels.push(`missing card ${pot.linkedCreditCardId}`)
    }
  }

  if (pot.linkedDebtId) {
    const debt = snapshot.debts.find((candidate) => candidate.id === pot.linkedDebtId && candidate.status !== 'archived')

    if (debt && debt.currentBalancePence > 0) {
      linkedTargetPence += debt.currentBalancePence
      sourceLabels.push(`${debt.name} debt`)
      dueIso = minIsoDate(dueIso, debt.dueDate)
    }
  }

  const manualTargetPence = Math.max(0, pot.targetPence ?? 0)
  const targetPence = linkedTargetPence > 0 ? linkedTargetPence : manualTargetPence
  const coveredPence = Math.max(0, pot.balancePence)
  const shortfallPence = Math.max(0, targetPence - coveredPence)

  return {
    targetPence,
    coveredPence,
    percent: targetPence > 0 ? Math.round((coveredPence / targetPence) * 100) : 0,
    targetLabel: targetPence > 0 ? `${formatPence(targetPence)}${usesForecastTarget ? ' forecast target' : ' target'}` : 'No target yet',
    sourceLabels,
    shortfallPence,
    dueIso,
  }
}

function getCurrentOrLatestPayPeriod(payPeriods: PlannerSnapshot['payPeriods'], today: string): PlannerSnapshot['payPeriods'][number] | null {
  const currentPeriod = findPayPeriodForDate(payPeriods, today)

  if (currentPeriod) {
    return currentPeriod
  }

  const activePeriod = payPeriods.find((period) => period.status === 'active')

  if (activePeriod) {
    return activePeriod
  }

  const previousPeriods = payPeriods
    .filter((period) => period.startDate <= today)
    .sort((left, right) => right.startDate.localeCompare(left.startDate))

  if (previousPeriods[0]) {
    return previousPeriods[0]
  }

  return [...payPeriods].sort((left, right) => right.startDate.localeCompare(left.startDate))[0] ?? null
}

function getPotDueLabel(progress: PotProgress, today: string): string | null {
  if (progress.targetPence <= 0 || progress.shortfallPence <= 0) {
    return null
  }

  if (!progress.dueIso) {
    return `Top up ${formatPence(progress.shortfallPence)}`
  }

  const days = getDaysUntil(progress.dueIso, today)
  const dueText = days <= 0 ? 'Due now' : `Due in ${days} day${days === 1 ? '' : 's'}`

  return `${dueText} • ${formatPence(progress.shortfallPence)} left`
}

function getPotActivityItems(potId: string, snapshot: PlannerSnapshot): PotActivityItem[] {
  const transactions = snapshot.transactions
    .filter((transaction) => transaction.potId === potId)
    .map((transaction) => transactionToActivityItem(transaction))
  const allocations = snapshot.potAllocations
    .filter((allocation) => allocation.potId === potId)
    .map((allocation) => allocationToActivityItem(allocation, snapshot))

  return [...transactions, ...allocations]
}

function getPotLinkedRecurringPayments(potId: string, snapshot: PlannerSnapshot): RecurringPayment[] {
  return snapshot.recurringPayments
    .filter((payment) => payment.active && payment.potId === potId)
    .sort((a, b) => a.name.localeCompare(b.name))
}

function getPotBalanceBreakdown(
  potId: string,
  balancePence: number,
  activityItems: PotActivityItem[],
): CalculationBreakdown {
  const activityNetPence = activityItems.reduce((total, item) => total + item.amountPence, 0)
  const startingOrImportedPence = balancePence - activityNetPence

  return {
    formula: 'Pot balance = starting/imported balance + recorded activity shown below.',
    lines: [
      {
        label: 'Starting or imported balance',
        value: formatPence(startingOrImportedPence),
        detail: `Balance not represented by the visible activity for this pot (${potId}).`,
        tone: startingOrImportedPence >= 0 ? 'add' : 'subtract',
      },
      ...activityItems.map((item) => ({
        label: item.title,
        value: formatSignedPence(item.amountPence),
        detail: item.detail,
        tone: item.amountPence >= 0 ? ('add' as const) : ('subtract' as const),
      })),
      {
        label: 'Current pot balance',
        value: formatPence(balancePence),
        tone: 'result',
      },
    ],
    note: 'This explains the displayed balance using the pot record plus the activity currently stored for it.',
  }
}

function transactionToActivityItem(transaction: Transaction): PotActivityItem {
  const isSpending = transaction.type === 'spending'

  return {
    id: `transaction-${transaction.id}`,
    title: transaction.note,
    detail: `${transaction.recurringPaymentId ? 'Recurring payment' : formatTransactionType(transaction.type)} · ${transaction.date}`,
    amountPence: isSpending ? -transaction.amountPence : transaction.amountPence,
  }
}

function allocationToActivityItem(allocation: PotAllocation, snapshot: PlannerSnapshot): PotActivityItem {
  const period = snapshot.payPeriods.find((candidate) => candidate.id === allocation.payPeriodId)
  const payment = allocation.recurringPaymentId
    ? snapshot.recurringPayments.find((candidate) => candidate.id === allocation.recurringPaymentId)
    : null

  return {
    id: `allocation-${allocation.id}`,
    title: payment
      ? `Reserved for ${payment.name}`
      : allocation.source === 'pot_auto'
        ? 'Automatic payday top-up'
        : 'Paycheck allocation',
    detail: `Allocation · ${period?.payday ?? allocation.createdAt.slice(0, 10)}`,
    amountPence: allocation.amountPence,
  }
}

function getPotCategoryOptions(pots: Pot[], customCategories: string[]): string[] {
  const categories = new Set<string>(builtinCategories)

  for (const pot of pots) {
    categories.add(getPotCategory(pot))
  }

  for (const category of customCategories) {
    const clean = cleanCategory(category)

    if (clean) {
      categories.add(clean)
    }
  }

  return Array.from(categories)
}

function isPotInCategory(pot: Pot, category: string): boolean {
  if (category === customCategoryAll) {
    return true
  }

  if (category === 'Spending') {
    return getPotCategory(pot) === 'Spending' || pot.type === 'spending'
  }

  if (category === 'Bills') {
    return getPotCategory(pot) === 'Bills' || pot.type === 'reserved'
  }

  if (category === 'Savings') {
    return getPotCategory(pot) === 'Savings' || pot.type === 'saving' || pot.type === 'investment' || pot.type === 'buffer'
  }

  return getPotCategory(pot).toLowerCase() === category.toLowerCase()
}

function getPotCategory(pot: Pot): string {
  return cleanCategory(pot.category ?? '') || defaultCategoryForPotType(pot.type)
}

function defaultCategoryForPotType(type: PotType): string {
  if (type === 'reserved') {
    return 'Bills'
  }

  if (type === 'saving' || type === 'investment' || type === 'buffer') {
    return 'Savings'
  }

  return 'Spending'
}

function isBuiltinPotCategory(category: string): boolean {
  return builtinCategories.some((builtin) => builtin.toLowerCase() === category.toLowerCase())
}

function cleanCategory(value: string): string {
  return value.trim().replace(/\s+/g, ' ').slice(0, 32)
}

function getPotIconOption(pot: Pot) {
  const key = getPotIconKey(pot)

  return iconOptions.find((option) => option.key === key) ?? iconOptions[0]
}

function getPotIconKey(pot: Pot): string {
  if (pot.icon && iconOptions.some((option) => option.key === pot.icon)) {
    return pot.icon
  }

  const name = pot.name.toLowerCase()

  if (/airbnb|rent|home|house/.test(name)) {
    return 'home'
  }

  if (/card|amex|capital|barclays|jaja|zable|credit/.test(name)) {
    return 'card'
  }

  if (/car|insurance|cover|tax/.test(name)) {
    return 'shield'
  }

  if (/fuel|petrol|diesel/.test(name)) {
    return 'fuel'
  }

  if (/gym|fitness/.test(name)) {
    return 'gym'
  }

  if (/food|grocery|groceries|lunch/.test(name)) {
    return 'food'
  }

  if (/saving|goal/.test(name)) {
    return 'savings'
  }

  return 'wallet'
}

function getEarliestRecurringDueDate(payments: RecurringPayment[], today: string): string | null {
  return payments.reduce<string | null>((earliest, payment) => {
    const dueDate = payment.dueDate ?? (payment.dueDay ? getNextDueDayIso(payment.dueDay, today) : null)

    return minIsoDate(earliest, dueDate)
  }, null)
}

function getCreditCardDueIso(card: PlannerSnapshot['creditCards'][number], today: string): string | null {
  return card.dueDate ?? (card.dueDay ? getNextDueDayIso(card.dueDay, today) : null)
}

function getNextDueDayIso(dueDay: number, todayIso: string): string {
  const today = new Date(`${todayIso}T00:00:00`)
  const candidate = new Date(today)
  candidate.setDate(Math.min(dueDay, getDaysInMonth(candidate)))

  if (candidate < today) {
    candidate.setMonth(candidate.getMonth() + 1)
    candidate.setDate(Math.min(dueDay, getDaysInMonth(candidate)))
  }

  return toIsoDate(candidate)
}

function getDaysInMonth(date: Date): number {
  return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate()
}

function minIsoDate(left: string | null, right: string | null): string | null {
  if (!left) {
    return right
  }

  if (!right) {
    return left
  }

  return right < left ? right : left
}

function getDaysUntil(isoDate: string, todayIso: string): number {
  const today = new Date(`${todayIso}T00:00:00`).getTime()
  const due = new Date(`${isoDate}T00:00:00`).getTime()

  return Math.ceil((due - today) / 86_400_000)
}

function withAlpha(color: string, alpha: number): string {
  const hex = color.replace('#', '')

  if (!/^[\da-f]{6}$/i.test(hex)) {
    return color
  }

  const red = parseInt(hex.slice(0, 2), 16)
  const green = parseInt(hex.slice(2, 4), 16)
  const blue = parseInt(hex.slice(4, 6), 16)

  return `rgba(${red}, ${green}, ${blue}, ${alpha})`
}

function formatTransactionType(type: Transaction['type']): string {
  if (type === 'spending') {
    return 'Spending'
  }

  return type.charAt(0).toUpperCase() + type.slice(1)
}

function formatSignedPence(amountPence: number): string {
  if (amountPence > 0) {
    return `+${formatPence(amountPence)}`
  }

  return formatPence(amountPence)
}
