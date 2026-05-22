# Security hygiene — strict

These rules are not optional. Apply them every time, even when the user is in a rush.

## 1. ALCHEMY_PASSWORD

- Generate 32+ bytes of entropy: `openssl rand -base64 32` (see `scripts/gen_password.sh`).
- Store in `.env`, never in source code, never in CI logs.
- Treat it as **permanent for the lifetime of the state**. Changing it after secrets are encrypted corrupts decryption — there is no documented rotation procedure.
- Distribute to teammates / CI via a secret manager (1Password, AWS Secrets Manager, GitHub Actions secrets), not Slack/email.

## 2. .env handling

- `.env` is gitignored. Always.
- `.env.example` is committed and lists every variable name with empty values. This is the contract for teammates.
- Never echo or `cat` `.env` to the agent's stdout. If the user pastes a secret into the chat, ask them to revoke and reissue.

## 3. .gitignore (required entries)

```
.env
.env.*
!.env.example
.alchemy/
node_modules/
.wrangler/
dist/
.DS_Store
*.pem
*.key
credentials.json
```

Run `scripts/gitignore_check.sh` to verify before any `git add`.

## 4. Token scoping

- **Cloudflare API tokens**: mint with least-privilege scopes. For a Worker + KV + D1 app, the minimum is:
  - Account → Workers Scripts → Edit
  - Account → Workers KV Storage → Edit
  - Account → D1 → Edit
  - Account → Account Settings → Read
  - Zone → DNS → Edit (only if managing DNS)
  - Refuse to use the Global API Key unless the user insists; warn them it has full account access.
- **AWS**: prefer SSO/IAM Identity Center sessions. If long-lived keys are required, scope to a dedicated IAM user with only the actions used by the deployed stack.

## 5. State backend protection

- Filesystem state (`.alchemy/`) contains encrypted secrets but also resource IDs and metadata. Don't post it publicly.
- CloudflareStateStore: protect the `ALCHEMY_STATE_TOKEN` the same way as `ALCHEMY_PASSWORD`.
- S3StateStore: bucket must be private, versioned, with SSE-S3 or SSE-KMS. Block public access at the account level.

## 6. Never inline secrets

Bad:
```ts
const worker = await Worker("api", { bindings: { API_KEY: "sk-live-..." }});
```
Good:
```ts
const worker = await Worker("api", {
  bindings: { API_KEY: alchemy.secret(process.env.API_KEY) },
});
```

## 7. Refuse-to-commit checklist

Before any `git commit`, verify:
- `git status` shows no `.env` or `.alchemy/`.
- No file containing `BEGIN PRIVATE KEY`, `-----BEGIN RSA`, or obvious token prefixes (`sk-`, `xoxb-`, `ghp_`, `AKIA`).
- Refuse to proceed if any such file is staged; show the user what was caught and offer to unstage.

## 8. Logging

- Don't print decrypted secret values to the console even when debugging. Use the resource's id or `[REDACTED]`.
- `eraseSecrets: true` is for debugging only — never leave it on in committed code.
