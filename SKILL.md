---
name: alchemy-infra
description: Sets up Alchemy (alchemy-run/alchemy, Infrastructure-as-TypeScript) in any codebase — new project scaffold OR add to existing app. Wires Cloudflare/AWS providers, state backend, secrets, and binding types end-to-end with strict secret hygiene. USE THIS SKILL whenever the user mentions "alchemy", "alchemy.run", "Infrastructure as TypeScript", or asks to deploy a Worker/Lambda/D1/R2/KV/Queue/DO via TS, add a state backend, configure ALCHEMY_PASSWORD, generate alchemy.run.ts, replace SST/Pulumi/CDK/Terraform with Alchemy, or scaffold a Cloudflare/AWS app from TypeScript. Trigger even when the user does not say "alchemy" explicitly but describes the workflow (e.g., "deploy a Worker with KV in pure TS", "TypeScript IaC", "wire D1 + Drizzle to a Worker", "set up Cloudflare bindings without wrangler.toml").
version: 0.1.0
author: aashirjaved
license: MIT
homepage: https://github.com/aashirjaved/alchemy-infra
tags: [alchemy, infrastructure, iac, typescript, cloudflare, aws, workers, deployment, devops]
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

# alchemy-infra

You are configuring **Alchemy** — an ESM-only, TypeScript-native IaC library where resources are async functions you `await`. State lives in JSON files (default), Cloudflare DO, S3, or SQLite. Secrets are encrypted with `ALCHEMY_PASSWORD`.

This skill is **interactive**. Do not guess the user's situation. Run the **Intake** below first, then branch.

---

## Step 0 — Intake (ALWAYS run before writing files)

Ask the user these questions in a single batched prompt (use the AskUserQuestion tool if available; otherwise plain text with numbered options). Do not skip — the answers change every subsequent decision.

1. **Starting point** — (a) brand-new project, (b) add to existing repo, (c) replace existing IaC (SST/Pulumi/CDK/Terraform/Wrangler).
2. **Cloud target** — (a) Cloudflare, (b) AWS, (c) both, (d) other provider (Vercel/Neon/PlanetScale/Stripe/etc).
3. **Framework** (if applicable) — Worker only, Vite, Next.js, SvelteKit, Astro, Nuxt, TanStack Start, React Router, Redwood, Bun SPA, or none.
4. **Runtime preference** — Bun (recommended), Node, pnpm/npm/yarn.
5. **State backend** — filesystem (default, fine for solo dev), CloudflareStateStore (recommended for teams/CI), S3StateStore, SQLiteStateStore.
6. **Auth method** — Cloudflare OAuth (`alchemy login`), CF API token in env, AWS profile, or "I'll do it later".
7. **Stage/env strategy** — single stage, per-user (`$USER`), per-branch PR previews (`pr-<n>`), explicit prod/staging/dev.
8. **Resources up front** — list what they need (Worker, KV, R2, D1, Queue, DO, Workflow, Lambda, DDB, S3, etc). It's OK if "just hello-world for now".

Follow up only if answers are contradictory or block progress. Don't over-interrogate.

---

## Step 1 — Detect existing state

Before touching anything, run:

```bash
ls package.json tsconfig.json alchemy.run.ts wrangler.toml wrangler.jsonc sst.config.ts pulumi.yaml cdk.json 2>/dev/null
```

If `alchemy.run.ts` already exists, **read it first** and treat the task as a modification, not a fresh install. If `wrangler.toml`/`sst.config.ts`/`pulumi.yaml` exist, the user is migrating — confirm before deleting any of those.

---

## Step 2 — Install

Based on intake answer for runtime + start point:

**New project from template** (preferred when starting fresh):
```bash
bunx alchemy create <name> --template=<typescript|vite|nextjs|sveltekit|nuxt|astro|tanstack-start|react-router|redwood|bun-spa>
```

**Add to existing project**:
```bash
# pick the package manager that matches the repo
bun add alchemy        # or: pnpm add / npm install / yarn add
bunx alchemy init      # optional: --framework <name> --yes
```

Verify install:
```bash
node -e "console.log(require('alchemy/package.json').version)"
```

Alchemy is ESM-only. If the repo is CommonJS, set `"type": "module"` or move IaC code to `.mts` / `.ts` files compiled with ESM target.

---

## Step 3 — Write `alchemy.run.ts`

Always place at repo root. Skeleton (cloud-agnostic core, add provider blocks per intake):

```ts
import alchemy from "alchemy";
// import per cloud — examples:
// import { Worker, KVNamespace, R2Bucket, D1Database } from "alchemy/cloudflare";
// import { Function, Table, Bucket } from "alchemy/aws";

const app = await alchemy("APP_NAME_HERE", {
  phase: process.argv.includes("--destroy") ? "destroy" : "up",
  // stage: process.env.STAGE,           // uncomment if multi-stage
  // password: process.env.ALCHEMY_PASSWORD, // already default, set for clarity
});

// === resources go here ===
// export const worker = await Worker("api", { entrypoint: "./src/worker.ts" });

await app.finalize();
```

**Required rules:**
- The handler must be `async function`, not arrow, for any custom Resource.
- `await app.finalize()` must be the last statement in the `up` path. Without it, orphans are not GC'd.
- Wrap every secret with `alchemy.secret(process.env.X)`. Never inline a literal token.

See `references/cloudflare.md` and `references/aws.md` for full resource shapes.

---

## Step 4 — Security setup (NON-NEGOTIABLE)

Follow `references/security.md` in full. Quick checklist:

1. **Generate ALCHEMY_PASSWORD** — run `scripts/gen_password.sh` (32+ bytes, base64). Write to `.env`. Never commit.
2. **Generate ALCHEMY_STATE_TOKEN** (only if using CloudflareStateStore) — `openssl rand -base64 32`.
3. **Update `.gitignore`** — must contain:
   ```
   .env
   .env.*
   !.env.example
   .alchemy/
   node_modules/
   .wrangler/
   ```
   Run `scripts/gitignore_check.sh` to verify.
4. **`.env.example`** — list every variable name with empty value. Commit this file; never commit `.env`.
5. **Never log decrypted secrets.** If the user asks you to print a token, refuse and offer to redact.
6. **Never write tokens into `alchemy.run.ts` literally.** Always pull from `process.env` and wrap with `alchemy.secret()`.
7. **Refuse to commit** if `git status` shows `.env`, `.alchemy/`, or any file with `*.pem`, `*.key`, `credentials.json`. Surface and stop.

---

## Step 5 — State backend

Default filesystem is fine for solo dev. For team/CI use Cloudflare or S3.

```ts
// Cloudflare DO-backed (recommended for shared state)
import { CloudflareStateStore } from "alchemy/state";
const app = await alchemy("my-app", {
  stateStore: (scope) => new CloudflareStateStore(scope, {
    stateToken: alchemy.secret(process.env.ALCHEMY_STATE_TOKEN),
  }),
});

// S3
import { S3StateStore } from "alchemy/aws";
new S3StateStore(scope, { bucketName: "my-app-alchemy-state", region: "us-east-1" });

// SQLite local
import { SQLiteStateStore } from "alchemy/state";
new SQLiteStateStore(scope, { filename: ".alchemy/state.sqlite" });
```

If the user picks CloudflareStateStore, the `alchemy-state-service` Worker auto-deploys on first run.

---

## Step 6 — Auth

Branch on intake:

- **Cloudflare OAuth**: `bun alchemy configure && bun alchemy login`. Tokens land in `~/.alchemy/credentials/<profile>/cloudflare.json`. Tell user to keep that dir private.
- **CF API Token**: write `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` to `.env`. Mint a token with minimal scopes (Workers Scripts:Edit, KV/R2/D1/Queue:Edit as needed, Account:Read). Show the scoped permissions list, don't reuse Global API Key unless they insist.
- **AWS**: rely on standard `AWS_PROFILE` / `AWS_ACCESS_KEY_ID` / SSO. Never write long-lived AWS keys into the repo.

---

## Step 7 — Wire framework adapter (if applicable)

See `references/frameworks.md`. One block per framework. Key invariants:

- Vite: add `alchemy()` plugin from `alchemy/cloudflare/vite` to `vite.config.ts`.
- Next.js: install `@opennextjs/cloudflare`, add `open-next.config.ts`, use `Nextjs(...)` resource.
- SvelteKit: `svelte.config.js` adapter `alchemy/cloudflare/sveltekit`.
- Astro: `astro.config.mjs` adapter `alchemy/cloudflare/astro` with `output: "server"`.

---

## Step 8 — Scripts in package.json

Add these (preserve existing scripts):
```json
{
  "scripts": {
    "deploy": "alchemy deploy",
    "destroy": "alchemy destroy",
    "dev": "alchemy dev",
    "run": "alchemy run"
  }
}
```

If `dev`/`deploy` are already taken, prefix with `alchemy:` instead of overwriting.

---

## Step 9 — Verify

1. **Type-check**: `bun tsc --noEmit` (or `tsc --noEmit`) — must pass.
2. **Dry-run read phase**: `bun alchemy run --stage local` — should print outputs without mutating cloud.
3. **Local dev** (Cloudflare only): `bun alchemy dev` — Miniflare boots, hot reload works.
4. **Deploy** (only if user explicitly asks): `bun alchemy deploy --stage <name>`.

If type-check fails on missing binding types, add to `types/env.d.ts`:
```ts
import type { worker } from "../alchemy.run.ts";
declare module "cloudflare:workers" {
  namespace Cloudflare {
    export interface Env extends typeof worker.Env {}
  }
}
```

---

## Step 10 — CI/CD (optional, if user asked)

See `references/cicd.md` for the canonical GitHub Actions setup with per-PR stages, secret injection, and a destroy job on PR close. Always include the safety check refusing to destroy `prod`.

---

## Common gotchas (warn the user proactively)

- Missing `await app.finalize()` → orphans accumulate.
- `phase: "destroy"` halts the script — code after `await alchemy(...)` never runs.
- `url: true` Worker preview URLs are incompatible with Durable Objects in prod — use `routes`/`domains`.
- Changing `ALCHEMY_PASSWORD` after secrets are stored corrupts decryption. Rotation procedure is not officially documented; treat the password as permanent.
- Committing `.alchemy/` works only for single-developer projects. For teams, switch state backend before the first deploy.
- Resource handlers must be `async function`, not arrow.

---

## Decision flow (use this as your operating loop)

1. Run **Step 0 intake**.
2. Run **Step 1 detect**.
3. Confirm plan back to user in 3-5 bullets (what you'll install, what files you'll write, what env vars they need). Wait for go-ahead before mutating.
4. Execute Steps 2-8 in order.
5. Run **Step 9 verify**. Report results.
6. Offer Step 10 (CI/CD) and any custom Resources they asked for.

For custom Resource authoring, see `references/custom-resources.md`. For troubleshooting failed deploys, see `references/troubleshooting.md`.
