---
status: draft
updated: 2026-11-08
---

# Vegabase: Decisions

> Accepted decisions bind; supersede them, never edit them silently. Open questions have no answer yet, so never assume one. IDs are never reused. D-001 to D-010 were rebuilt on 2026-11-08 from their index rows and the docs, because the originals were lost; they stay **Draft** until the project lead approves them.

## Decisions

**D-001 Part decomposition**: Draft (rebuilt). Seven parts: edge, control plane, deploy pipeline, request pipeline, data layer, extension host, Shopify vendor lib. The admin app is pending (Q-012). Why: each part owns state the others must not touch. See ARCHITECTURE.

**D-002 Odin core, C behind bindings**: Draft (rebuilt). One closed Odin core binary per build target, built by our CI. C only behind thin `bind/*` packages. Why: explicit memory and lifetimes, one language for the team (I-005). Consequence: no stable ABI, so core and vendor libs are built with the same compiler.

**D-003 HTTP serving and CDN**: Draft (rebuilt). libh2o at origin and in the front routers, behind a CDN that is never a security boundary. The CDN vendor is open; Cloudflare is the researched candidate (STACK §6). Why: event-loop HTTP/1-3 with SSE in C, embeddable from Odin.

**D-004 Hypermedia UI**: Draft (rebuilt). Datastar over SSE; theme CSS on replaceable design tokens (Stellar CSS or our own, Q-017). Why: server state, morphing, no client framework (I-003, I-004).

**D-005 Databases**: Draft (rebuilt). One StardustDB database per tenant for content, routes and the read index; Postgres for the control plane. Why: an embedded per-tenant database gives local reads and simple tenant moves; Postgres gives durable shared state and `LISTEN/NOTIFY`. Risk: StardustDB is alpha (Q-018, Q-019).

**D-006 Isolation model**: Draft (rebuilt). Logical isolation at API boundaries; hard resource limits only for WASM; dedicated workers for sensitive tenants. Why: density for most tenants; vendor libs are encapsulated, not sandboxed.

**D-007 Extension tiers and plugin ABI**: Draft (rebuilt). Three tiers: core; signed native vendor libs; sandboxed WASM plugins that import only the plugin ABI. Why: trusted hot paths stay native, while untrusted code never runs natively.

**D-008 Declared reads**: Draft (rebuilt). Every reader (component, plugin, vendor lib) declares its fields; the core plans, batches and caches them. Why: fetch once (P3); it makes G3 measurable.

**D-009 Typed themes, admin-managed routes**: Draft (rebuilt). Static types end to end; editors manage routes and redirects in the admin app and the core writes them (D-017); themes are component libraries with no routes or data wiring. Why: errors at deploy or save (P4, I-001).

**D-010 Editions**: Draft (rebuilt). The spec is the API. Two supported editions at a time, with migrations and retirement deadlines. Retiring an edition carries features forward and never drops them (D-014).

**D-011 Plugins in 1.0**: Accepted 2026-11-08. WASM plugins and the plugin ABI ship in 1.0. Why: access-policy gates need a plugin's verify action, and G4 needs real extensions to measure.

**D-012 Distributable language toolchain**: Accepted 2026-11-08. The template and schema parser, type checker, compiler front-end, LSP and plugin SDK form the language toolchain. It is separate from core and may be distributed as signed binaries; its source stays with the team. Packages import nothing from core runtime packages, and the deploy pipeline links the same packages. Amends the hosting hard line. Consequences: binaries per developer OS, versioned per edition; the language semantics become visible (acceptable, since themes need them).

**D-013 Upgrade path to 1.0**: Accepted 2026-11-08. Before 1.0, upgrades are manual and may interrupt service. 1.0 is the first stable, usable release, and requires rolling upgrades and tenant moves.

**D-014 Never remove shipped features**: Accepted 2026-11-08. A shipped feature is never removed if at all possible. Edition migrations carry features forward; a removal needs its own D- entry stating why keeping it is impossible. Adopted as principle P8.

**D-015 One vendor lib per commerce platform**: Accepted 2026-11-08. No neutral commerce lib and no "provider" role. Shopify is one vendor lib; Medusa, later, is another. Each is the type owner of its own entity types. Why: one type owner per type stays true, and there is no shared lib to keep neutral.

**D-016 Large traffic, efficient scale**: Accepted 2026-11-08. Design for large traffic from the start: the CDN serves public output, and per-worker origin budgets are enforced at the readiness check. Adds G5. Consequence: Q-009 (one tenant beyond one worker) becomes urgent.

**D-017 Core-owned data and extension write paths**: Accepted 2026-11-08. Only the core writes routes, redirects, compositions, deployments and ownership. Extensions write their private storage, tenant-owned databases through vendor lib connectors, and published fields, owned entities, events and gates through host functions. Routes and redirects live in the tenant's StardustDB database, versioned and activated with compositions; Postgres keeps gates, ownership and platform state.

**D-018 The origin never stops**: Accepted 2026-11-08. Workers never stop serving or return an error page. If the control plane is unreachable, they keep serving with frozen ownership, gates and activation; moves and activations wait. Anything that can't be rendered gets a fallback view; gated pages still fail closed, with the gate page as the fallback. Consequence: every write path checks the generation (fencing), so no second owner appears during an outage (Q-023). See OPERATIONS.

**D-019 Source-version writes**: Accepted 2026-11-08. Each type owner supplies a monotonic version per entity; the data layer rejects writes older than the stored version, and tombstones beat older updates. Webhooks, reconciliation and bulk backfill may then arrive in any order.

**D-020 Core content types**: Accepted 2026-11-08. The core is type owner of a fixed set of content types: page, post, media. A non-commerce tenant needs no extension (P1). Media bytes live in an object store (Q-032).

**D-021 Own certificates for custom domains**: Accepted 2026-11-08. We verify tenant domains with a DNS TXT challenge, re-check them periodically, detach dangling ones, and issue certificates ourselves over ACME. The CDN terminates visitor TLS, so certificates are uploaded to it (S-6).

**D-022 Purge coalescing**: Accepted 2026-11-08. Purges coalesce in a short window; past a threshold they fall back to coarser tags (entity type, then tenant). Gate and policy purges go first.

**D-023 Version axes**: Accepted 2026-11-08. Engine release, edition and deployment version are independent. Each engine release declares the editions it supports, always both supported editions.

**D-024 Observability floor for 1.0**: Accepted 2026-11-08. Structured logs plus per-tenant metrics (renders, origin load, external calls, JS weight, errors) and cost attribution.

**D-025 Manual theme port**: Accepted 2026-11-08. Shopify themes move to Vegabase by hand, with a porting guide. No Liquid converter in 1.0.

**D-026 Plugin approval**: Accepted 2026-11-08. The platform team reviews and signs a plugin bundle once; a tenant admin then approves its scopes for that tenant.

## Open questions

| ID | Question | Options · settled by |
| --- | --- | --- |
| Q-001 | What % cut in LCP and shipped JS weight is G1's pass line? | Measure the current themes on the same pages (needs Q-002) · project lead |
| Q-002 | Which stores are "our own", and how many must run in production for 1.0? | · project lead |
| Q-003 | Is there a time or effort bound (appetite) for 1.0? | None · fixed, with scope cut by goal · project lead |
| Q-004 | Is a non-commerce tenant a 1.0 deliverable? | Production tenant · CI test tenant · design property only · project lead |
| Q-005 | May any field be never-stale (B2B prices, balances), and may it block a page? | None · closed list rendering "unavailable" · closed list that may block · D- entry amending P2 |
| Q-006 | Should the domain-agnostic core become a hard line? | Keep as P1 · promote · D- entry |
| Q-007 | How are third-party browser scripts admitted, and who owns the allowlist? | Plugin theme components only · platform-owned script model · D- entry |
| Q-008 | Must the charter say P2 outranks P4 (and so G2)? | Note on G2 · re-rank · leave · project lead |
| Q-009 | How does one tenant scale beyond one owning worker? (urgent, D-016) | Read-only index replicas · another database · dedicated sizing only · load test of the largest store |
| Q-010 | Which types and contexts are index-backed vs request-time, with what staleness limits? | Workload model per type against memory and bulk-operation limits |
| Q-011 | Does the deploy pipeline run in the owning worker or a separate process? | In worker · separate process handing plans over · architecture decision |
| Q-012 | Is the admin app a part, or a client of the deploy pipeline and data layer? | Keep · demote · architecture decision |
| Q-013 | Theme file extensions? | Keep `.vegt`/`.vegs` · rename · before editor tooling starts |
| Q-014 | Plugins as signed binary bundles or source with a server-side build? | Binaries (lint is advisory) · source · plugin pipeline decision |
| Q-015 | May vetted partners author vendor libs? | Platform team only · partners with platform review, build and signing · project lead |
| Q-016 | Is linux_arm64 a production target? | amd64 only for 1.0 · both · hosting cost comparison |
| Q-017 | Do Stellar CSS terms allow hosted use by agencies and tenants? | License Stellar · own token sheet · written terms (no Stellar licence text found; Datastar says Stellar works without Pro) |
| Q-018 | How do we bound StardustDB history while keeping backups, rollback and erasure? | Confirm capabilities (S-5) · retention decision |
| Q-019 | What are StardustDB's terms for hosted multi-tenancy and licence activation? | Vendor's terms in writing; 30-day tokens are confirmed |
| Q-020 | Who owns search, filtering, facets and sorting? | Core per-tenant index · Shopify Storefront API · extension · decide as the project grows |
| Q-021 | What RPO, RTO, backup cadence and restore drill do tenant databases need? A restore must re-apply erasures | After S-5 |
| Q-022 | After an activation flip, what happens when a worker never acknowledges? | Fence the worker · roll back · retry; scope query raised by the project lead |
| Q-023 | Lease TTL, renewal cadence and clock source, and where the generation check sits on each write path (D-018) | Design before S-5 |
| Q-024 | What survives a tenant move or restart: SSE resync, action idempotency keys, saga steps, sessions and carts? | Persist in the tenant database · rebuild · accept loss per item |
| Q-025 | Session cookie scope per custom domain; fragment signing key scope, rotation and host/context binding; the CDN cache key | Host-only cookies, per-tenant keys · platform-wide |
| Q-026 | How large can contexts grow (market × language × currency × B2B location) against index memory and the 16 KB Cache-Tag limit? | Workload model per tenant (with Q-010) |
| Q-027 | Plugin trap or fuel exhaustion mid-saga; repeated traps; computed-field budget exhaustion | Retry · compensate · poison; circuit breaker; serve stale or unavailable |
| Q-028 | Is a declared storage or PII class trusted, and does a computed field inherit its strictest input class? | Trust and audit · inherit strictest · verify by sampling |
| Q-029 | Where do tenant Shopify tokens live and rotate; admin authentication, MFA, roles and audit scope? | Secrets store design · project lead |
| Q-030 | Tenant data export and deletion for 1.0? | Self-serve · operator-run · after 1.0 |
| Q-031 | How do editors preview draft entities, and how is merchant content localized against the read index? | Draft as a context dimension · separate preview index |
| Q-032 | Which object store holds media bytes (D-020)? | CDN object storage (R2) · own store · tenant database |
| Q-033 | What is the local theme development loop? | Local fixture runtime · remote preview tenant · both |
| Q-034 | Glossary proposals: rename `entity` to entity page; save (editors) vs deploy (developers); global region; shared plugin | Accept or reject each · project lead |

## Risks

- **R-001 Shopify blocks ingestion or visitor traffic.** Signal: rising 430 or 429 responses. Response: Admin bulk operations only; on 430, alert and serve stale with no retry loop; back off on 429; register Web Bot Auth keys if needed.
- **R-002 Approved plugin JS leaks visitor data.** Signal: unexpected endpoints, `connect-src` violation reports. Response: only signed, approved bundles carry JS; the approval screen says what JS can do; `connect-src 'self'`. Residual risk accepted.
- **R-003 Injected script runs on a CDN-cached shell.** A per-deployment nonce doesn't stop injection. Response: accepted; the defenses are static Datastar expressions, contextual escaping, sanitized `RichText` and `data-ignore`.
- **R-004 StardustDB claims fail.** Many limits we design around are unverified (STACK §3). Signal: S-5 results. Response: the `ContentStore` and index proc tables allow a swap.

## Influences

| ID | Influence | Stance | What and why |
| --- | --- | --- | --- |
| I-001 | Shopify theme system (sections, blocks, JSON templates) | Adapted | Keep the structure developers know; replace untyped Liquid (G2, P4) |
| I-002 | Shopify app model | Rejected | Per-app scripts and fetches are the problem (G3, G4, P3) |
| I-003 | SPA frameworks, client routing, optimistic UI | Rejected | Hypermedia only; the UI confirms committed results |
| I-004 | Datastar / Delaney Gillilan | Borrowed | Server state, SSE plus morphing, tiny stable core (P7) |
| I-005 | gingerBill / Odin philosophy | Borrowed | Specific problem first, explicit, errors as values, arenas (P7) |
| I-006 | Public app marketplace | Rejected | Admin-approved plugins only (P6) |
