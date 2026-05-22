# Troubleshooting

## "ALCHEMY_PASSWORD is not set"
You used `alchemy.secret(...)` without setting the password. Add to `.env`:
```
ALCHEMY_PASSWORD=<32+ bytes of entropy>
```

## "Resource already exists" / 409 on create
The remote resource exists but isn't in state. Two options:
- Re-run with `--adopt` (CLI flag) or set `adopt: true` on the resource props.
- Manually delete the remote resource via the provider's dashboard.

## "Cannot find package 'alchemy'" / ESM import errors
- Ensure `package.json` has `"type": "module"` OR your IaC file uses `.mts`.
- TypeScript `module` setting should be `"NodeNext"` or `"ESNext"`.
- If using Bun, no transpile config required.

## Type-check fails on `env.CACHE` not found
You haven't wired the binding types. Add `types/env.d.ts`:
```ts
import type { worker } from "../alchemy.run.ts";
declare module "cloudflare:workers" {
  namespace Cloudflare {
    export interface Env extends typeof worker.Env {}
  }
}
```
Make sure `types/` is in `tsconfig.json` `include`.

## "Orphaned resources" after running
You forgot `await app.finalize()`. Add it at the end of `alchemy.run.ts`.

## Custom Resource handler — `this` is undefined
You wrote an arrow function instead of `async function`. Switch to `async function` so `this` binds.

## Cloudflare 10000 / Auth Failed
- Token may be missing scopes. Check `references/security.md` minimum scopes list.
- `CLOUDFLARE_ACCOUNT_ID` mismatch — the token isn't for that account. Verify with:
  ```bash
  curl -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" https://api.cloudflare.com/client/v4/accounts | jq '.result[].id'
  ```

## Destroy ran but didn't delete remote resource
Resource had `delete: false`. Remove that flag, then re-run destroy.

## State drift (out-of-band changes)
Someone deleted the resource in the dashboard. On next `up`, you'll see "resource not found" during update. Re-run with `--adopt` (recreates without erroring) or delete the state file for that resource.

## Lost ALCHEMY_PASSWORD
Encrypted secrets are unrecoverable. Options:
1. Recreate the stage from scratch (destroy → re-deploy, supplying secrets fresh).
2. Manually delete all `*.json` state files that contain `"@secret"` entries (you'll lose those resources from state — re-adopt them).

There is no documented in-place rotation. Treat the password as permanent.

## `alchemy dev` Miniflare crashes
- Ensure `compatibilityDate` is set on the Worker.
- Some Cloudflare bindings (Hyperdrive, certain AI) don't have local emulation — set `dev: { remote: true }` on those bindings.

## Windows-specific issues
Not officially documented. WSL2 + Bun is the most reliable path. PowerShell paths in `entrypoint` should use forward slashes.
