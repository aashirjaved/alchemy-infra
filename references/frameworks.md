# Framework adapter reference

Every framework template follows the same shape: `alchemy.run.ts` declares a high-level resource (`Vite`, `Nextjs`, etc.), and the framework's config file imports an `alchemy()` adapter.

## Vite + React

```ts
// alchemy.run.ts
import alchemy from "alchemy";
import { Vite } from "alchemy/cloudflare";
const app = await alchemy("my-react-app");
export const worker = await Vite("website");
await app.finalize();
```
```ts
// vite.config.ts
import alchemy from "alchemy/cloudflare/vite";
import react from "@vitejs/plugin-react";
export default { plugins: [react(), alchemy()] };
```

## Next.js (via OpenNext)

```bash
bun add @opennextjs/cloudflare
```
```ts
// alchemy.run.ts
import alchemy from "alchemy";
import { KVNamespace, Nextjs } from "alchemy/cloudflare";
const app = await alchemy("my-next");
export const kv = await KVNamespace("kv");
export const website = await Nextjs("website", {
  adopt: true,
  bindings: { KV: kv },
});
await app.finalize();
```
```ts
// open-next.config.ts
import { defineCloudflareConfig } from "@opennextjs/cloudflare";
export default defineCloudflareConfig({});
```
Access bindings in routes:
```ts
import { getCloudflareContext } from "@opennextjs/cloudflare";
export const GET = async () => {
  const { env } = getCloudflareContext();
  return Response.json(await env.KV.list());
};
```

## SvelteKit

```ts
// alchemy.run.ts
import { SvelteKit } from "alchemy/cloudflare";
export const worker = await SvelteKit("website");
```
```js
// svelte.config.js
import alchemy from "alchemy/cloudflare/sveltekit";
export default { kit: { adapter: alchemy() } };
```

## Astro

```ts
// astro.config.mjs
import { defineConfig } from "astro/config";
import alchemy from "alchemy/cloudflare/astro";
export default defineConfig({ output: "server", adapter: alchemy() });
```

## Nuxt

```ts
// nuxt.config.ts
import alchemy from "alchemy/cloudflare/nuxt";
export default defineNuxtConfig({ modules: [alchemy()] });
```

## TanStack Start

Vite config:
```ts
import { defineConfig } from "vite";
import { tanstackStart } from "@tanstack/start/plugin";
import alchemy from "alchemy/cloudflare/vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
  plugins: [tanstackStart({ target: "cloudflare-module" }), react(), alchemy()],
});
```

## Bindings types — auto-generated

Most framework templates emit `types/env.d.ts` that declares `Cloudflare.Env` from `typeof worker.Env`. If you wrote `alchemy.run.ts` by hand, create the file:

```ts
import type { worker } from "../alchemy.run.ts";
declare module "cloudflare:workers" {
  namespace Cloudflare {
    export interface Env extends typeof worker.Env {}
  }
}
```
