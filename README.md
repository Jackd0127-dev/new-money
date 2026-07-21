# New Money Workspace

New Money is a private, local-first paycheck planner with web and native iOS clients. The web client uses React, TypeScript, Vite, Dexie, Firebase, and Vercel. The iOS client uses SwiftUI and Swift Package Manager.

## Structure

- `App/` — deployable web project and its iOS companion project.
  - `src/` — web UI, state hooks, storage, Firebase integration, and finance domain code.
  - `api/` and `server/` — Vercel functions and server-only support code.
  - `ai/` — AI behavior documentation and server prompt instructions.
  - `ios/` — Xcode project, Swift sources, resources, schemes, and tests.
  - `docs/` — architecture, safety constraints, design references, and handoff notes.
  - `outputs/` — versioned simulation results used for finance verification.
  - `tools/` — scripts that generate and compare simulation outputs.
- `Brand/Logos/` — canonical standalone logo variants.
- `.github/` — repository automation.

Generated dependencies, build products, local environment files, Xcode user data, and deployment metadata are ignored by Git.

## Web Development

Use Node.js 22, then run commands from `App/`:

```bash
cd App
npm ci
cp .env.example .env.local
npm run dev
```

The app works locally without Firebase values; authentication, sync, and hosted AI features require the corresponding local or deployment environment variables. Never commit `.env.local`.

Run the complete web validation pipeline with:

```bash
cd App
npm run check
```

## iOS Development

Open `App/ios/NewMoneyIPhone/NewMoneyIPhone.xcodeproj` in Xcode, or inspect the shared schemes from the command line:

```bash
xcodebuild -list -project App/ios/NewMoneyIPhone/NewMoneyIPhone.xcodeproj
```

The normal `NewMoneyIPhone` scheme uses file-backed app data. Named QA and simulation schemes provide isolated fixtures; do not replace the normal repository with fixture data.

## Deployment

The web project is configured for Vercel and GitHub Pages. Vercel's project root must remain `App/`. GitHub Pages validates and builds `App/` through `.github/workflows/pages.yml`. Production deployment is a separate release action and is not implied by a code or pull-request update.
