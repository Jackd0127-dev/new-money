import { useState } from 'react'
import { Send, Sparkles } from 'lucide-react'

import { toIsoDate } from '../domain/money'
import type { PlannerSnapshot } from '../hooks/usePlannerData'
import { Button, Panel, TextArea } from '../components/ui'
import type { PayPeriod } from '../types/models'

type AiPlanUser = {
  getIdToken: () => Promise<string>
} | null

interface AiResponse {
  answer?: string
}

export function AiPlanPage({
  snapshot,
  selectedPayPeriod,
  user,
}: {
  snapshot: PlannerSnapshot
  selectedPayPeriod?: PayPeriod | null
  user: AiPlanUser
}) {
  const [question, setQuestion] = useState('')
  const [answer, setAnswer] = useState<string | null>(null)
  const [assistantError, setAssistantError] = useState<string | null>(null)
  const [isAsking, setIsAsking] = useState(false)
  const viewedPeriod = selectedPayPeriod ?? null

  async function askAssistant() {
    const trimmedQuestion = question.trim()

    if (!trimmedQuestion) {
      return
    }

    if (!user) {
      setAnswer(null)
      setAssistantError('Sign in from Settings to ask the AI.')
      return
    }

    setIsAsking(true)
    setAssistantError(null)

    try {
      const idToken = await user.getIdToken()
      const response = await fetch('/api/ai-planner', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${idToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          question: trimmedQuestion,
          todayIso: toIsoDate(new Date()),
          selectedPayPeriodId: viewedPeriod?.id ?? null,
          customInstructions: snapshot.settings.aiInstructions,
          snapshot: {
            ...snapshot,
            dailyBriefs: [],
          },
        }),
      })

      if (!response.ok) {
        throw new Error(`AI request failed with ${response.status}`)
      }

      const data = (await response.json()) as AiResponse
      setAnswer(data.answer?.trim() || 'The AI did not return an answer.')
    } catch (error) {
      setAnswer(null)
      setAssistantError(error instanceof Error ? error.message : 'Unable to ask the AI.')
    } finally {
      setIsAsking(false)
    }
  }

  return (
    <div className="space-y-6">
      <Panel
        title="Ask the AI"
        description="Ask anything about your pay, pots, cards, spending, bills, or next money move."
        accent="blue"
      >
        <div className="space-y-4">
          <TextArea
            aria-label="Ask the AI"
            value={question}
            onChange={(event) => setQuestion(event.target.value)}
            placeholder="Ask anything about your money..."
            className="min-h-[260px] resize-y text-base leading-7"
          />
          <div className="flex flex-wrap items-center gap-3">
            <Button onClick={askAssistant} disabled={!question.trim() || isAsking}>
              <Send size={16} />
              {isAsking ? 'Asking...' : 'Ask the AI'}
            </Button>
            {viewedPeriod && (
              <p className="text-sm text-slate-500">
                Using {viewedPeriod.startDate} to {viewedPeriod.endDate}
              </p>
            )}
          </div>
          {assistantError && (
            <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
              {assistantError}
            </p>
          )}
          {answer && (
            <div className="rounded-lg border border-slate-200 bg-slate-50 p-4">
              <div className="flex items-start gap-2">
                <Sparkles className="mt-0.5 shrink-0 text-slate-500" size={18} />
                <p className="whitespace-pre-wrap text-sm leading-6 text-slate-800">{answer}</p>
              </div>
            </div>
          )}
        </div>
      </Panel>
    </div>
  )
}
