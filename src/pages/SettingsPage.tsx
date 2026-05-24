import { useState } from 'react'
import { Apple, CheckCircle2, KeyRound, LogOut, Mail, ShieldAlert, Trash2 } from 'lucide-react'

import { parsePoundsToPence } from '../domain/money'
import type { PlannerActions, PlannerSnapshot } from '../hooks/usePlannerData'
import type { FirebaseAuthController } from '../hooks/useFirebaseAuth'
import { Button, Field, Panel, SectionGrid, SelectInput, TextArea, TextInput } from '../components/ui'
import type { AiProvider, PayFrequency } from '../types/models'

export function SettingsPage({
  snapshot,
  actions,
  auth,
}: {
  snapshot: PlannerSnapshot
  actions: PlannerActions
  auth?: FirebaseAuthController
}) {
  const [hourlyRate, setHourlyRate] = useState((snapshot.settings.hourlyRatePence / 100).toFixed(2))
  const [defaultHoursWorked, setDefaultHoursWorked] = useState(String(snapshot.settings.defaultHoursWorked))
  const [payFrequency, setPayFrequency] = useState<PayFrequency>(snapshot.settings.payFrequency)
  const [aiInstructions, setAiInstructions] = useState(snapshot.settings.aiInstructions)
  const [aiProvider, setAiProvider] = useState<AiProvider>(snapshot.settings.aiProvider)
  const [saved, setSaved] = useState(false)

  async function saveSettings() {
    await actions.updateSettings({
      defaultHoursWorked: Number.parseFloat(defaultHoursWorked) || 0,
      hourlyRatePence: parsePoundsToPence(hourlyRate),
      payFrequency,
      aiInstructions: aiInstructions.trim(),
      aiProvider,
    })
    setSaved(true)
  }

  return (
    <div className="space-y-6">
      <SectionGrid variant="balanced">
        <Panel title="Pay defaults" description="These defaults speed up each payday plan." accent="blue" density="compact">
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Currency">
                <TextInput value={snapshot.settings.currency} disabled />
              </Field>
              <Field label="Hourly rate">
                <TextInput
                  inputMode="decimal"
                  value={hourlyRate}
                  onChange={(event) => {
                    setHourlyRate(event.target.value)
                    setSaved(false)
                  }}
                />
              </Field>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Default hours worked">
                <TextInput
                  inputMode="decimal"
                  value={defaultHoursWorked}
                  onChange={(event) => {
                    setDefaultHoursWorked(event.target.value)
                    setSaved(false)
                  }}
                />
              </Field>
              <Field label="Pay frequency">
                <SelectInput
                  value={payFrequency}
                  onChange={(event) => {
                    setPayFrequency(event.target.value as PayFrequency)
                    setSaved(false)
                  }}
                >
                  <option value="weekly">Weekly</option>
                  <option value="biweekly">Biweekly</option>
                  <option value="monthly">Monthly</option>
                  <option value="custom">Custom</option>
                </SelectInput>
              </Field>
            </div>
            <Field
              label="AI provider"
              hint="Gemini stays as the default. OpenRouter uses openai/gpt-oss-120b:free on the server."
            >
              <SelectInput
                aria-label="AI provider"
                value={aiProvider}
                onChange={(event) => {
                  setAiProvider(event.target.value as AiProvider)
                  setSaved(false)
                }}
              >
                <option value="gemini">Gemini</option>
                <option value="openrouter">OpenRouter gpt-oss-120b</option>
              </SelectInput>
            </Field>
            <Field
              label="Custom AI instructions"
              hint="Used for tone and preferences only. The app still owns all money calculations."
            >
              <TextArea
                aria-label="Custom AI instructions"
                value={aiInstructions}
                onChange={(event) => {
                  setAiInstructions(event.target.value)
                  setSaved(false)
                }}
                placeholder="Example: be direct, prioritise debts due soon, keep answers short."
              />
            </Field>
            <div className="flex flex-wrap items-center gap-3">
              <Button onClick={saveSettings} disabled={saved}>
                Save settings
              </Button>
              {saved && (
                <span className="inline-flex items-center gap-2 text-sm font-medium text-emerald-700">
                  <CheckCircle2 size={18} />
                  Settings saved
                </span>
              )}
            </div>
          </div>
        </Panel>

        <AccountPanel auth={auth} />
      </SectionGrid>
    </div>
  )
}

function AccountPanel({ auth }: { auth?: FirebaseAuthController }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  async function signInWithEmail() {
    await auth?.signInWithEmail(email, password)
  }

  async function createEmailAccount() {
    await auth?.createEmailAccount(email, password)
  }

  const accountIdentifier = auth?.user?.email ?? auth?.user?.uid ?? (auth ? 'Not signed in' : 'Local planner')
  const providerLabel = getAuthProviderLabel(auth)
  const canUseAuth = Boolean(auth?.isConfigured)
  const isSignedIn = Boolean(auth?.user)

  return (
    <Panel title="Account" description="Manage sign-in and account actions." accent="cyan" density="compact">
      <div className="space-y-4">
        <div className="grid gap-3 sm:grid-cols-2">
          <AccountFact label="Account" value={accountIdentifier} />
          <AccountFact label="Sign-in provider" value={providerLabel} />
        </div>

        {auth?.isLoading && (
          <div className="rounded-lg border border-slate-200 bg-slate-50 p-3 text-sm text-slate-600">
            Checking account status.
          </div>
        )}

        {!canUseAuth && (
          <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm leading-5 text-amber-900">
            Sign-in is not configured for this build.
          </div>
        )}

        {auth && canUseAuth && !auth.isLoading && !auth.user && (
          <div className="space-y-4">
            <div className="grid gap-2 sm:grid-cols-2">
              <Button variant="secondary" onClick={auth.signInWithGoogle}>
                <Mail size={18} />
                Continue with Google
              </Button>
              <Button variant="secondary" disabled={!auth.isAppleEnabled} onClick={auth.signInWithApple}>
                <Apple size={18} />
                Continue with Apple
              </Button>
            </div>

            <div className="grid gap-3 md:grid-cols-[1fr_1fr_auto_auto]">
              <Field label="Email">
                <TextInput
                  autoComplete="email"
                  inputMode="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  placeholder="you@example.com"
                  type="email"
                />
              </Field>
              <Field label="Password">
                <TextInput
                  autoComplete="current-password"
                  minLength={6}
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  placeholder="6+ characters"
                  type="password"
                />
              </Field>
              <Button className="self-end" onClick={signInWithEmail} disabled={!email || password.length < 6}>
                <Mail size={18} />
                Sign in
              </Button>
              <Button
                className="self-end"
                variant="secondary"
                onClick={createEmailAccount}
                disabled={!email || password.length < 6}
              >
                Create
              </Button>
            </div>
          </div>
        )}

        {auth?.error && (
          <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm leading-5 text-red-700">
            {auth.error}
          </div>
        )}

        <div className="grid gap-2 sm:grid-cols-3">
          <Button variant="secondary" disabled title="Ready for password reset wiring">
            <KeyRound size={18} />
            Change password
          </Button>
          <Button variant="danger" disabled title="Ready for account deletion wiring">
            <Trash2 size={18} />
            Delete account
          </Button>
          <Button
            variant="secondary"
            disabled={!isSignedIn}
            onClick={() => {
              if (window.confirm('Log out on this device?')) {
                void auth?.signOut()
              }
            }}
          >
            <LogOut size={18} />
            Log out
          </Button>
        </div>

        <div className="flex items-start gap-2 rounded-lg bg-slate-50 p-3 text-xs leading-5 text-slate-500">
          <ShieldAlert className="mt-0.5 shrink-0" size={15} />
          <p>Change password and Delete account are placeholders ready for account-management wiring.</p>
        </div>
      </div>
    </Panel>
  )
}

function AccountFact({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 break-words text-sm font-semibold text-slate-950">{value}</p>
    </div>
  )
}

function getAuthProviderLabel(auth?: FirebaseAuthController): string {
  if (!auth?.isConfigured) {
    return 'Not configured'
  }

  const providerId = auth.user?.providerData[0]?.providerId

  if (!providerId) {
    return auth.user ? 'Email/password' : 'Not signed in'
  }

  if (providerId === 'google.com') {
    return 'Google'
  }

  if (providerId === 'apple.com') {
    return 'Apple'
  }

  if (providerId === 'password') {
    return 'Email/password'
  }

  return providerId
}
