# Custom Resource authoring

Use when the user needs to manage a system Alchemy doesn't ship with (a niche SaaS, an internal API, etc).

## Recipe

```ts
import { Resource, type Context, alchemy } from "alchemy";

export interface MyThingProps {
  name: string;
  apiKey: ReturnType<typeof alchemy.secret>;
}

export interface MyThing extends MyThingProps {
  id: string;
  createdAt: number;
}

export const MyThing = Resource(
  "myservice::Thing",                              // globally unique kind
  async function (this: Context<MyThing>, id: string, props: MyThingProps): Promise<MyThing> {
    const headers = { Authorization: `Bearer ${props.apiKey.unencrypted}` };

    if (this.phase === "delete") {
      await fetch(`https://api.myservice.com/things/${this.output.id}`, { method: "DELETE", headers });
      return this.destroy();
    }

    if (this.phase === "update") {
      // If an immutable property changed, trigger replacement.
      if (this.output.name !== props.name) this.replace();
      // Otherwise PATCH and merge.
      return { ...this.output, ...props };
    }

    // create
    const res = await fetch("https://api.myservice.com/things", {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ name: props.name }),
    });
    if (!res.ok) throw new Error(`Create failed: ${res.status}`);
    const data = await res.json();
    return { ...props, id: data.id, createdAt: Date.now() };
  },
);
```

## Rules

- **Must be `async function`** — not arrow. `this` is the resource Context.
- **Kind string** must be globally unique. Use `"namespace::Name"` convention.
- Branch on `this.phase`: `"create" | "update" | "delete"`.
- In delete phase, return `this.destroy()`.
- Call `this.replace()` to swap-and-delete on immutable property changes. `this.replace(true)` deletes the old one first (downtime risk).
- Secrets in props: keep wrapped in `alchemy.secret(...)` so they encrypt at rest.
- Plain `fetch` works. No special SDK required.

## Testing a custom Resource

```ts
import { alchemy, destroy } from "alchemy";
import { expect } from "vitest";

const BRANCH_PREFIX = process.env.BRANCH_PREFIX ?? "local";
const test = alchemy.test(import.meta, { prefix: BRANCH_PREFIX });

test("creates and updates", async (scope) => {
  try {
    let t = await MyThing("t1", {
      name: `${BRANCH_PREFIX}-thing`,
      apiKey: alchemy.secret(process.env.API_KEY!),
    });
    expect(t.id).toBeTruthy();
  } finally {
    await destroy(scope);
  }
});
```
