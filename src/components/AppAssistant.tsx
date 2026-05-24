import { type FormEvent, useState } from 'react'
import { Loader2, Send, Sparkles, X } from 'lucide-react'
import { clsx } from 'clsx'

import {
  getAssistantActionDetails,
  getAssistantActionValidationError,
  normalizeAssistantActionProposals,
  runAssistantAction,
  type AssistantActionProposal,
  type AssistantActionStatus,
} from '../domain/assistantActions'
import { getViewLabel } from '../domain/assistantContext'
import { toIsoDate } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import type { PayPeriod } from '../types/models'
import type { ViewKey } from '../types/navigation'

type AppAssistantUser = {
  getIdToken: () => Promise<string>
} | null

interface AssistantConversationMessage {
  role: 'user' | 'assistant'
  content: string
}

interface AssistantResponse {
  answer: string
  highlights: string[]
  actions: string[]
  confidence: 'high' | 'medium' | 'low'
  proposedActions?: AssistantActionProposal[]
}

interface ChatMessage extends AssistantResponse {
  id: string
  role: 'user' | 'assistant'
}

export function AppAssistant({
  snapshot,
  activeView,
  selectedPayPeriod,
  actions,
  user,
}: {
  snapshot: PlannerSnapshot
  activeView: ViewKey
  selectedPayPeriod?: PayPeriod | null
  actions: PlannerActions
  user: AppAssistantUser
}) {
  const [isOpen, setIsOpen] = useState(false)
  const [draft, setDraft] = useState('')
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [isSending, setIsSending] = useState(false)
  const [actionStatuses, setActionStatuses] = useState<Record<string, AssistantActionStatus>>({})
  const todayIso = toIsoDate(new Date())
  const viewLabel = getViewLabel(activeView)

  async function confirmAssistantAction(action: AssistantActionProposal) {
    const validationError = getAssistantActionValidationError(action, snapshot)

    if (validationError) {
      setActionStatuses((current) => ({
        ...current,
        [action.id]: { state: 'error', error: validationError },
      }))
      return
    }

    setActionStatuses((current) => ({
      ...current,
      [action.id]: { state: 'running' },
    }))

    try {
      await runAssistantAction(action, actions)
      setActionStatuses((current) => ({
        ...current,
        [action.id]: { state: 'done' },
      }))
    } catch (error) {
      setActionStatuses((current) => ({
        ...current,
        [action.id]: {
          state: 'error',
          error: error instanceof Error ? error.message : 'Unable to run this action.',
        },
      }))
    }
  }

  function cancelAssistantAction(actionId: string) {
    setActionStatuses((current) => ({
      ...current,
      [actionId]: { state: 'cancelled' },
    }))
  }

  async function sendMessage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    const question = draft.trim()

    if (!question || isSending) {
      return
    }

    setDraft('')
    setMessages((current) => [
      ...current,
      createMessage({
        role: 'user',
        answer: question,
        highlights: [],
        actions: [],
        confidence: 'high',
        proposedActions: [],
      }),
    ])

    if (!user) {
      setMessages((current) => [
        ...current,
        createMessage({
          role: 'assistant',
          ...createUnavailableResponse(
            'Sign in from Settings to ask AI.',
            'Authentication is required before any planner data is sent to an AI provider.',
            'Sign in from Settings, then ask again so I can use your synced planner data.',
          ),
        }),
      ])
      return
    }

    setIsSending(true)

    try {
      const idToken = await user.getIdToken()
      const response = await fetch('/api/ai-assistant', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${idToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          question,
          todayIso,
          activeView,
          selectedPayPeriodId: selectedPayPeriod?.id ?? null,
          conversationHistory: createConversationHistory(messages),
          snapshot,
        }),
      })

      if (!response.ok) {
        throw new Error(await getAssistantErrorMessage(response))
      }

      const assistantResponse = (await response.json()) as AssistantResponse
      setMessages((current) => [...current, createMessage({ role: 'assistant', ...createVisibleAssistantResponse(assistantResponse) })])
    } catch (error) {
      setMessages((current) => [...current, createMessage({ role: 'assistant', ...createUnavailableResponse('AI provider failed.', error instanceof Error ? error.message : 'Unknown AI provider error.') })])
    } finally {
      setIsSending(false)
    }
  }

  if (!isOpen) {
    return (
      <button
        type="button"
        aria-label="Open AI helper"
        onClick={() => setIsOpen(true)}
        className="ai-assistant-trigger fixed bottom-5 right-5 z-40 inline-flex items-center gap-3 rounded-full border border-slate-800 bg-slate-950 px-4 py-3 text-sm font-semibold text-white shadow-2xl shadow-slate-900/25 transition hover:-translate-y-0.5 hover:bg-slate-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-950"
      >
        <span className="flex size-9 items-center justify-center rounded-full bg-white text-slate-950">
          <Sparkles size={18} />
        </span>
        <span className="hidden sm:inline">Ask AI</span>
      </button>
    )
  }

  return (
    <section
      role="dialog"
      aria-label="AI helper"
      className="fixed bottom-5 right-5 z-40 flex max-h-[min(720px,calc(100vh-2.5rem))] w-[min(430px,calc(100vw-2.5rem))] flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xl shadow-slate-900/20"
    >
      <div className="border-b border-slate-200 bg-slate-950 p-4 text-white">
        <div className="flex items-center justify-between gap-3">
          <p className="text-sm font-semibold">AI</p>
          <button
            type="button"
            aria-label="Close AI helper"
            onClick={() => setIsOpen(false)}
            className="rounded-md p-2 text-slate-300 transition hover:bg-white/10 hover:text-white"
          >
            <X size={18} />
          </button>
        </div>
      </div>

      <div className="min-h-0 flex-1 space-y-3 overflow-y-auto bg-slate-50 p-4">
        <div className="rounded-xl border border-slate-200 bg-white p-3 text-sm leading-6 text-slate-700">
          <p>I can access all of your payments and give you a detailed plan depending on your needs.</p>
        </div>

        {messages.map((message) => (
          <ChatBubble
            key={message.id}
            message={message}
            snapshot={snapshot}
            actionStatuses={actionStatuses}
            onConfirmAction={confirmAssistantAction}
            onCancelAction={cancelAssistantAction}
          />
        ))}

        {isSending && (
          <div className="flex items-center gap-2 rounded-xl border border-slate-200 bg-white p-3 text-sm text-slate-500">
            <Loader2 className="animate-spin" size={16} />
            Reading the whole planner...
          </div>
        )}
      </div>

      <form onSubmit={sendMessage} className="border-t border-slate-200 bg-white p-3">
        <label htmlFor="app-assistant-input" className="sr-only">
          Ask AI
        </label>
        <div className="flex items-end gap-2 rounded-xl border border-slate-200 bg-slate-50 p-2 shadow-inner shadow-slate-200/50 focus-within:border-slate-400 focus-within:ring-4 focus-within:ring-slate-100">
          <textarea
            id="app-assistant-input"
            aria-label="Ask AI"
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            rows={2}
            placeholder={`Ask about ${viewLabel.toLowerCase()}, costs, pots, debts...`}
            className="max-h-28 min-h-10 flex-1 resize-none bg-transparent px-2 py-2 text-sm leading-5 text-slate-950 outline-none placeholder:text-slate-400"
          />
          <button
            type="submit"
            aria-label="Send message"
            disabled={!draft.trim() || isSending}
            className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-slate-950 text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <Send size={17} />
          </button>
        </div>
      </form>
    </section>
  )
}

function ChatBubble({
  message,
  snapshot,
  actionStatuses,
  onConfirmAction,
  onCancelAction,
}: {
  message: ChatMessage
  snapshot: PlannerSnapshot
  actionStatuses: Record<string, AssistantActionStatus>
  onConfirmAction: (action: AssistantActionProposal) => void
  onCancelAction: (actionId: string) => void
}) {
  const isUser = message.role === 'user'

  return (
    <article className={clsx('flex', isUser ? 'justify-end' : 'justify-start')}>
      <div
        className={clsx(
          'max-w-[92%] rounded-2xl px-3.5 py-3 text-sm leading-6',
          isUser ? 'bg-slate-950 text-white' : 'border border-slate-200 bg-white text-slate-700',
        )}
      >
        <p className={clsx('whitespace-pre-wrap', isUser ? 'text-white' : 'text-slate-800')}>{message.answer}</p>
        {!isUser && message.proposedActions && message.proposedActions.length > 0 && (
          <div className="mt-3 space-y-2">
            {message.proposedActions.map((action) => (
              <AssistantActionCard
                key={action.id}
                action={action}
                snapshot={snapshot}
                status={actionStatuses[action.id] ?? { state: 'pending' }}
                onConfirm={() => onConfirmAction(action)}
                onCancel={() => onCancelAction(action.id)}
              />
            ))}
          </div>
        )}
      </div>
    </article>
  )
}

function AssistantActionCard({
  action,
  snapshot,
  status,
  onConfirm,
  onCancel,
}: {
  action: AssistantActionProposal
  snapshot: PlannerSnapshot
  status: AssistantActionStatus
  onConfirm: () => void
  onCancel: () => void
}) {
  const validationError = getAssistantActionValidationError(action, snapshot)
  const isTerminal = status.state === 'done' || status.state === 'cancelled'
  const isRunning = status.state === 'running'
  const details = getAssistantActionDetails(action, snapshot)

  return (
    <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-slate-800">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">Suggested action</p>
          <p className="mt-1 text-sm font-semibold text-slate-950">{action.label}</p>
        </div>
        {status.state === 'done' && (
          <span className="rounded-full bg-emerald-600 px-2 py-1 text-xs font-semibold text-white">Done</span>
        )}
        {status.state === 'cancelled' && (
          <span className="rounded-full bg-slate-200 px-2 py-1 text-xs font-semibold text-slate-700">Cancelled</span>
        )}
      </div>
      <ul className="mt-2 space-y-1">
        {details.map((detail) => (
          <li key={detail} className="text-xs leading-5 text-slate-600">
            {detail}
          </li>
        ))}
      </ul>
      {(validationError || status.error) && (
        <p className="mt-2 rounded-md bg-red-50 px-2 py-1.5 text-xs font-medium text-red-700">
          {status.error ?? validationError}
        </p>
      )}
      {!isTerminal && (
        <div className="mt-3 flex flex-wrap gap-2">
          <button
            type="button"
            onClick={onConfirm}
            disabled={Boolean(validationError) || isRunning}
            className="inline-flex min-h-8 items-center justify-center rounded-md bg-slate-950 px-3 text-xs font-semibold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {isRunning ? 'Running...' : 'Confirm action'}
          </button>
          <button
            type="button"
            onClick={onCancel}
            disabled={isRunning}
            className="inline-flex min-h-8 items-center justify-center rounded-md border border-slate-200 bg-white px-3 text-xs font-semibold text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Cancel
          </button>
        </div>
      )}
    </div>
  )
}

function createMessage(input: Omit<ChatMessage, 'id'>): ChatMessage {
  return {
    ...input,
    id: crypto.randomUUID(),
  }
}

function createUnavailableResponse(answer: string, reason: string, action = 'Check Settings, confirm you are signed in, and verify the selected AI provider has a working server key.'): AssistantResponse {
  return {
    answer: `${answer}\n\n${reason}\n\nWhat I’d do next: ${action}`,
    highlights: [reason],
    actions: [action],
    confidence: 'low',
    proposedActions: [],
  }
}

function createVisibleAssistantResponse(response: AssistantResponse): AssistantResponse {
  return {
    ...response,
    answer: ensureNextStepGuidance(response.answer, response.actions),
    proposedActions: normalizeAssistantActionProposals(response.proposedActions),
  }
}

function createConversationHistory(messages: ChatMessage[]): AssistantConversationMessage[] {
  return messages
    .filter((message) => message.answer.trim())
    .slice(-8)
    .map((message) => ({
      role: message.role,
      content: truncateConversationText(message.answer),
    }))
}

function truncateConversationText(value: string): string {
  const trimmed = value.trim()
  const maxLength = 1_500

  if (trimmed.length <= maxLength) {
    return trimmed
  }

  return `${trimmed.slice(0, maxLength - 1).trimEnd()}…`
}

function ensureNextStepGuidance(answer: string, actions: string[]): string {
  const trimmedAnswer = answer.trim()

  if (/what i['’]d do next|what to do next|next steps?|my advice|i recommend/i.test(trimmedAnswer)) {
    return trimmedAnswer
  }

  const nextStep = actions.find((action) => action.trim())?.trim()

  if (!nextStep) {
    return `${trimmedAnswer}\n\nWhat I’d do next: ask me a follow-up and I’ll help you decide the best move from the current planner data.`
  }

  return `${trimmedAnswer}\n\nWhat I’d do next: ${nextStep}`
}

async function getAssistantErrorMessage(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as {
      error?: unknown
      provider?: unknown
      reason?: unknown
    }
    const parts = [
      typeof body.error === 'string' ? body.error : `AI helper request failed with ${response.status}`,
      typeof body.provider === 'string' ? `Provider: ${body.provider}` : '',
      typeof body.reason === 'string' ? body.reason : '',
    ].filter(Boolean)

    return parts.join(' · ')
  } catch {
    return `AI helper request failed with ${response.status}`
  }
}
