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

**D-005 Data stores**: Draft (rebuilt). One StardustDB database per tenant for content, routes and the read index; Postgres for the control plane. Why: an embedded per-tenant database gives local reads and simple tenant moves; Postgres gives durable shared state and `LISTEN/NOTIFY`. Risk: StardustDB is alpha (Q-018, Q-019).

**D-006 Isolation model**: Draft (rebuilt). Logical isolation at API boundaries; hard resource limits only for WASM; dedicated workers for sensitive tenants. Why: density for most tenants; vendor libs are encapsulated, not sandboxed.

**D-007 Extension tiers and plugin ABI**: Draft (rebuilt). Three tiers: core; signed native vendor libs; sandboxed WASM plugins that import only the plugin ABI. Why: trusted hot paths stay native, while untrusted code never runs natively.

**D-008 Declared reads**: Draft (rebuilt). Every reader (component, plugin, vendor lib) declares its fields; the core plans, batches and caches them. Why: fetch once (P3); it makes G3 measurable.

**D-009 Typed themes, admin-owned routes**: Draft (rebuilt). Static types end to end; routes and redirects are owned in the admin app; themes are component libraries with no routes or data wiring. Why: errors at deploy or save (P4, I-001).

**D-010 Editions**: Draft (rebuilt). The spec is the API. Two supported editions at a time, with migrations and retirement deadlines. Retiring an edition carries features forward and never drops them (D-014).

**D-011 Plugins in 1.0**: Accepted 2026-11-08. WASM plugins and the plugin ABI ship in 1.0. Why: access-policy gates need a plugin's verify action, and G4 needs real extensions to measure.

**D-012 Distributable language toolchain**: Accepted 2026-11-08. The template and schema parser, type checker, compiler front-end, LSP and plugin SDK form the language toolchain. It is separate from core and may be distributed as signed binaries; its source stays with the team. Packages import nothing from core runtime packages, and the deploy pipeline links the same packages. Amends the hosting hard line. Consequences: binaries per developer OS, versioned per edition; the language semantics become visible (acceptable, since themes need them).

**D-013 Upgrade path to 1.0**: Accepted 2026-11-08. Before 1.0, upgrades are manual and may interrupt service. 1.0 is the first stable, usable release, and requires rolling upgrades and tenant moves.

**D-014 Never remove shipped features**: Accepted 2026-11-08. A shipped feature is never removed if at all possible. Edition migrations carry features forward; a removal needs its own D- entry stating why keeping it is impossible. Adopted as principle P8.

**D-015 One vendor lib per commerce platform**: Accepted 2026-11-08. No neutral commerce lib and no "provider" role. Shopify is one vendor lib; Medusa, later, is another. Each is the type owner of its own entity types. Why: one type owner per type stays true, and there is no shared lib to keep neutral.

**D-016 Large traffic, efficient scale**: Accepted 2026-11-08. Design for large traffic from the start: the CDN serves public output, and per-worker origin budgets are enforced at the readiness check. Adds G5. Consequence: Q-009 (one tenant beyond one worker) becomes urgent.

**D-017 Core-owned data and extension write paths**: Accepted 2026-11-08. Only the core writes routes, redirects, compositions, deployments and ownership. Extensions write their private storage, tenant-owned databases through vendor lib connectors, and published fields, owned entities, events and gates through host functions. Routes and redirects live in the tenant's StardustDB database, versioned and activated with compositions; Postgres keeps gates, ownership and platform state.

## Open questions

| ID    | Question                                                                    | Options · settled by                                                                              |
| ----- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Q-001 | What % cut in LCP and shipped JS weight is G1's pass line?                  | Measure the current themes on the same pages (needs Q-002) · project lead                         |
| Q-002 | Which stores are "our own", and how many must be live for 1.0?              | · project lead                                                                                    |
| Q-003 | Is there a time or effort bound (appetite) for 1.0?                         | None · fixed, with scope cut by goal · project lead                                               |
| Q-004 | Is a non-commerce tenant a 1.0 deliverable?                                 | Live tenant · CI test tenant · design property only · project lead                                |
| Q-005 | May any field be never-stale (B2B prices, balances), and may it block a page? | None · closed list rendering "unavailable" · closed list that may block · D- entry amending P2    |
| Q-006 | Should the domain-agnostic core become a hard line?                         | Keep as P1 · promote · D- entry                                                                   |
| Q-007 | How are third-party browser scripts admitted, and who owns the allowlist?   | Plugin theme components only · platform-owned script model · D- entry                             |
| Q-008 | Must the charter say P2 outranks P4 (and so G2)?                            | Note on G2 · re-rank · leave · project lead                                                       |
| Q-009 | How does one tenant scale beyond one owning worker? (urgent, D-016)         | Read-only index replicas · another database · dedicated sizing only · load test of the largest store |
| Q-010 | Which types and contexts are index-backed vs request-time, with what staleness limits? | Workload model per type against memory and bulk-operation limits                                  |
| Q-011 | Does the deploy pipeline run in the owning worker or a separate process?    | In worker · separate process handing plans over · architecture decision                           |
| Q-012 | Is the admin app a part, or a client of the deploy pipeline and data layer? | Keep · demote · architecture decision                                                             |
| Q-013 | Theme file extensions?                                                      | Keep `.vegt`/`.vegs` · rename · before editor tooling starts                                      |
| Q-014 | Plugins as signed binary bundles or source with a server-side build?        | Binaries (lint is advisory) · source · plugin pipeline decision                                   |
| Q-015 | May vetted partners author vendor libs?                                     | Platform team only · partners with platform review, build and signing · project lead              |
| Q-016 | Is linux_arm64 a production target?                                         | amd64 only for 1.0 · both · hosting cost comparison                                               |
| Q-017 | Do Stellar CSS terms allow hosted use by agencies and tenants?              | License Stellar · own token sheet · written terms (no Stellar licence text found; Datastar says Stellar works without Pro) |
| Q-018 | How do we bound StardustDB history while keeping backups, rollback and erasure? | Confirm capabilities (S-5) · retention decision                                                   |
| Q-019 | What are StardustDB's terms for hosted multi-tenancy and licence activation? | Vendor's terms in writing; 30-day tokens are confirmed                                            |

## Risks

- **R-001 Shopify blocks ingestion or visitor traffic.** Signal: rising 430 or 429 responses. Response: Admin bulk operations only; on 430, alert and serve stale with no retry loop; back off on 429; register Web Bot Auth keys if needed.
- **R-002 Approved plugin JS leaks visitor data.** Signal: unexpected endpoints, `connect-src` violation reports. Response: only signed, approved bundles carry JS; the approval screen says what JS can do; `connect-src 'self'`. Residual risk accepted.
- **R-003 Injected script runs on a CDN-cached shell.** A per-deployment nonce doesn't stop injection. Response: accepted; the defenses are static Datastar expressions, contextual escaping, sanitized `RichText` and `data-ignore`.
- **R-004 StardustDB claims fail.** Many limits we design around are unverified (STACK §3). Signal: S-5 results. Response: the `ContentStore` and index proc tables allow a swap.

## Influences

| ID    | Influence                                         | Stance   | What and why                                                        |
| ----- | ------------------------------------------------- | -------- | ------------------------------------------------------------------- |
| I-001 | Shopify theme system (sections, blocks, JSON templates) | Adapted  | Keep the structure developers know; replace untyped Liquid (G2, P4) |
| I-002 | Shopify app model                                 | Rejected | Per-app scripts and fetches are the problem (G3, G4, P3)            |
| I-003 | SPA frameworks, client routing, optimistic UI     | Rejected | Hypermedia only; the UI confirms committed results                  |
| I-004 | Datastar / Delaney Gillilan                       | Borrowed | Server state, SSE plus morphing, tiny stable core (P7)              |
| I-005 | gingerBill / Odin philosophy                      | Borrowed | Specific problem first, explicit, errors as values, arenas (P7)     |
| I-006 | Public app marketplace                            | Rejected | Admin-approved plugins only (P6)                                    |
