import { beforeEach, describe, expect, it, vi } from 'vitest'

import handler from './ai-assistant'

const mocks = vi.hoisted(() => ({
  verifyIdToken: vi.fn(),
  generateContent: vi.fn(),
  initializeApp: vi.fn(),
  cert: vi.fn((value) => value),
}))

vi.mock('firebase-admin/app', () => ({
  cert: mocks.cert,
  getApps: () => [],
  initializeApp: mocks.initializeApp,
}))

vi.mock('firebase-admin/auth', () => ({
  getAuth: () => ({
    verifyIdToken: mocks.verifyIdToken,
  }),
}))

vi.mock('@google/genai', () => ({
  GoogleGenAI: vi.fn(function GoogleGenAI() {
    return {
      models: {
        generateContent: mocks.generateContent,
      },
    }
  }),
  Type: {
    ARRAY: 'ARRAY',
    OBJECT: 'OBJECT',
    STRING: 'STRING',
  },
}))

describe('AI assistant api', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.unstubAllEnvs()
    vi.stubEnv('GEMINI_API_KEY', 'gemini-key')
    vi.stubEnv(
      'FIREBASE_SERVICE_ACCOUNT_JSON',
      JSON.stringify({
        project_id: 'new-money',
        client_email: 'firebase-admin@example.com',
        private_key: '-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n',
      }),
    )
    mocks.verifyIdToken.mockResolvedValue({ uid: 'user-1' })
    mocks.generateContent.mockResolvedValue({
      text: JSON.stringify({
        answer: 'Food spending is visible from the Spending tab context.',
        highlights: ['Current tab: Spending', 'Food pot balance: £120.00'],
        actions: ['Open Spending to edit the logged transaction.'],
        confidence: 'high',
      }),
    })
  })

  it('rejects requests without a Firebase ID token', async () => {
    const response = createResponse()

    await handler(
      {
        method: 'POST',
        headers: {},
        body: {},
      },
      response,
    )

    expect(response.statusCode).toBe(401)
    expect(mocks.verifyIdToken).not.toHaveBeenCalled()
    expect(mocks.generateContent).not.toHaveBeenCalled()
  })

  it('sends compact app context, computed summaries, and current tab context to Gemini', async () => {
    const response = createResponse()

    await handler(
      {
        method: 'POST',
        headers: {
          authorization: 'Bearer firebase-token',
        },
        body: {
          question: 'What am I looking at and what changed?',
          todayIso: '2026-05-20',
          activeView: 'spending',
          selectedPayPeriodId: 'period-current',
          snapshot: createSnapshot(),
        },
      },
      response,
    )

    const request = mocks.generateContent.mock.calls[0][0] as {
      contents: string
      config: {
        systemInstruction: string
        responseMimeType: string
        responseSchema: unknown
      }
    }

    expect(request.config.systemInstruction).toContain('whole-app assistant')
    expect(request.config.responseMimeType).toBe('application/json')
    expect(request.contents).toContain('Current screen context JSON:')
    expect(request.contents).toContain('"activeView":"spending"')
    expect(request.contents).toContain('"activeViewLabel":"Spending"')
    expect(request.contents).toContain('Computed app summaries JSON:')
    expect(request.contents).toContain('"dashboard"')
    expect(request.contents).toContain('Compact app context JSON:')
    expect(request.contents).toContain('Focused app facts JSON:')
    expect(request.contents).not.toContain('Full planner snapshot JSON:')
    expect(request.contents).toContain('"Food"')
    expect(request.contents).toContain('"Lunch"')
    expect(request.contents).toContain('"contentLength"')
    expect(request.contents).not.toContain('"Saved generated brief"')
    expect(response.payload).toEqual({
      answer: 'Food spending is visible from the Spending tab context.',
      highlights: ['Current tab: Spending', 'Food pot balance: £120.00'],
      actions: ['Open Spending to edit the logged transaction.'],
      confidence: 'high',
    })
  })

  it('uses OpenRouter when the saved provider is OpenRouter', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({
        choices: [
          {
            message: {
              content: JSON.stringify({
                answer: 'OpenRouter has the same full app context.',
                highlights: ['Provider: OpenRouter'],
                actions: ['Review the dashboard period.'],
                confidence: 'medium',
              }),
            },
          },
        ],
      }),
    }))
    vi.stubGlobal('fetch', fetchMock)
    vi.stubEnv('OPENROUTER_API_KEY', 'openrouter-key')
    const response = createResponse()

    await handler(
      {
        method: 'POST',
        headers: {
          authorization: 'Bearer firebase-token',
        },
        body: {
          question: 'Use OpenRouter?',
          todayIso: '2026-05-20',
          activeView: 'dashboard',
          selectedPayPeriodId: 'period-current',
          snapshot: createSnapshot({
            settings: {
              ...createSnapshot().settings,
              aiProvider: 'openrouter',
            },
          }),
        },
      },
      response,
    )

    expect(mocks.generateContent).not.toHaveBeenCalled()
    expect(fetchMock).toHaveBeenCalledWith(
      'https://openrouter.ai/api/v1/chat/completions',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer openrouter-key',
        }),
      }),
    )
    const requestBody = JSON.parse(fetchMock.mock.calls[0][1].body as string) as {
      model: string
      messages: Array<{ role: string; content: string }>
      response_format?: unknown
    }
    expect(requestBody.model).toBe('openai/gpt-oss-120b:free')
    expect(requestBody.messages[0].content).toContain('whole-app assistant')
    expect(requestBody.messages[1].content).toContain('Compact app context JSON:')
    expect(requestBody.response_format).toBeUndefined()
    expect(response.payload).toEqual({
      answer: 'OpenRouter has the same full app context.',
      highlights: ['Provider: OpenRouter'],
      actions: ['Review the dashboard period.'],
      confidence: 'medium',
    })
  })

  it('compresses large app snapshots while preserving paycheck history for OpenRouter', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({
        choices: [
          {
            message: {
              content: JSON.stringify({
                answer: 'You have two recorded paychecks: 2 May and 16 May.',
                highlights: ['2 paychecks found.'],
                actions: ['Open History to review them.'],
                confidence: 'high',
              }),
            },
          },
        ],
      }),
    }))
    vi.stubGlobal('fetch', fetchMock)
    vi.stubEnv('OPENROUTER_API_KEY', 'openrouter-key')
    const response = createResponse()

    await handler(
      {
        method: 'POST',
        headers: {
          authorization: 'Bearer firebase-token',
        },
        body: {
          question: 'What paychecks have I received in total and when?',
          todayIso: '2026-05-20',
          activeView: 'history',
          snapshot: createSnapshot({
            settings: {
              ...createSnapshot().settings,
              aiProvider: 'openrouter',
            },
            payPeriods: [
              createPayPeriod({
                id: 'period-one',
                payday: '2026-05-02',
                startDate: '2026-05-02',
                endDate: '2026-05-15',
                nextPayday: '2026-05-16',
                incomePence: 80000,
              }),
              createPayPeriod({
                id: 'period-two',
                payday: '2026-05-16',
                startDate: '2026-05-16',
                endDate: '2026-05-29',
                nextPayday: '2026-05-30',
                incomePence: 85000,
              }),
            ],
            paychecks: [
              createPaycheck({
                id: 'paycheck-one',
                payPeriodId: 'period-one',
                calculatedAmountPence: 80000,
                actualAmountPence: 80500,
              }),
              createPaycheck({
                id: 'paycheck-two',
                payPeriodId: 'period-two',
                calculatedAmountPence: 85000,
                actualAmountPence: null,
              }),
            ],
            dailyBriefs: [
              {
                id: 'brief-huge',
                date: '2026-05-20',
                snapshotSignature: 'huge',
                content: 'x'.repeat(500_000),
                createdAt: '2026-05-20T00:00:00.000Z',
                updatedAt: '2026-05-20T00:00:00.000Z',
              },
            ],
          }),
        },
      },
      response,
    )

    const requestBody = JSON.parse(fetchMock.mock.calls[0][1].body as string) as {
      messages: Array<{ content: string }>
    }
    const prompt = requestBody.messages[1].content

    expect((fetchMock.mock.calls[0][1].body as string).length).toBeLessThan(100_000)
    expect(prompt).toContain('"payHistory"')
    expect(prompt).toContain('"payday":"2026-05-02"')
    expect(prompt).toContain('"receivedAmountPence":80500')
    expect(prompt).not.toContain('x'.repeat(1000))
    expect(response.statusCode).toBe(200)
  })

  it('returns an AI error instead of a deterministic local answer when the provider fails', async () => {
    mocks.generateContent.mockResolvedValueOnce({ text: 'not json' })
    const response = createResponse()

    await handler(
      {
        method: 'POST',
        headers: {
          authorization: 'Bearer firebase-token',
        },
        body: {
          question: 'Give me every paycheck I have received.',
          todayIso: '2026-05-20',
          activeView: 'history',
          snapshot: createSnapshot({
            payPeriods: [
              createPayPeriod({ id: 'period-one', payday: '2026-05-02', incomePence: 80000 }),
              createPayPeriod({ id: 'period-two', payday: '2026-05-16', incomePence: 85000 }),
            ],
          }),
        },
      },
      response,
    )

    expect(response.statusCode).toBe(502)
    expect(response.payload).toEqual({
      error: 'AI provider failed',
      provider: 'gemini',
      reason: 'Assistant returned invalid JSON.',
    })
    expect(JSON.stringify(response.payload)).not.toContain('I can see History')
    expect(JSON.stringify(response.payload)).not.toContain('Create or select a pay period')
  })

  it('accepts JSON wrapped in a markdown fence from OpenRouter', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({
        choices: [
          {
            message: {
              content: [
                '```json',
                JSON.stringify({
                  answer: 'Your paycheck history is available to the model.',
                  highlights: ['2 paychecks found.'],
                  actions: ['Open History for the table.'],
                  confidence: 'high',
                }),
                '```',
              ].join('\n'),
            },
          },
        ],
      }),
    }))
    vi.stubGlobal('fetch', fetchMock)
    vi.stubEnv('OPENROUTER_API_KEY', 'openrouter-key')
    const response = createResponse()

    await handler(
      {
        method: 'POST',
        headers: {
          authorization: 'Bearer firebase-token',
        },
        body: {
          question: 'Give me every paycheck.',
          todayIso: '2026-05-20',
          activeView: 'history',
          snapshot: createSnapshot({
            settings: {
              ...createSnapshot().settings,
              aiProvider: 'openrouter',
            },
          }),
        },
      },
      response,
    )

    expect(response.statusCode).toBe(200)
    expect(response.payload).toEqual({
      answer: 'Your paycheck history is available to the model.',
      highlights: ['2 paychecks found.'],
      actions: ['Open History for the table.'],
      confidence: 'high',
    })
  })
})

function createResponse() {
  return {
    statusCode: 200,
    payload: null as unknown,
    headers: {} as Record<string, string>,
    status(code: number) {
      this.statusCode = code
      return this
    },
    json(payload: unknown) {
      this.payload = payload
      return this
    },
    end() {
      return this
    },
    setHeader(key: string, value: string) {
      this.headers[key] = value
      return this
    },
  }
}

function createSnapshot(overrides: Record<string, unknown> = {}) {
  const timestamp = '2026-05-20T00:00:00.000Z'

  return {
    settings: {
      id: 'default',
      currency: 'GBP',
      payFrequency: 'biweekly',
      defaultPayPeriodDays: 14,
      hourlyRatePence: 1250,
      defaultHoursWorked: 72,
      aiInstructions: 'Answer directly.',
      aiProvider: 'gemini',
      createdAt: timestamp,
      updatedAt: timestamp,
    },
    pots: [
      {
        id: 'pot-food',
        name: 'Food',
        type: 'spending',
        balancePence: 12000,
        targetPence: null,
        color: '#16a34a',
        archived: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    ],
    recurringPayments: [
      {
        id: 'recurring-rent',
        name: 'Rent',
        amountPence: 50000,
        dueDay: 24,
        frequency: 'monthly',
        potId: 'pot-food',
        creditCardId: null,
        priority: 'essential',
        active: true,
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    ],
    payPeriods: [
      {
        id: 'period-current',
        startDate: '2026-05-16',
        endDate: '2026-05-29',
        payday: '2026-05-16',
        nextPayday: '2026-05-30',
        payFrequency: 'biweekly',
        incomePence: 90000,
        status: 'active',
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    ],
    paychecks: [],
    potAllocations: [],
    transactions: [
      {
        id: 'transaction-lunch',
        potId: 'pot-food',
        payPeriodId: 'period-current',
        amountPence: 1200,
        type: 'spending',
        paymentMethod: 'pot',
        creditCardId: null,
        date: '2026-05-20',
        note: 'Lunch',
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    ],
    debts: [],
    debtPayments: [],
    debtReserves: [],
    creditCards: [],
    customPayments: [],
    creditCardRepayments: [],
    dailyBriefs: [
      {
        id: 'brief-today',
        date: '2026-05-20',
        snapshotSignature: 'sig',
        content: 'Saved generated brief',
        createdAt: timestamp,
        updatedAt: timestamp,
      },
    ],
    ...overrides,
  }
}

function createPayPeriod(overrides: Record<string, unknown> = {}) {
  const timestamp = '2026-05-20T00:00:00.000Z'

  return {
    id: 'period-current',
    startDate: '2026-05-16',
    endDate: '2026-05-29',
    payday: '2026-05-16',
    nextPayday: '2026-05-30',
    payFrequency: 'biweekly',
    incomePence: 90000,
    status: 'active',
    createdAt: timestamp,
    updatedAt: timestamp,
    ...overrides,
  }
}

function createPaycheck(overrides: Record<string, unknown> = {}) {
  const timestamp = '2026-05-20T00:00:00.000Z'

  return {
    id: 'paycheck-current',
    payPeriodId: 'period-current',
    hoursWorked: 72,
    hourlyRatePence: 1250,
    calculatedAmountPence: 90000,
    actualAmountPence: null,
    createdAt: timestamp,
    updatedAt: timestamp,
    ...overrides,
  }
}
