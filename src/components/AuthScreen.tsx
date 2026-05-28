import { useState } from 'react'
import { Apple, Loader2, LockKeyhole, Mail, ShieldCheck } from 'lucide-react'

import type { FirebaseAuthController } from '../hooks/useFirebaseAuth'
import { Button, Field, TextInput } from './ui'

export function AuthScreen({ auth }: { auth: FirebaseAuthController }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [mode, setMode] = useState<'sign-in' | 'create'>('sign-in')
  const [busyAction, setBusyAction] = useState<'google' | 'apple' | 'email' | null>(null)
  const canSubmitEmail = email.trim().length > 0 && password.length >= 6 && busyAction === null

  async function runAuthAction(action: 'google' | 'apple' | 'email', callback: () => Promise<boolean>) {
    setBusyAction(action)

    try {
      await callback()
    } finally {
      setBusyAction(null)
    }
  }

  async function submitEmailAuth() {
    if (!canSubmitEmail) {
      return
    }

    await runAuthAction('email', () =>
      mode === 'sign-in'
        ? auth.signInWithEmail(email.trim(), password)
        : auth.createEmailAccount(email.trim(), password),
    )
  }

  return (
    <main className="flex min-h-dvh min-w-0 items-center justify-center overflow-x-hidden bg-[linear-gradient(180deg,#f8fbff_0%,#eef5f7_48%,#f7fafc_100%)] px-4 py-6 text-slate-950 sm:px-6">
      <section
        aria-label="Sign in to Money Manager"
        className="grid min-w-0 w-full max-w-5xl overflow-hidden rounded-2xl border border-slate-200/80 bg-white/95 shadow-[0_26px_80px_rgba(15,23,42,0.12)] backdrop-blur lg:grid-cols-[0.9fr_1.1fr]"
      >
        <div className="min-w-0 bg-[linear-gradient(180deg,#06122a_0%,#071a2d_56%,#06101f_100%)] px-5 py-7 text-white sm:px-8 sm:py-10">
          <div className="flex items-center gap-3">
            <div className="flex size-11 items-center justify-center rounded-xl bg-white p-2 text-slate-950 shadow-lg shadow-emerald-950/20">
              <img src="/favicon.svg" alt="" className="size-full" />
            </div>
            <div>
              <p className="text-sm font-semibold text-white">Money Manager</p>
              <p className="text-xs text-slate-300">Private paycheck planning</p>
            </div>
          </div>

          <div className="mt-10 max-w-sm">
            <h1 className="text-3xl font-semibold leading-tight tracking-normal sm:text-4xl">
              Sign in to open your planner.
            </h1>
            <p className="mt-4 text-sm leading-6 text-slate-300">
              This app is account-only. Your dashboard, pots, cards, and paycheck checklist stay hidden until you sign in.
            </p>
          </div>

          <div className="mt-10 grid gap-3 text-sm text-slate-200">
            <div className="flex items-start gap-3">
              <ShieldCheck className="mt-0.5 shrink-0 text-emerald-300" size={18} />
              <p>Cloud sync runs only after Firebase confirms your account.</p>
            </div>
            <div className="flex items-start gap-3">
              <LockKeyhole className="mt-0.5 shrink-0 text-cyan-300" size={18} />
              <p>Opening the app signed out always returns to this login screen.</p>
            </div>
          </div>
        </div>

        <div className="min-w-0 px-5 py-7 sm:px-8 sm:py-10">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-semibold text-slate-950">Account login</h2>
              <p className="mt-1 text-sm text-slate-500">
                Use your saved account to continue.
              </p>
            </div>
            {auth.isLoading && <Loader2 className="animate-spin text-slate-400" size={20} aria-label="Checking sign-in" />}
          </div>

          {!auth.isConfigured && (
            <div className="mt-5 rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm leading-5 text-amber-900">
              Sign-in is not configured for this deployment, so the planner cannot be opened.
            </div>
          )}

          {auth.isConfigured && (
            <div className="mt-6 space-y-5">
              <div className="grid gap-2 sm:grid-cols-2">
                <Button
                  className="w-full px-3"
                  variant="secondary"
                  disabled={busyAction !== null || auth.isLoading}
                  onClick={() => void runAuthAction('google', auth.signInWithGoogle)}
                >
                  {busyAction === 'google' ? <Loader2 className="animate-spin" size={18} /> : <Mail size={18} />}
                  Continue with Google
                </Button>
                <Button
                  className="w-full px-3"
                  variant="secondary"
                  disabled={busyAction !== null || auth.isLoading || !auth.isAppleEnabled}
                  onClick={() => void runAuthAction('apple', auth.signInWithApple)}
                >
                  {busyAction === 'apple' ? <Loader2 className="animate-spin" size={18} /> : <Apple size={18} />}
                  Continue with Apple
                </Button>
              </div>

              <div className="rounded-lg border border-slate-200/90 bg-slate-50/80 p-3 shadow-inner shadow-slate-200/50">
                <div className="grid gap-3">
                  <Field label="Email">
                    <TextInput
                      autoComplete="email"
                      inputMode="email"
                      value={email}
                      onChange={(event) => {
                        auth.clearError()
                        setEmail(event.target.value)
                      }}
                      placeholder="you@example.com"
                      type="email"
                    />
                  </Field>
                  <Field label="Password">
                    <TextInput
                      autoComplete={mode === 'sign-in' ? 'current-password' : 'new-password'}
                      minLength={6}
                      value={password}
                      onChange={(event) => {
                        auth.clearError()
                        setPassword(event.target.value)
                      }}
                      placeholder="6+ characters"
                      type="password"
                    />
                  </Field>
                  <div className="grid gap-2 sm:grid-cols-[1fr_auto]">
                    <Button className="w-full" onClick={() => void submitEmailAuth()} disabled={!canSubmitEmail || auth.isLoading}>
                      {busyAction === 'email' ? <Loader2 className="animate-spin" size={18} /> : <Mail size={18} />}
                      {mode === 'sign-in' ? 'Sign in' : 'Create account'}
                    </Button>
                    <Button
                      className="w-full"
                      type="button"
                      variant="secondary"
                      disabled={busyAction !== null || auth.isLoading}
                      onClick={() => {
                        auth.clearError()
                        setMode((current) => current === 'sign-in' ? 'create' : 'sign-in')
                      }}
                    >
                      {mode === 'sign-in' ? 'Create instead' : 'Sign in instead'}
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {auth.error && (
            <div className="mt-4 rounded-lg border border-red-200 bg-red-50 p-3 text-sm leading-5 text-red-700">
              {auth.error}
            </div>
          )}
        </div>
      </section>
    </main>
  )
}
