---
status: draft
updated: 2026-11-08
---

# Vegabase: Architecture

> A deploy pipeline rejects broken themes and compositions before activation. A data layer fetches shared data once into each tenant's read index, so renders read only local data. One owning worker per tenant hosts its request pipeline, data layer and extensions; the edge and the control plane route requests to it. Stable shape only; mechanisms are in DESIGN.

## Context

- **Visitors** request pages, fragments and SSE streams, and trigger actions.
- **Editors and admins** manage routes, redirects, compositions, content and plugin approvals in the admin app.
- **Agency and tenant developers** build themes and plugins with the language toolchain and deploy them.
- **Platform team** builds and signs the core, vendor libs and language toolchain.
- **Commerce platforms** (Shopify; Medusa later) supply catalog, pricing, translations, webhooks, cart and customer login, and keep checkout, payments, orders and inventory.
- **Third-party HTTP APIs** are reached only by plugins, through approved outbound fetch.
- **CDN** caches public shells, cached fragments and assets. Never a security boundary.

## Quality goals (ranked; hard lines in CHARTER outrank all)

1. **Domain-agnostic core**: a non-commerce tenant runs with no core change (P1).
2. **Visitor speed**: renders read only local data; no page waits on upstream while an acceptable stale value exists (P2, G1).
3. **Efficient scale**: peak traffic is served by the CDN and within each worker's origin budget (G5).
4. **Upstream thrift**: shared fields are fetched once per freshness window per tenant; external calls per page view are measured (P3, G3).
5. **Correct before activation**: an invalid theme or composition fails at deploy or save (P4, G2).
6. **Tenant isolation**: a worker crash or plugin fault stays within its worker; sensitive tenants get dedicated workers (P5).

## Parts

| Part              | Responsibility                                                      | Owns                                                                                              | Status           |
| ----------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------- |
| Edge              | Caches public output; routes requests to the owning worker          | Host normalization, forwarded-header trust, tenant → worker mapping cache                         | draft (D-001)    |
| Control plane     | Holds platform-wide state; propagates versioned changes             | Tenants, domains, leases, activation pointer, gates, enablement, approvals, event delivery, sagas | draft (D-001)    |
| Deploy pipeline   | Validates and compiles themes and compositions into deployments     | Type checking (via the language toolchain), fetch plans, deployments, readiness check             | draft (D-001)    |
| Request pipeline  | Turns a request into a page, fragment or SSE patch                  | Gate → redirect → route → render; fragment endpoints; open streams                                | draft (D-001)    |
| Data layer        | Serves declared reads locally; the only path to core-owned data     | Entities, read index, caches, ingestion, published and computed fields, actions, outbox, routes and redirects | draft (D-001)    |
| Extension host    | Loads vendor libs, sandboxes plugins, enforces capabilities         | Vendor lib registration, plugin invocations, contracts, plugin private storage                    | draft (D-001)    |
| Shopify vendor lib | The only home of Shopify commerce concepts (D-015)                  | Shopify entity types, cart, customer login, B2B context                                           | draft (D-001)    |
| Admin app         | Lets editors compose and approve without code or data wiring        | Composer, side-effect-free preview, approval screens                                              | proposed (Q-012) |

## Seams

- **Control plane → Edge, workers**: versioned changes to ownership, activation, gates and enablement. Requires: receivers acknowledge each version. Guarantees: versions only increase; polling covers missed notifications.
- **Edge → Request pipeline**: a request with verified tenant, normalized host, visitor IP and generation. Guarantees: stale generations are rejected; private responses are never publicly cached.
- **Admin app, developers → Deploy pipeline**: compositions, routes, redirects and themes. Requires: declared kinds, slots and data needs. Guarantees: invalid input is rejected with source locations; nothing activates before its readiness check.
- **Request pipeline → Data layer**: a fetch plan plus context. Requires: declared reads only. Guarantees: every field returns a typed state (fresh, acceptable stale, unavailable, unauthorized), never `nil`.
- **Data layer ↔ Extension host**: batch resolver calls, change feeds, published fields, events. Requires: edition-pinned contracts. Guarantees: extensions see only declared fields, filtered by storage class and PII class.
- **Extension host ↔ vendor libs**: host API table in, descriptor table out. Requires: matching edition and build ID. Guarantees: registered only for tenants that enable it.

## Key flows

**Warm product page view**: the edge misses its cache and routes to the owning worker → the request pipeline checks gates, resolves the route and loads the activated deployment's fetch plan → the data layer serves the plan from the read index and caches, gap-fetching only missing or stale fields, batched per type owner → the request pipeline renders the shell and fragments; the CDN caches the shell, tagged by its read set.

**Save to activation**: the deploy pipeline type-checks the composition, route or theme and recomputes fetch plans → the data layer ingests the required fields and the readiness check passes → the control plane moves the activation pointer, workers acknowledge, and the CDN purges old entries.

**Upstream price change**: the Shopify vendor lib verifies, deduplicates and enqueues the webhook → the data layer updates the read index, invalidates dependent caches and computed fields, and purges tags → the request pipeline re-renders push-enabled instances whose read set matches.

## Invariants and absences

- Always: each tenant has exactly one owning worker. Broken if: two workers serve or write for one tenant.
- Always: private fields never enter the read index, shared cache or CDN. Broken if: a cached response or index row holds visitor-specific data.
- Always: gates fail closed. Broken if: a gated page is served while verification is unavailable.
- Always: untrusted code never runs natively. Broken if: a plugin fault crashes a worker.
- Always: extensions share only through published fields, owned entity types and events. Broken if: one reads another's storage or calls it.
- Always: only the core writes core-owned data; extensions write only through core-mediated paths (D-017). Broken if: an extension changes routes, redirects, compositions, deployments or ownership directly.
- Always: one request reads one deployment version end to end.
- Absent by design: everything in the CHARTER non-goals.
- Absent by design: plugins rendering HTML or acting as middleware; only the core renders.

## Code map (planned; `source/` is scaffolding today)

| Directory          | Part                                                                      |
| ------------------ | ------------------------------------------------------------------------- |
| `source/http/`     | Edge front router and request pipeline                                    |
| `source/template/` | Template language (language toolchain, shared with the deploy pipeline)   |
| `source/schema/`   | Schema language and type checker (language toolchain)                     |
| `source/store/`    | Data layer (name clashes with the glossary "store"; consider `data/`)     |
| `source/plugin/`   | Extension host: WASM sandbox, capabilities, host functions                |
| `source/bind/`     | One hand-written binding package per C library (DESIGN §7)                |
| `third_party/`     | Vendored C library sources, pinned by commit                              |

## Open questions

Q-005, Q-009 to Q-012 in DECISIONS.
