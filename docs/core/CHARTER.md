---
status: draft
updated: 2026-11-08
---

# Vegabase: Charter

> A hosted storefront and CMS engine, written in Odin, for our own stores and the stores our agency builds. It renders each tenant from one read index, so pages are faster, extensions stop piling on scripts and API calls, and theme mistakes are caught before visitors see them.

## Problem

As an agency and as merchants on Shopify we hit three problems:

- Theme bugs surface only at runtime, because Liquid is untyped and editors can break pages.
- Each Shopify app adds its own scripts and API calls, which slows pages.
- Overlapping apps and themes refetch the same data, which hits API limits and costs money.

## Vision

Data is fetched once and shared by every page and extension. Extensions add data and components, never their own scripts or API calls. A broken theme or composition fails at deploy or save, never in front of a visitor.

## Goals

| #   | Goal                                                                   | Success signal                                                                                 |
| --- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| G1  | Our own stores run on the engine, faster than on their current themes  | On the same pages, LCP and shipped JS weight are cut by at least X% (Q-001)                    |
| G2  | Theme and composition errors are caught before activation _(proposed)_ | Invalid ones fail at deploy or save; no production incident traces to a type error in either   |
| G3  | Shared upstream data is fetched once per freshness window per tenant   | External calls per page view are reported; no rate-limit incidents at peak _(signal proposed)_ |
| G4  | Extensions add no scripts or API calls of their own _(proposed)_       | Per-extension JS weight and external calls show in the admin app, within budget                |
| G5  | The engine serves large traffic efficiently                            | Peak workload (STACK §4) served within the per-worker origin budget (D-016)                    |

## Scope (1.0)

- Multi-tenant hosting with admin-owned routes, redirects, market and language URLs, and a composer
- Typed themes, templates and transforms, plus a distributable language toolchain (D-012)
- A shared data layer: declared reads, read index, caches, published and computed fields, events, actions
- Fragments: pull by default; push over SSE is opt-in
- The Shopify vendor lib: catalog and pricing ingestion, webhooks, cart, customer login, B2B context
- Vendor libs and sandboxed, admin-approved WASM plugins (D-011)
- Gates, SEO basics, and two supported editions with migrations

## Non-goals

- Checkout, payments, orders, inventory: the commerce platform (Shopify; Medusa later) keeps them; we only display availability.
- Client frameworks, SPA routing, optimistic UI: hypermedia only.
- Distributing core or vendor lib source or binaries: hosted only by us (the language toolchain is separate, D-012).
- A public plugin marketplace: plugins are admin-approved per tenant.
- Extensions calling each other (hard line below).
- Failover beyond supervisor restarts and restore from backup.

## Audience

Merchants and their visitors (our own stores first); agency developers, then tenant developers after handoff; editors and admins; the platform team.

## Constraints and appetite

- Tenant isolation is logical; tenants that need more get dedicated workers.
- Accepted D- entries are fixed; flag real risks in them.
- Before 1.0, upgrades are manual. 1.0 is the first stable, usable release (D-013).
- Appetite: not set (Q-003).

## Assumptions

- StardustDB (alpha) can run hosted multi-tenant production. Invalidated if its terms, licence activation or file-format stability fail (Q-019).
- Shopify Admin API bulk operations plus webhooks keep catalog, per-market prices and translations fresh enough. Invalidated if bulk operations can't fetch `contextualPricing` or translations (spike S-9), or if staleness limits are missed under real volume.
- Our current themes are a fair G1 baseline. Invalidated if they are atypically heavy or atypically optimized.
- Stellar CSS terms allow hosted use, or our own token sheet suffices (Q-017).

## Principles (ranked: a higher one wins)

When none settles a case, raise a Q- entry instead of improvising a rule. Change a principle only through a D- entry.

1. **P1. Domain-agnostic core, even over a faster or simpler core.** Commerce lives in vendor libs. Why: once commerce leaks in, non-commerce tenants need core changes. Violation: a cart or price type in core because it skips a vendor lib hop.
2. **P2. Fast pages, even over fresher data.** Why: visitors feel latency on every page, and checkout confirms the real price. Violation: blocking a product page on a slow upstream call when the cache holds an acceptable value.
3. **P3. Shared data fetched once, even over per-extension convenience.** Why: duplicate fetches are what hit API limits today. Violation: a component or plugin refetching a product instead of declaring its fields.
4. **P4. No broken page reaches a visitor, even over a quicker or more permissive deploy or save.** Why: runtime-only errors are what we are leaving. Violation: saving an invalid composition with a warning and failing at render.
5. **P5. Isolation for sensitive tenants, even over density and cost** _(rank proposed)_. Why: on shared workers, native code sees neighbours' data. Violation: a B2B tenant on a shared worker by default.
6. **P6. Third-party scripts only from a fixed allowlist, even over a merchant's request** _(rank proposed)_. Why: each unvetted script brings back what G4 removes. Violation: an off-list pixel for one merchant.
7. **P7. Small, simple core, even over mechanisms the goals don't need.** Why: every mechanism is maintained forever. Violation: a general rule engine where two fixed page kinds would do.
8. **P8. Never remove a shipped feature, if at all possible** (D-014). Why: tenants and themes depend on it. Violation: an edition migration that drops a feature instead of carrying it forward.

## Hard lines

- MUST NOT serve a gated page or private/PII data when access can't be verified. Fail closed, even if slow or down.
- MUST NOT run untrusted code (plugins, tenant code) natively, because one native fault crashes or exposes every tenant in the process.
- MUST NOT put private or visitor-specific data in shared caches, the read index or the CDN.
- MUST NOT let extensions call each other or read each other's storage, because hidden coupling breaks contracts, editions and uninstall.
- MUST NOT let extensions write core-owned data (routes, redirects, compositions, deployments, ownership). Extensions write only through core-mediated paths (D-017).
- MUST NOT let core or vendor lib source or binaries leave our team. Language toolchain binaries are exempt (D-012).
