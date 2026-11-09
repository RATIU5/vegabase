---
status: draft
updated: 2026-11-08
---

# Vegabase: Design

> Mechanism detail. CHARTER, GLOSSARY, ARCHITECTURE and DECISIONS outrank this doc; operations are in OPERATIONS. Template and schema syntax and semantics are in `docs/specs/` (start at `specs/README.md`); concrete extension APIs are designed separately. Versions, limits and prices are in STACK.

## 1. Runtime

```
CDN (client TLS, HTTP/3, caching) ─ authenticated origin pull / mTLS
 └─ front routers (libh2o proxy, one per host): tenant → (host, worker, generation) from the control plane
     same host: unix socket · other host: mTLS HTTP/2 to that host's router
 └─ workers under a supervisor; each owning worker holds its tenants' StardustDB databases, caches, read index, SSE streams
     ├─ h2o event-loop threads: accept, route, plan, render, SSE
     └─ thread pool: libpq, libcurl, StardustDB, wasmtime, heavy renders
```

- **Front routers** are stateless: verify domain ownership, normalize hosts, trust forwarded headers only from the CDN, pass the visitor IP, proxy SSE with long timeouts and no buffering.
- **Workers**: shared (default) or dedicated. Worker config may allowlist vendor libs and set limits; each worker loads only its tenants' vendor libs.
- Ownership, fencing, moves, upgrades, failure and scale: OPERATIONS §1–3.

## 2. Request handling, memory, threads

- Order: router → owning worker → gates → redirects → routes → composition → fetch plan → read index and caches → batched gap fetch → render → HTML or SSE patch.
- Renders have work budgets. Over budget, they move to the pool with owned copies of inputs and outputs. h2o objects are touched only on their event loop; cancellation never frees memory a pool thread uses.
- Memory: a per-request arena; one sub-arena per SSE push; compiled themes and fetch plans in reference-counted per-deployment arenas; caches in evictable allocators (slabs), never arenas. A per-worker budget covers databases (StardustDB memory set explicitly, Unverified API), caches, wasmtime pools and native buffers, with admission control, RSS monitoring and load shedding.
- One libcurl multi and one libpq connection set per thread. Per-tenant curl handles and credentials. Per-tenant concurrency caps with fair scheduling. wasmtime: one `Engine` and compiled modules per process, one `Store` per invocation. Verify StardustDB handle thread safety; if unsafe, serialize per tenant.

## 3. Themes and the language toolchain

- Package: `.vegs` and `.vegt` files anywhere in the theme (paths carry no meaning; a template names its type, VEGT §1), optional `.css` and budgeted `.js`, `assets/**`. Manifest syntax (edition, name, vendor libs, global settings): Q-044. Extensions stay `.vegs`/`.vegt` (Q-013).
- Deploy fails on every `check` error (`specs/COMMON.md` §6), extension-namespace collisions (Q-045), and unsafe uploads (size, traversal, symlinks, MIME).
- Components, groups and page kinds: VEGS §6, VEGS-DATA §4. Composition depth is capped by the core (VEGS-DATA §8).
- Locales: `locale` tables and `t(...)` (VEGS §7.5, VEGT §7); missing translations fall back to the default locale. Placeholders and plurals: Q-036. Merchant-translated content lives in the database (Q-031).
- Assets: fingerprinted, pre-compressed (Brotli, zstd), selected from the tree actually rendered; fragments declare theirs; each loads once. The JS budget covers packaged JS.
- **Language toolchain** (D-012): parser, type checker, compiler front-end and LSP live in packages that import nothing from core runtime packages. The deploy pipeline links the same packages, so local and server results match. Shipped as signed binaries per developer OS, versioned per edition.

## 4. Templates, routing, gates

- Own parser on lexbor's tokenizer, enforcing the HTML5 structure rules of VEGT §8. Type-check all expressions and pipes; emit static chunks plus bytecode.
- Transforms (template-callable `fn`s, VEGS §4.4): versioned built-ins plus enabled vendor lib functions, never plugins. They run on the cached canonical entity; expensive results are memoized by (entity version, function, args).
- Escaping semantics are in VEGT §8. Mechanism: lexbor tokenizer contexts for HTML, attribute and URL (core scheme allowlist); `std.RichText` sanitized with lexbor and wrapped in `data-ignore`; Datastar expressions stay static.
- Routes and redirects (route rules: VEGS-DATA §4) are managed by editors in the admin app, written by the core and stored in the tenant's StardustDB database, versioned and activated with compositions (D-017). Lookup: gates → redirects → routes → `not-found`. A redirect that conflicts with a route needs an explicit winner. A route whose page kind has no component fails deploy or save; if one is still missing at runtime, the core serves a minimal built-in page and alerts.
- Markets and languages live in the URL (path prefix or domain), never negotiated by header or geo; at most one suggestion redirect. Public HTML needs no context `Vary`.
- Status codes: full pages use 200, 404, and 410 for tombstoned entities; overrides set a 2xx, 3xx or 4xx status. No page or override uses 5xx. Fragments return visitor-facing errors as 2xx HTML, but real codes for auth expiry, throttling and gone. Open SSE streams send a final event and close. A deployment or CSP change forces full navigation.
- Gates are stored in the control plane, propagated ahead of time and checked in memory, with no WASM per request. Policy-protected routes are never publicly cached. Scheduled overrides cap `s-maxage` at the transition time. A small core script flips clients at the transition; high-traffic pages are pre-rendered before an override ends.
- SEO: sitemaps, robots, canonicals, hreflang per market, structured data, `noindex` on gate pages.

## 5. Data layer

- Entities: the core owns the content types page, post and media (D-020). Sessions and signals are not entities. Writes carry the type owner's monotonic source version; older writes are rejected and tombstones beat older updates (D-019). Alternate keys (SKU, handle, external IDs) map to canonical IDs with declared scope and uniqueness; changed or reused keys are tombstoned. Fields declare the context dimensions they vary by.
- Fetch plans carry relationship traversals with depth, pagination and cost limits. They are recomputed on changes to theme, composition, type owners, contracts, editions or relevant settings, and drive what the read index holds.
- Loading: frontier loading (resolve roots, read locally, batch missing keys per type owner, repeat within limits). Order: read index → shared cache → session cache. Gap-fetch only missing or stale fields. Singleflight keyed by entity, context, field set and freshness. Outcomes: fresh, acceptable stale, unavailable, unauthorized; a field with no acceptable value renders its component's `unavailable` state (VEGS-DATA §7). The readiness check keeps required index-backed fields present, so this applies only to request-time types (Q-010; never-stale fields: Q-005).
- Read index: shared entities, projections and shared published fields. Ingestion comes from change feeds plus periodic reconciliation and bulk backfill, queued per type owner. After each commit the worker emits an in-process hint with the transaction ID; SSE consumers resync from their last transaction ID. Data classes: authoritative (backed up), derived (recomputed), external (re-ingested), with rebuildability tested per type.
- Caches: the shared cache is keyed (tenant, type, id, context), field-level, with TTL, stale-while-revalidate and dependency-following invalidation (lists, lookups, computed fields, counts). The session cache holds private fields. CDN entries are tagged with tenant, deployment version and read-set tags, and purged on read index, deployment, route, redirect or gate changes. Caches hold canonical data or rendered output; transforms run at render.
- Extension sharing: an extension shares data only by publishing it; private storage is never shared. Published fields are keyed by entity identity, namespaced, written only by their publisher, each with storage class and PII class. Owned entity types have resolvers and change feeds. A reader declares a contract as required (install fails without it) or optional (arrives "absent") and lists the fields as inputs to its computed field, resolver or event handler; the core passes only those, filtered by storage class and PII class. Computed fields form a DAG with incremental, budgeted, debounced recompute. Events go through a transactional outbox in the database that owns the change, relayed at-least-once to idempotent per-subscriber inboxes with a dead-letter queue.
- Writes: actions check CSRF, Origin, authorization and an idempotency key, serialized per target with version checks. Multi-extension actions run as durable sagas in Postgres. The UI confirms from the committed result; the session cache holds it until the read index catches up. Admin app preview never runs side effects.
- Fragments: the cache class is derived from the schema and tightened with `@fragment`; cache policy comes from `@cache` on the type owner's loader, and fields and pages may only tighten it (VEGS-DATA §5, §7). Endpoints are signed (tenant, deployment version, instance ID, keys, expiry); personalized ones are session-bound. Triggers: action results, push by read-set match (opt-in), pull on visibility, interval or interaction. Streams have heartbeats, per-tenant budgets and backpressure, and fall back to pull when over budget.

## 6. Plugins (WASM, 1.0 per D-011)

- We compile every module ourselves with time and memory caps; precompiled uploads are never accepted. The compile cache is keyed by module hash, wasmtime version, target and engine config.
- Pooling allocator; one `Store` per invocation per tenant and plugin, with fuel, epoch deadline and limiter, dropped after the call or any trap. Host calls have deadlines and per-invocation budgets.
- Plugins provide: resolvers for owned types, published and computed fields, event handlers, actions and saga steps, webhook handlers, page kinds, overrides, access policies, and theme components the core renders.
- Host functions (capability-gated): outbound fetch via libcurl (hostname allowlisted, every resolved IP checked against private/metadata ranges, connection pinned to the checked IP, redirects followed by the host, HTTPS only, size enforced), private storage, secrets by reference, logging, time, publishing, gate changes.
- Storage: no database credentials. Per-tenant, per-plugin private storage with quotas, encrypted at rest, PII-classed, deleted on uninstall. Tenant-owned databases only through vendor lib connectors with named, parameterized operations.
- Load-time checks on the signed bundle: imports only from the core ABI or enabled vendor lib namespaces (reject `wasi_*`, `env`); allowlisted exports; one bounded 32-bit memory; no start function; manifest matches the approval; pinned engine features; the linker defines only approved host functions. Source lint is advisory (Q-014).
- Data in: only declared fields, filtered by tenant, visitor, scopes, storage class and PII class; CBOR with size and depth limits; every guest pointer is bounds-checked.
- Browser: plugin JS is trusted tenant code (R-002), allowed only in signed, approved bundles. CSP: nonce plus same-origin `script-src`, `object-src 'none'`, `base-uri 'none'`, `form-action 'self'`, `connect-src 'self'`. Datastar CSP mode (`data-nonce` on `html`), no `unsafe-eval`. A fresh nonce per uncached response; a per-deployment nonce on CDN-cached shells (R-003). Third-party scripts: Q-007.

## 7. Vendor libs and bindings

- A signed `.so` per target, verified (signature, hash, build ID) before `core:dynlib` loads it. One C-ABI entry point exchanges a versioned host API table for a descriptor table. Core and vendor libs are built with the same pinned compiler and flags, because Odin has no stable ABI.
- Boundary: `proc "c"`, plain structs with tested layout, pointer plus length. No `any`, maps or dynamic arrays. No panics across the boundary. Shared C services come from the host table. No unloading; disabling drains, then unregisters. Per-tenant registration.
- Bindings: one `bind/<lib>` package per C library, hand-written for the subset we use, with generated `size_of`/`align_of` tests. Global allocator hooks (curl, lexbor) point to one thread-safe process allocator, never arenas. C errors become Odin unions at the boundary. ASAN/UBSAN in CI; fuzz the parsers, sanitizer, CBOR and webhooks.

## 8. Shopify vendor lib

- Cart in Shopify (Storefront Cart API): we hold the cart ID per session; checkout redirects to `checkoutUrl`; mutations are serialized per cart and handle payload `userErrors`.
- Ingestion only through Shopify Admin API bulk operations (up to 5 concurrent per shop): catalog, `contextualPricing` per market, translations. Bulk support for the last two is Unverified (spike S-9).
- Visitor-driven Storefront requests send `Shopify-Storefront-Private-Token`, `Shopify-Storefront-Buyer-IP`, and the customer and B2B context via `@inContext`.
- Customer accounts: OAuth 2.0 + PKCE with discovery; validate `state` and `nonce`; durable pending-login state; each tenant domain registered as a redirect URI. Refresh tokens are issued only to customer-account clients configured on the shop; otherwise re-authorize. Logout via `end_session_endpoint`.
- B2B: the selected company location is part of the context key; all B2B results are private.
- Webhooks: HMAC on the raw body, dedupe by event ID, durable enqueue, out-of-order tolerant, periodic reconciliation.
- Errors: 430 Security Rejection alerts and serves stale with no retry loop (R-001); 429 backs off; checkout throttling is separate. Each edition targets a supported Shopify API version and retires before it does.

## 9. Databases and consistency

- **Postgres** (control plane): tenants, domains, users, roles, enablement, editions, ownership, plugin registry, approvals, deployment pins and the activation pointer, gates and schedules, outbox, inboxes, sagas, signing keys, usage.
- **StardustDB** (one database per tenant): content, compositions, routes and redirects (with history for preview and rollback), theme settings, audit trail, read index, its own outbox facts, plugin private storage. Narrow `ContentStore` and index proc tables keep it swappable. Authoritative data has tested export and import; external and derived data is rebuilt by re-ingest.
- **Activation**: stage in both databases, validate, then flip the Postgres activation pointer. Workers acknowledge before CDN purge. The previous deployment is kept for rollback. A crash before the flip leaves the old deployment active.
- Erasure and signing: OPERATIONS §6.
