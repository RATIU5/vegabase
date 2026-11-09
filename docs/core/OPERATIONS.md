---
status: draft
updated: 2026-11-08
---

# Vegabase: Operations

> How the engine stays up, recovers, stays secure in operation and is observed. CHARTER, DECISIONS, GLOSSARY and ARCHITECTURE outrank this doc; it sits beside DESIGN. Versions, limits and prices are in STACK.

## 1. Ownership and fencing

- A worker owns a tenant under a lease plus generation. A lapsed lease means stop taking new ownership work and close the tenant's databases once a successor holds the lease. Stale-generation requests and writes are rejected.
- Every write path (StardustDB, outbox, published fields, actions) checks the generation it was opened under (fencing), so a paused or partitioned worker can't write after a successor opens (D-018). Lease TTL, renewal and clock source: Q-023.
- Control-plane changes reach routers and workers by Postgres `LISTEN/NOTIFY` with a polling fallback; versions only increase.

## 2. Never stop serving (D-018)

- No origin response is a 5xx page. Anything that can't be rendered gets a fallback view: the stale cached value, the component's `unavailable` state, or a minimal built-in page.
- Control plane unreachable: workers keep serving with frozen ownership, gates and activation. Moves, activations, approvals and gate edits wait until it returns. The CDN keeps serving cached pages.
- Gates still fail closed: when access can't be verified, the gate page is the fallback.
- Worker crash: the supervisor restarts it within a tested reopen budget. Host loss: restore from backup elsewhere under a new generation. Recovery targets: Q-021.

## 3. Tenant moves and upgrades

- Move: stop writes, drain, close, copy a consistent snapshot, verify, bump the generation, open on the new worker, warm, reroute. CDN hits continue meanwhile; moves have a tested time budget. What survives a move (SSE resync, idempotency keys, sagas, sessions, carts): Q-024.
- Upgrades (D-013): before 1.0, manual restarts. From 1.0, rolling: move tenants to a warm sibling worker before restarting; SSE clients reconnect with staggered backoff.
- Version axes (D-023): engine release, edition and deployment version are independent. Each engine release declares the editions it supports; a worker accepts only tenants whose pinned editions it supports.
- Scale (D-016): the CDN absorbs public traffic; each owning worker has an origin budget. One tenant beyond one worker: Q-009.

## 4. Activation and purges

- Activation flips the Postgres pointer after staging in both databases (DESIGN §9). A worker that never acknowledges: Q-022.
- Purges coalesce in a short window; past a threshold they fall back to coarser tags (entity type, then tenant). Gate and policy purges go first (D-022). The adapter is `purge_tags(tags[])`, `set_origin_auth()` (STACK §6).

## 5. Domains and edge trust

- Tenant domains: DNS TXT challenge, periodic re-check, dangling domains detached; certificates issued by us over ACME and uploaded to the CDN, which terminates visitor TLS (D-021, S-6). A detached domain also loses its customer-account redirect URI.
- Origins accept only authenticated CDN pulls or mTLS; direct hits are rejected (S-6). Forwarded headers are trusted only from the CDN.
- Session cookie scope, fragment signing keys and the CDN cache key: Q-025.

## 6. Security operations

- Plugins: the platform team reviews and signs each bundle once; a tenant admin approves its scopes (D-026). Load-time checks are in DESIGN §6.
- Signing: platform keys (HSM or equivalent) sign the core, vendor libs, language toolchain and approved plugin bundles. Workers trust a control-plane key set plus a revocation list.
- Secrets: tenant credentials by reference only, never in plugin memory or logs. Storage, rotation and admin authentication: Q-029.
- Erasure is a platform workflow across StardustDB history, Postgres, caches, CDN, logs, PII-classed plugin storage, published fields and backups, with an audit record. A restore re-applies erasures (Q-021).

## 7. Observability (D-024)

- Structured logs and per-tenant metrics: renders by cache class, origin requests against the origin budget, external calls per page view (G3), per-extension JS weight and external calls (G4), errors and fallback views served, purge lag.
- Cost attribution per tenant from worker time, memory, storage and external calls.
- R- signals (430/429 rates, CSP violation reports) are metrics with alerts.
