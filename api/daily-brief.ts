import { GoogleGenAI } from '@google/genai'
import { cert, getApps, initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'

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

interface DailyBriefRequestBody {
  todayIso?: string
  snapshotSignature?: string
  snapshot?: unknown
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
  const geminiApiKey = process.env.GEMINI_API_KEY

  if (!geminiApiKey) {
    return res.status(500).json({ error: 'Gemini API key is not configured' })
  }

  try {
    initializeFirebaseAdmin()
    await getAuth().verifyIdToken(idToken)

    const ai = new GoogleGenAI({ apiKey: geminiApiKey })
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: buildPrompt(body),
    })
    const content = extractGeminiText(response)

    if (!content) {
      return res.status(502).json({ error: 'Gemini returned an empty daily brief' })
    }

    return res.status(200).json({ content })
  } catch (error) {
    return res.status(500).json({
      error: error instanceof Error ? error.message : 'Unable to generate daily brief',
    })
  }
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

function parseBody(body: unknown): DailyBriefRequestBody {
  if (typeof body === 'string') {
    try {
      return JSON.parse(body) as DailyBriefRequestBody
    } catch {
      return {}
    }
  }

  if (body && typeof body === 'object') {
    return body as DailyBriefRequestBody
  }

  return {}
}

function buildPrompt(body: DailyBriefRequestBody): string {
  return [
    'You are generating a concise daily money run-through for a private paycheck planner.',
    'Use the provided planner snapshot only. Do not provide tax, regulated investment, legal, or credit advice.',
    'Focus on: today pay/payment summary, credit card amounts owed, upcoming payment risks, and a short action checklist.',
    'Keep it practical, specific, and under 180 words. Use GBP formatting when money amounts are present.',
    `Local date: ${body.todayIso ?? 'unknown'}`,
    `Snapshot signature: ${body.snapshotSignature ?? 'unknown'}`,
    `Planner snapshot JSON: ${JSON.stringify(body.snapshot ?? {})}`,
  ].join('\n\n')
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
