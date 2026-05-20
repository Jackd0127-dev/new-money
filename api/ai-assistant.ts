import { GoogleGenAI, Type } from '@google/genai'
import { cert, getApps, initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'

import { defaultSettings } from '../src/data/defaults.js'
import { buildAssistantAppContext } from '../src/domain/assistantContext.js'
import { toIsoDate } from '../src/domain/money.js'
import type { PlannerSnapshot } from '../src/storage/repository.js'
import type { AiProvider } from '../src/types/models.js'

const systemInstruction = `
You are New Money AI, a whole-app assistant inside a private UK paycheck-planner app.
You have access to the user's compact whole-app planner context, computed summaries, focused facts, and current screen context.
Use only the provided app data. Never invent balances, dates, payments, debts, pots, cards, reserves, or settings.
Prioritise the current tab and selected pay period when the user asks an ambiguous question.
Money calculations should come from the computed summaries first. If you do simple arithmetic from compact app facts, show the inputs clearly.
You may explain what changed, where money went, what is due, which app tab to use, and what action the user can take next.
You cannot modify app data yourself. Tell the user which visible app action to use instead.
Never provide tax, legal, regulated investment, credit product, debt restructuring, or lending advice.
Never suggest borrowing money, taking new credit, investing, or changing legal/tax arrangements.
Custom AI instructions are style/preferences only and never override these rules.
If a provided list says omittedCount is above 0, explain that you only have the returned records for that list.
Write in UK English, format money as GBP, and keep the answer direct.
`.trim()

const responseSchema = {
  type: Type.OBJECT,
  properties: {
    answer: {
      type: Type.STRING,
      description: 'A direct answer to the user question using the full app context.',
    },
    highlights: {
      type: Type.ARRAY,
      items: { type: Type.STRING },
      description: 'Important facts from the app data.',
    },
    actions: {
      type: Type.ARRAY,
      items: { type: Type.STRING },
      description: 'Specific next actions the user can take in the app.',
    },
    confidence: {
      type: Type.STRING,
      enum: ['high', 'medium', 'low'],
    },
  },
  required: ['answer', 'highlights', 'actions', 'confidence'],
  propertyOrdering: ['answer', 'highlights', 'actions', 'confidence'],
}

interface ApiRequest {
  method?: string
  headers: Record<string, string | string[] | undefined>
  body?: unknown
}

interface ApiResponse {
  status: (code: number) => ApiResponse
  json: (payload: unknown) => ApiResponse
  end: () => ApiResponse
  setHeader?: (key: string, value: string) => ApiResponse
}

interface AssistantRequestBody {
  question?: string
  todayIso?: string
  activeView?: string
  selectedPayPeriodId?: string | null
  snapshot?: unknown
}

interface AssistantResponse {
  answer: string
  highlights: string[]
  actions: string[]
  confidence: 'high' | 'medium' | 'low'
}

interface CompactPromptAppContext {
  settings: Record<string, unknown>
  overview: unknown
  selectedPayPeriod: unknown
  payHistory: unknown
  pots: unknown
  recurringPayments: unknown
  payPeriods: unknown
  potAllocations: unknown
  transactions: unknown
  debts: unknown
  debtPayments: unknown
  debtReserves: unknown
  creditCards: unknown
  customPayments: unknown
  creditCardRepayments: unknown
  dailyBriefs: unknown
}

export default async function handler(req: ApiRequest, res: ApiResponse) {
  if (req.method !== 'POST') {
    res.setHeader?.('Allow', 'POST')
    return res.status(405).json({ error: 'Method not allowed' })
  }

  const idToken = getBearerToken(req.headers.authorization)

  if (!idToken) {
    return res.status(401).json({ error: 'Missing Firebase ID token' })
  }

  const body = parseBody(req.body)
  const todayIso = body.todayIso ?? toIsoDate(new Date())

  try {
    initializeFirebaseAdmin()
    await getAuth().verifyIdToken(idToken)
  } catch (error) {
    return res.status(500).json({
      error: error instanceof Error ? error.message : 'Unable to verify assistant access',
    })
  }

  const snapshot = normalizePlannerSnapshot(body.snapshot)
  const context = buildAssistantAppContext({
    snapshot,
    activeView: body.activeView,
    selectedPayPeriodId: body.selectedPayPeriodId ?? null,
    todayIso,
  })
  const prompt = buildPrompt({
    question: body.question ?? '',
    customInstructions: snapshot.settings.aiInstructions,
    context,
  })
  const provider = snapshot.settings.aiProvider

  if (provider === 'openrouter') {
    const openRouterApiKey = process.env.OPENROUTER_API_KEY

    if (!openRouterApiKey) {
      return res.status(503).json(createAiProviderError('openrouter', 'OpenRouter API key is not configured.'))
    }

    try {
      return res.status(200).json(
        parseAssistantResponse(
          await generateOpenRouterJson({
            apiKey: openRouterApiKey,
            systemInstruction,
            prompt,
          }),
        ),
      )
    } catch (error) {
      logAiProviderError(provider, error)
      return res.status(502).json(createAiProviderError(provider, getErrorMessage(error)))
    }
  }

  const geminiApiKey = process.env.GEMINI_API_KEY

  if (!geminiApiKey) {
    return res.status(503).json(createAiProviderError('gemini', 'Gemini API key is not configured.'))
  }

  try {
    const ai = new GoogleGenAI({ apiKey: geminiApiKey })
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: prompt,
      config: {
        systemInstruction,
        responseMimeType: 'application/json',
        responseSchema,
      },
    })

    return res.status(200).json(parseAssistantResponse(extractGeminiText(response)))
  } catch (error) {
    logAiProviderError(provider, error)
    return res.status(502).json(createAiProviderError(provider, getErrorMessage(error)))
  }
}

async function generateOpenRouterJson({
  apiKey,
  systemInstruction,
  prompt,
}: {
  apiKey: string
  systemInstruction: string
  prompt: string
}): Promise<string> {
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://money.scriptai.space',
      'X-OpenRouter-Title': 'New Money',
    },
    body: JSON.stringify({
      model: 'openai/gpt-oss-120b:free',
      messages: [
        { role: 'system', content: systemInstruction },
        { role: 'user', content: prompt },
      ],
    }),
  })

  if (!response.ok) {
    throw new Error(`OpenRouter request failed with ${response.status}: ${await response.text()}`)
  }

  const body = (await response.json()) as {
    choices?: Array<{ message?: { content?: unknown } }>
  }
  const content = body.choices?.[0]?.message?.content

  if (typeof content !== 'string' || !content.trim()) {
    throw new Error('OpenRouter returned an empty assistant response.')
  }

  return content.trim()
}

function buildPrompt({
  question,
  customInstructions,
  context,
}: {
  question: string
  customInstructions: string
  context: ReturnType<typeof buildAssistantAppContext>
}): string {
  const promptContext = buildCompactPromptContext(context, question)

  return [
    'Return only valid JSON with exactly these keys: answer, highlights, actions, confidence.',
    'Required JSON example: {"answer":"Direct answer","highlights":["Fact from app data"],"actions":["Visible app action"],"confidence":"high"}',
    'highlights and actions must be arrays of strings. confidence must be one of high, medium, or low.',
    customInstructions ? `User custom instructions:\n${truncateText(customInstructions, 2000)}` : '',
    `User question:\n${question || 'Give the most useful answer for the current app screen.'}`,
    `Current screen context JSON:\n${JSON.stringify(promptContext.screen)}`,
    `Computed app summaries JSON:\n${JSON.stringify(promptContext.computedSummaries)}`,
    `Compact app context JSON:\n${JSON.stringify(promptContext.compactAppContext)}`,
    `Focused app facts JSON:\n${JSON.stringify(promptContext.focusedFacts)}`,
  ].filter(Boolean).join('\n\n')
}

function buildCompactPromptContext(context: ReturnType<typeof buildAssistantAppContext>, question: string) {
  const snapshot = context.snapshot
  const lookups = buildLookups(snapshot)
  const compactAppContext: CompactPromptAppContext = {
    settings: {
      currency: snapshot.settings.currency,
      payFrequency: snapshot.settings.payFrequency,
      defaultPayPeriodDays: snapshot.settings.defaultPayPeriodDays,
      hourlyRatePence: snapshot.settings.hourlyRatePence,
      defaultHoursWorked: snapshot.settings.defaultHoursWorked,
      aiProvider: snapshot.settings.aiProvider,
      hasCustomAiInstructions: Boolean(snapshot.settings.aiInstructions.trim()),
    },
    overview: context.overview,
    selectedPayPeriod: compactPayPeriod(context.screen.selectedPayPeriod),
    payHistory: limitList(buildPayHistory(snapshot), 500, (item) => item),
    pots: limitList(snapshot.pots, 200, compactPot),
    recurringPayments: limitList(snapshot.recurringPayments, 250, (payment) => compactRecurringPayment(payment, lookups)),
    payPeriods: limitList(sortByDate(snapshot.payPeriods, 'payday'), 500, compactPayPeriod),
    potAllocations: limitList(snapshot.potAllocations, 500, (allocation) => compactPotAllocation(allocation, lookups)),
    transactions: limitList(sortByDate(snapshot.transactions, 'date', 'desc'), 350, (transaction) =>
      compactTransaction(transaction, lookups),
    ),
    debts: limitList(sortByDate(snapshot.debts, 'dueDate'), 200, compactDebt),
    debtPayments: limitList(sortByDate(snapshot.debtPayments, 'date', 'desc'), 350, (payment) =>
      compactDebtPayment(payment, lookups),
    ),
    debtReserves: limitList(sortByDate(snapshot.debtReserves, 'payday'), 350, (reserve) =>
      compactDebtReserve(reserve, lookups),
    ),
    creditCards: limitList(snapshot.creditCards, 100, compactCreditCard),
    customPayments: limitList(sortByDate(snapshot.customPayments, 'dueDate'), 250, (payment) =>
      compactCustomPayment(payment, lookups),
    ),
    creditCardRepayments: limitList(sortByDate(snapshot.creditCardRepayments, 'date', 'desc'), 250, (repayment) =>
      compactCreditCardRepayment(repayment, lookups),
    ),
    dailyBriefs: limitList(sortByDate(snapshot.dailyBriefs, 'date', 'desc'), 40, compactDailyBrief),
  }

  return {
    screen: {
      ...context.screen,
      selectedPayPeriod: compactPayPeriod(context.screen.selectedPayPeriod),
    },
    computedSummaries: compactComputedSummaries(context, lookups),
    compactAppContext,
    focusedFacts: buildFocusedFacts(context, question, compactAppContext, lookups),
  }
}

function compactComputedSummaries(context: ReturnType<typeof buildAssistantAppContext>, lookups: ReturnType<typeof buildLookups>) {
  return {
    overview: context.overview,
    summaries: {
      dashboard: {
        ...context.summaries.dashboard,
        items: limitList(context.summaries.dashboard.items, 120, (item) => ({
          ...item,
          label: truncateText(item.label, 140),
          potName: getLookupName(lookups.pots, item.potId),
          creditCardName: getLookupName(lookups.creditCards, item.creditCardId),
        })),
      },
      debts: context.summaries.debts,
      creditCards: {
        ...context.summaries.creditCards,
        cards: limitList(context.summaries.creditCards.cards, 80, (card) => ({
          ...card,
          card: compactCreditCard(card.card),
          items: limitList(card.items, 80, (item) => ({
            ...item,
            label: truncateText(item.label, 140),
            potName: getLookupName(lookups.pots, item.potId),
          })),
        })),
        unlinkedItems: limitList(context.summaries.creditCards.unlinkedItems, 80, (item) => ({
          ...item,
          label: truncateText(item.label, 140),
          potName: getLookupName(lookups.pots, item.potId),
        })),
      },
      debtPlans: limitList(context.summaries.debtPlans, 80, (plan) => ({
        ...plan,
        debt: compactDebt(plan.debt),
        schedule: limitList(plan.schedule, 80, (item) => item),
      })),
    },
  }
}

function buildFocusedFacts(
  context: ReturnType<typeof buildAssistantAppContext>,
  question: string,
  compactAppContext: CompactPromptAppContext,
  lookups: ReturnType<typeof buildLookups>,
) {
  const query = question.toLowerCase()
  const activeView = context.screen.activeView
  const selectedPeriod = context.screen.selectedPayPeriod
  const facts: Record<string, unknown> = {
    currentTab: context.screen.activeViewLabel,
    todayIso: context.screen.todayIso,
    selectedPayPeriod: compactPayPeriod(selectedPeriod),
  }

  if (activeView === 'history' || activeView === 'payday' || /pay\s*che?cks?|payday|wages?|salary|received|history/.test(query)) {
    facts.payHistory = compactAppContext.payHistory
  }

  if (activeView === 'dashboard' || /dashboard|left|cost|total|pay period|money/.test(query)) {
    facts.dashboard = compactComputedSummaries(context, lookups).summaries.dashboard
  }

  if (activeView === 'spending' || /spend|transaction|manual|purchase/.test(query)) {
    const transactions = selectedPeriod
      ? context.snapshot.transactions.filter(
          (transaction) => transaction.date >= selectedPeriod.startDate && transaction.date <= selectedPeriod.endDate,
        )
      : context.snapshot.transactions

    facts.transactionsForSelectedPeriod = limitList(sortByDate(transactions, 'date', 'desc'), 250, (transaction) =>
      compactTransaction(transaction, lookups),
    )
  }

  if (activeView === 'debts' || activeView === 'aiPlan' || /debt|reserve|owe|owed|payment plan/.test(query)) {
    facts.debts = compactAppContext.debts
    facts.debtPayments = compactAppContext.debtPayments
    facts.debtReserves = compactAppContext.debtReserves
    facts.debtPlans = compactComputedSummaries(context, lookups).summaries.debtPlans
  }

  if (activeView === 'pots' || /pot|saving|balance/.test(query)) {
    facts.pots = compactAppContext.pots
    facts.potAllocations = compactAppContext.potAllocations
  }

  if (activeView === 'allocatingPayments' || /card|credit|repayment|allocation/.test(query)) {
    facts.creditCards = compactAppContext.creditCards
    facts.customPayments = compactAppContext.customPayments
    facts.creditCardRepayments = compactAppContext.creditCardRepayments
    facts.creditCardSummary = compactComputedSummaries(context, lookups).summaries.creditCards
  }

  if (activeView === 'recurring' || activeView === 'calendar' || /recurring|subscription|due|calendar|bill/.test(query)) {
    facts.recurringPayments = compactAppContext.recurringPayments
    facts.customPayments = compactAppContext.customPayments
    facts.debtDueDates = compactAppContext.debts
  }

  if (activeView === 'settings' || /setting|instruction|provider|ai/.test(query)) {
    facts.settings = compactAppContext.settings
  }

  return facts
}

function buildLookups(snapshot: PlannerSnapshot) {
  return {
    pots: new Map(snapshot.pots.map((pot) => [pot.id, pot.name])),
    creditCards: new Map(snapshot.creditCards.map((card) => [card.id, card.name])),
    debts: new Map(snapshot.debts.map((debt) => [debt.id, debt.name])),
    payPeriods: new Map(snapshot.payPeriods.map((period) => [period.id, period.payday])),
  }
}

function buildPayHistory(snapshot: PlannerSnapshot) {
  const paychecksByPeriod = new Map(snapshot.paychecks.map((paycheck) => [paycheck.payPeriodId, paycheck]))
  const periodIds = new Set(snapshot.payPeriods.map((period) => period.id))
  const rows = sortByDate(snapshot.payPeriods, 'payday').map((period) => {
    const paycheck = paychecksByPeriod.get(period.id) ?? null
    const receivedAmountPence = paycheck?.actualAmountPence ?? period.incomePence ?? paycheck?.calculatedAmountPence ?? 0

    return {
      payPeriodId: period.id,
      paycheckId: paycheck?.id ?? null,
      payday: period.payday,
      periodStartDate: period.startDate,
      periodEndDate: period.endDate,
      nextPayday: period.nextPayday,
      payFrequency: period.payFrequency ?? snapshot.settings.payFrequency,
      status: period.status,
      incomePence: period.incomePence,
      hoursWorked: paycheck?.hoursWorked ?? null,
      hourlyRatePence: paycheck?.hourlyRatePence ?? null,
      calculatedAmountPence: paycheck?.calculatedAmountPence ?? null,
      actualAmountPence: paycheck?.actualAmountPence ?? null,
      receivedAmountPence,
      receivedAmountSource: paycheck?.actualAmountPence != null
        ? 'actualPaycheck'
        : paycheck
          ? 'recordedPaycheckEstimate'
          : 'payPeriodIncome',
    }
  })
  const orphanPaychecks = snapshot.paychecks
    .filter((paycheck) => !periodIds.has(paycheck.payPeriodId))
    .map((paycheck) => ({
      payPeriodId: paycheck.payPeriodId,
      paycheckId: paycheck.id,
      payday: null,
      periodStartDate: null,
      periodEndDate: null,
      nextPayday: null,
      payFrequency: snapshot.settings.payFrequency,
      status: 'unknown',
      incomePence: null,
      hoursWorked: paycheck.hoursWorked,
      hourlyRatePence: paycheck.hourlyRatePence,
      calculatedAmountPence: paycheck.calculatedAmountPence,
      actualAmountPence: paycheck.actualAmountPence,
      receivedAmountPence: paycheck.actualAmountPence ?? paycheck.calculatedAmountPence,
      receivedAmountSource: paycheck.actualAmountPence != null ? 'actualPaycheck' : 'recordedPaycheckEstimate',
    }))

  return [...rows, ...orphanPaychecks]
}

function compactPayPeriod(period: PlannerSnapshot['payPeriods'][number] | null) {
  if (!period) {
    return null
  }

  return {
    id: period.id,
    startDate: period.startDate,
    endDate: period.endDate,
    payday: period.payday,
    nextPayday: period.nextPayday,
    payFrequency: period.payFrequency,
    incomePence: period.incomePence,
    status: period.status,
  }
}

function compactPot(pot: PlannerSnapshot['pots'][number]) {
  return {
    id: pot.id,
    name: truncateText(pot.name, 120),
    type: pot.type,
    balancePence: pot.balancePence,
    targetPence: pot.targetPence,
    color: pot.color,
    archived: pot.archived,
  }
}

function compactRecurringPayment(payment: PlannerSnapshot['recurringPayments'][number], lookups: ReturnType<typeof buildLookups>) {
  return {
    id: payment.id,
    name: truncateText(payment.name, 140),
    amountPence: payment.amountPence,
    dueDay: payment.dueDay,
    dueDate: payment.dueDate,
    frequency: payment.frequency,
    potId: payment.potId,
    potName: getLookupName(lookups.pots, payment.potId),
    creditCardId: payment.creditCardId ?? null,
    creditCardName: getLookupName(lookups.creditCards, payment.creditCardId),
    priority: payment.priority,
    active: payment.active,
  }
}

function compactPotAllocation(allocation: PlannerSnapshot['potAllocations'][number], lookups: ReturnType<typeof buildLookups>) {
  return {
    id: allocation.id,
    payPeriodId: allocation.payPeriodId,
    payday: getLookupName(lookups.payPeriods, allocation.payPeriodId),
    potId: allocation.potId,
    potName: getLookupName(lookups.pots, allocation.potId),
    amountPence: allocation.amountPence,
    source: allocation.source,
    recurringPaymentId: allocation.recurringPaymentId ?? null,
  }
}

function compactTransaction(transaction: PlannerSnapshot['transactions'][number], lookups: ReturnType<typeof buildLookups>) {
  return {
    id: transaction.id,
    potId: transaction.potId ?? null,
    potName: getLookupName(lookups.pots, transaction.potId),
    payPeriodId: transaction.payPeriodId ?? null,
    payday: getLookupName(lookups.payPeriods, transaction.payPeriodId),
    amountPence: transaction.amountPence,
    type: transaction.type,
    paymentMethod: transaction.paymentMethod,
    creditCardId: transaction.creditCardId ?? null,
    creditCardName: getLookupName(lookups.creditCards, transaction.creditCardId),
    date: transaction.date,
    note: truncateText(transaction.note, 180),
  }
}

function compactDebt(debt: PlannerSnapshot['debts'][number]) {
  return {
    id: debt.id,
    name: truncateText(debt.name, 140),
    lender: truncateText(debt.lender, 140),
    originalAmountPence: debt.originalAmountPence,
    currentBalancePence: debt.currentBalancePence,
    minimumPaymentPence: debt.minimumPaymentPence,
    dueDate: debt.dueDate,
    interestRateApr: debt.interestRateApr,
    note: truncateText(debt.note, 220),
    status: debt.status,
  }
}

function compactDebtPayment(payment: PlannerSnapshot['debtPayments'][number], lookups: ReturnType<typeof buildLookups>) {
  return {
    id: payment.id,
    debtId: payment.debtId,
    debtName: getLookupName(lookups.debts, payment.debtId),
    amountPence: payment.amountPence,
    date: payment.date,
    note: truncateText(payment.note, 180),
  }
}

function compactDebtReserve(reserve: PlannerSnapshot['debtReserves'][number], lookups: ReturnType<typeof buildLookups>) {
  return {
    id: reserve.id,
    debtId: reserve.debtId,
    debtName: getLookupName(lookups.debts, reserve.debtId),
    payPeriodId: reserve.payPeriodId,
    payday: reserve.payday,
    periodStartDate: reserve.periodStartDate,
    periodEndDate: reserve.periodEndDate,
    amountPence: reserve.amountPence,
    status: reserve.status,
    source: reserve.source,
    note: truncateText(reserve.note, 180),
  }
}

function compactCreditCard(card: PlannerSnapshot['creditCards'][number]) {
  return {
    id: card.id,
    name: truncateText(card.name, 120),
    provider: truncateText(card.provider, 120),
    limitPence: card.limitPence,
    dueDay: card.dueDay,
    dueDate: card.dueDate,
    color: card.color,
    archived: card.archived,
  }
}

function compactCustomPayment(payment: PlannerSnapshot['customPayments'][number], lookups: ReturnType<typeof buildLookups>) {
  return {
    id: payment.id,
    name: truncateText(payment.name, 140),
    amountPence: payment.amountPence,
    dueDate: payment.dueDate,
    creditCardId: payment.creditCardId ?? null,
    creditCardName: getLookupName(lookups.creditCards, payment.creditCardId),
    status: payment.status,
  }
}

function compactCreditCardRepayment(
  repayment: PlannerSnapshot['creditCardRepayments'][number],
  lookups: ReturnType<typeof buildLookups>,
) {
  return {
    id: repayment.id,
    creditCardId: repayment.creditCardId,
    creditCardName: getLookupName(lookups.creditCards, repayment.creditCardId),
    amountPence: repayment.amountPence,
    date: repayment.date,
    note: truncateText(repayment.note, 180),
  }
}

function compactDailyBrief(brief: PlannerSnapshot['dailyBriefs'][number]) {
  return {
    id: brief.id,
    date: brief.date,
    snapshotSignature: brief.snapshotSignature,
    contentLength: brief.content.length,
  }
}

function limitList<T, U>(items: T[], limit: number, mapper: (item: T) => U) {
  const safeLimit = Math.max(0, limit)
  const limitedItems = items.slice(0, safeLimit).map(mapper)

  return {
    totalCount: items.length,
    returnedCount: limitedItems.length,
    omittedCount: Math.max(0, items.length - limitedItems.length),
    items: limitedItems,
  }
}

function sortByDate<T, K extends keyof T>(items: T[], key: K, direction: 'asc' | 'desc' = 'asc'): T[] {
  const multiplier = direction === 'asc' ? 1 : -1

  return [...items].sort((a, b) => String(a[key] ?? '').localeCompare(String(b[key] ?? '')) * multiplier)
}

function getLookupName(lookup: Map<string, string>, id: string | null | undefined): string | null {
  if (!id) {
    return null
  }

  return lookup.get(id) ?? null
}

function truncateText(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value
  }

  return `${value.slice(0, Math.max(0, maxLength - 1)).trimEnd()}…`
}

function createAiProviderError(provider: AiProvider, reason: string) {
  return {
    error: 'AI provider failed',
    provider,
    reason,
  }
}

function parseAssistantResponse(value: string): AssistantResponse {
  const parsed = JSON.parse(extractJsonObjectText(value)) as unknown

  if (!parsed || typeof parsed !== 'object') {
    throw new Error('Assistant returned a non-object JSON response.')
  }

  const response = parsed as Record<string, unknown>
  const answer = getFirstString(response, ['answer', 'response', 'message', 'summary'])

  if (!answer) {
    throw new Error('Assistant returned an invalid JSON shape.')
  }

  return {
    answer: answer.trim(),
    highlights: normalizeStringList(response.highlights),
    actions: normalizeStringList(response.actions),
    confidence: normalizeConfidence(response.confidence),
  }
}

function extractJsonObjectText(value: string): string {
  const trimmed = value.trim()

  if (!trimmed) {
    throw new Error('Assistant returned empty JSON.')
  }

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i)
  const candidate = (fenced?.[1] ?? trimmed).trim()
  const start = candidate.indexOf('{')
  const end = candidate.lastIndexOf('}')

  if (start < 0 || end < start) {
    throw new Error('Assistant returned invalid JSON.')
  }

  return candidate.slice(start, end + 1)
}

function normalizePlannerSnapshot(snapshot: unknown): PlannerSnapshot {
  const input = snapshot && typeof snapshot === 'object' ? snapshot as Partial<PlannerSnapshot> : {}

  return {
    settings: {
      ...defaultSettings,
      ...input.settings,
      aiInstructions: input.settings?.aiInstructions ?? defaultSettings.aiInstructions,
      aiProvider: normalizeAiProvider(input.settings?.aiProvider),
    },
    pots: input.pots ?? [],
    recurringPayments: input.recurringPayments ?? [],
    payPeriods: input.payPeriods ?? [],
    paychecks: input.paychecks ?? [],
    potAllocations: input.potAllocations ?? [],
    transactions: input.transactions ?? [],
    debts: input.debts ?? [],
    debtPayments: input.debtPayments ?? [],
    debtReserves: input.debtReserves ?? [],
    creditCards: input.creditCards ?? [],
    customPayments: input.customPayments ?? [],
    creditCardRepayments: input.creditCardRepayments ?? [],
    dailyBriefs: input.dailyBriefs ?? [],
  }
}

function normalizeAiProvider(provider: unknown): AiProvider {
  return provider === 'openrouter' ? 'openrouter' : 'gemini'
}

function initializeFirebaseAdmin() {
  if (getApps().length > 0) {
    return
  }

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON

  if (!serviceAccountJson) {
    throw new Error('Firebase service account is not configured')
  }

  const serviceAccount = JSON.parse(serviceAccountJson) as Record<string, unknown>

  if (typeof serviceAccount.private_key === 'string') {
    serviceAccount.private_key = serviceAccount.private_key.replace(/\\n/g, '\n')
  }

  initializeApp({
    credential: cert(serviceAccount),
  })
}

function getBearerToken(value: string | string[] | undefined): string | null {
  const header = Array.isArray(value) ? value[0] : value

  if (!header?.startsWith('Bearer ')) {
    return null
  }

  return header.slice('Bearer '.length).trim() || null
}

function parseBody(body: unknown): AssistantRequestBody {
  if (typeof body === 'string') {
    try {
      return JSON.parse(body) as AssistantRequestBody
    } catch {
      return {}
    }
  }

  if (body && typeof body === 'object') {
    return body as AssistantRequestBody
  }

  return {}
}

function extractGeminiText(response: unknown): string {
  const text = (response as { text?: unknown }).text

  if (typeof text === 'string') {
    return text.trim()
  }

  if (typeof text === 'function') {
    return String(text()).trim()
  }

  return ''
}

function cleanList(items: string[]): string[] {
  return items.map(cleanListItem).filter(Boolean)
}

function cleanListItem(item: string): string {
  return item
    .replace(/^\s*[-*•]\s*/, '')
    .replace(/^\s*\d+[.)]\s*/, '')
    .trim()
}

function normalizeStringList(value: unknown): string[] {
  if (Array.isArray(value)) {
    return cleanList(value.filter((item): item is string => typeof item === 'string'))
  }

  if (typeof value === 'string') {
    return cleanList(value.split(/\r?\n/))
  }

  return []
}

function normalizeConfidence(value: unknown): AssistantResponse['confidence'] {
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase()

    if (normalized.includes('high')) {
      return 'high'
    }

    if (normalized.includes('medium')) {
      return 'medium'
    }

    if (normalized.includes('low')) {
      return 'low'
    }
  }

  if (typeof value === 'number') {
    if (value >= 0.75) {
      return 'high'
    }

    if (value >= 0.45) {
      return 'medium'
    }

    return 'low'
  }

  return 'medium'
}

function getFirstString(source: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = source[key]

    if (typeof value === 'string' && value.trim()) {
      return value
    }
  }

  return null
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unknown AI provider error.'
}

function logAiProviderError(provider: AiProvider, error: unknown) {
  console.error('AI assistant provider failed', {
    provider,
    reason: getErrorMessage(error),
  })
}
