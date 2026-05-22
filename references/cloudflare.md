# Cloudflare provider reference

Import path: `alchemy/cloudflare`. All resources are async functions; `await` them inside the app scope.

## Worker — the main compute primitive

```ts
import { Worker, KVNamespace, R2Bucket, D1Database, Queue, DurableObjectNamespace, Workflow } from "alchemy/cloudflare";
import alchemy from "alchemy";

const cache   = await KVNamespace("cache", { title: "cache" });
const storage = await R2Bucket("storage", { empty: false });
const db      = await D1Database("db", { migrationsDir: "./drizzle" });
const queue   = await Queue<{ name: string; email: string }>("jobs");
const counter = DurableObjectNamespace("counter", { className: "Counter", sqlite: true });
const flow    = Workflow("orderFlow", { className: "OrderFlow" });

export const worker = await Worker("api", {
  name: "api-worker",
  entrypoint: "./src/worker.ts",
  url: true,                              // workers.dev URL — disable for DO/prod
  compatibilityDate: "2025-01-01",
  bindings: {
    CACHE: cache, STORAGE: storage, DB: db, QUEUE: queue,
    COUNTER: counter, ORDER_FLOW: flow,
    API_KEY: alchemy.secret(process.env.API_KEY),
    PUBLIC_ENV: "production",
  },
  eventSources: [queue],
  routes: [{ pattern: "api.example.com/*", zone: "example.com" }],
  domains: ["api.example.com"],
  crons: ["0 * * * *"],
  placement: { mode: "smart" },
  limits: { cpu_ms: 50 },
});
```

## Storage

| Resource | Typical use |
|---|---|
| `KVNamespace(id, { title })` | Cache, config, simple KV. |
| `R2Bucket(id, { empty })` | Object storage. `empty: true` deletes contents on destroy. |
| `BucketObject(id, { bucket, key, content })` | Single object upload. |
| `D1Database(id, { migrationsDir, migrationsTable })` | SQLite at edge. `migrationsTable: "drizzle_migrations"` for Drizzle. |
| `Queue<T>(id)` | Typed queue. Consumer wired via `eventSources: [queue]` on a Worker. |
| `VectorizeIndex(id, { dimensions, metric })` | Vector DB. |
| `Pipeline(id, ...)` | Cloudflare Pipelines. |
| `Hyperdrive(id, { origin })` | Pooled connection to external Postgres. |

## Durable Objects

```ts
const counter = DurableObjectNamespace("counter", {
  className: "Counter",
  sqlite: true,                  // enable SQLite-backed DO
  // migrations: [...]
});
```
Not awaited — DOs are declarative references resolved when bound on a Worker.

## DNS / Routing

```ts
import { Zone, DnsRecords, CustomDomain, Route } from "alchemy/cloudflare";

const zone = await Zone("example.com", { type: "full" });
await DnsRecords("dns", {
  zone,
  records: [
    { name: "@",   type: "A",     content: "192.0.2.1", proxied: true },
    { name: "www", type: "CNAME", content: "@",         proxied: true },
  ],
});
```

## Email

`EmailRouting`, `EmailRule`, `EmailAddress`, `EmailCatchAll`, `EmailSender` — see provider docs at https://alchemy.run/providers/cloudflare/

## AI

`AI`, `AIGateway`, `AISearch`, `AISearchNamespace`, `AISearchToken`, `AICrawler`.

## Access (Zero Trust)

`AccessApplication`, `AccessGroup`, `AccessIdentityProvider`, `AccessPolicy`, `AccessServiceToken`.

## Framework wrappers (high-level resources)

`Vite`, `Nextjs`, `SvelteKit`, `Nuxt`, `Astro`, `TanStackStart`, `ReactRouter`, `Redwood`, `BunSpa`, `Website`. Each wraps a framework build into a Worker (or static + Worker hybrid).

## Patterns

- **Adopt existing resource**: pass `adopt: true` on the resource props.
- **Don't delete on destroy**: pass `delete: false` (handy for KVs holding user data).
- **Per-binding remote dev override**: `dev: { remote: true }` on a binding makes the local dev session hit the deployed resource instead of the Miniflare emulation.
