# CI/CD reference (GitHub Actions)

Canonical workflow: deploy on push to `main` → `prod`; deploy on PR → `pr-<n>`; destroy on PR close.

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
  pull_request:
    types: [opened, reopened, synchronize, closed]

env:
  STAGE: >-
    ${{ github.event_name == 'pull_request' && format('pr-{0}', github.event.number) ||
        (github.ref == 'refs/heads/main' && 'prod' || github.ref_name) }}

jobs:
  deploy:
    if: github.event.action != 'closed'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write    # for GitHubComment posting preview URL
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install --frozen-lockfile
      - run: bun alchemy deploy --stage "$STAGE"
        env:
          ALCHEMY_PASSWORD:      ${{ secrets.ALCHEMY_PASSWORD }}
          ALCHEMY_STATE_TOKEN:   ${{ secrets.ALCHEMY_STATE_TOKEN }}
          CLOUDFLARE_API_TOKEN:  ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          GITHUB_TOKEN:          ${{ secrets.GITHUB_TOKEN }}

  cleanup:
    if: github.event_name == 'pull_request' && github.event.action == 'closed'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
      - run: bun install --frozen-lockfile
      - name: Safety check
        run: |
          if [ "$STAGE" = "prod" ] || [ "$STAGE" = "main" ]; then
            echo "Refusing to destroy protected stage: $STAGE"
            exit 1
          fi
      - run: bun alchemy destroy --stage "$STAGE"
        env:
          ALCHEMY_PASSWORD:      ${{ secrets.ALCHEMY_PASSWORD }}
          ALCHEMY_STATE_TOKEN:   ${{ secrets.ALCHEMY_STATE_TOKEN }}
          CLOUDFLARE_API_TOKEN:  ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

## Required GitHub Actions secrets

| Secret | Purpose |
|---|---|
| `ALCHEMY_PASSWORD` | Decrypt secrets in state. |
| `ALCHEMY_STATE_TOKEN` | Auth for CloudflareStateStore (only if used). |
| `CLOUDFLARE_API_TOKEN` | Scoped to the resources you deploy. |
| `CLOUDFLARE_ACCOUNT_ID` | Account ID. |
| `AWS_*` | If deploying to AWS, use OIDC role assumption instead of long-lived keys when possible. |

## Posting preview URL to PR

```ts
import { GitHubComment } from "alchemy/github";

if (process.env.GITHUB_TOKEN && process.env.PR_NUMBER) {
  await GitHubComment("preview-url", {
    token: alchemy.secret(process.env.GITHUB_TOKEN),
    owner: "your-org",
    repo:  "your-repo",
    issueNumber: Number(process.env.PR_NUMBER),
    body: `Preview deployed: ${worker.url}`,
  });
}
```
The comment is idempotent — subsequent deploys edit it in place.

## AWS via OIDC (no long-lived keys)

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/gha-deployer
      aws-region: us-east-1
```
