---
status: draft
updated: 2026-11-08
---

# Vegabase: Stack and environment

> Fast-moving facts: versions, limits, prices, environment, workload, spikes. External facts were checked on 2026-11-08 against the sources at the end; re-verify before relying on them.

## Standing instructions

- The stack is chosen (D-002 to D-007). Don't comment on maturity; raise only a concrete defect with evidence.
- Answer for the pinned version; if a newer one matters, say so in one line.
- For any pin, CDN, hosting or Shopify fact: check the primary source and record the version, date and URL. If sources disagree, show both.

## 1. Pins

`mise.toml` and `mise.lock` are the source of truth for tools.

| Component                | Pin                                       |
| ------------------------ | ----------------------------------------- |
| Odin                     | dev-2026-10 (84bc3fc), in `mise.toml`     |
| wasmtime + C API         | 50.0.1 (c307ec8)                          |
| h2o                      | master commit                             |
| StardustDB               | build alpha-2610240014, hash-checked      |
| Datastar                 | 1.0.4 (1efcdc3), vendored                 |
| lexbor                   | commit of tag v3.0.1                      |
| curl / zstd / brotli     | 8.23.0 / 1.5.7 / 1.2.1                    |
| libpq, PostgreSQL server | REL_18_6 / 18.6                           |
| Shopify API version      | 2026-10, env `SHOPIFY_API_VERSION`        |
| LLVM/zig cc, sysroot, CLDR, tzdata, Stellar CSS | TBD                |

- C libraries are pinned by commit. Planned: a hash-checked mise fetch task (S-8).
- wasmtime ships a new major on the 20th of each month; bump only after S-3 passes.
- Odin at dev-2026-10 provides `core:os`, `vendor:curl`, `core:encoding/cbor`, `core:time/timezone`, `core:crypto/ed25519`, `core:dynlib`, `core:odin/parser`, the `freestanding_wasm32` target and `-build-mode:shared`.

## 2. Libraries

| Layer          | Choice                                                                                              |
| -------------- | --------------------------------------------------------------------------------------------------- |
| HTTP and TLS   | libh2o (picotls/OpenSSL), built without LTO; origin mTLS or authenticated pulls; router ↔ router mTLS |
| Outbound HTTP  | libcurl multi (`vendor:curl`); SSRF rules in DESIGN §6                                              |
| Postgres       | libpq on pool threads; one `LISTEN/NOTIFY` connection per process                                   |
| WASM           | wasmtime C API, official prebuilt; fuel, epoch interruption, pooling allocator                      |
| JSON, CBOR     | `core:encoding/json`, `core:encoding/cbor`; C only if profiling demands it                          |
| HTML           | Own parser on the lexbor tokenizer; lexbor tree for `RichText`; security and differential tests     |
| Formatting     | Odin formatter over pinned CLDR and tz data: decimal currency, numbers, plurals, fixed date styles; tested against ICU |
| Compression    | brotli, zstd; pre-compress at deploy; h2o compresses dynamic responses                              |
| Hash and sign  | `core:hash` (xxHash), `core:crypto/sha2`, `core:crypto/ed25519`                                     |
| Editor tooling | tree-sitter plus an LSP on the language toolchain (D-012)                                           |
| Images         | Image CDN or imgproxy, out of process                                                               |

## 3. StardustDB facts

- Embedded database, in alpha. Later alpha builds may not open existing databases, so pin exact builds and keep exportable backups.
- One licence per project. Licence tokens expire 30 days after download; dev and CI need a refresh step.
- Design assumptions still to confirm with spike S-5: single-opener, in-process events only, an explicit memory budget setting, blackholes for erasure, and how history interacts with backups (R-004).

## 4. Environment and workload

- Dev: Apple Silicon Mac. Prod: linux_amd64 (linux_arm64 is Q-016). The language toolchain also ships for developer OSes.
- L0, Mac native: edit, compile, pure-Odin tests. L1, amd64 container on the Mac (OrbStack): integration tests touching h2o, wasmtime, StardustDB or C libs. L2, remote Linux amd64: load tests, CI, every speed number.
- OrbStack: free for personal use; business is $8 per user per month, or $96 a year billed annually.
- L2 candidates: Hetzner CPX22 at €19.99/month before VAT; GitHub Codespaces with 120 compute hours a month (60 hours on a 2-core machine). Prod host: Proposed Hetzner.
- Base OS image: TBD, the same for L1, L2 and prod. Secrets live in `mise.local.toml` or the keychain.

| Workload input (D-016)  | Value                                                   |
| ----------------------- | ------------------------------------------------------- |
| Peak visitors per day   | 400,000 (design target; expect more, scale efficiently) |
| Orders per day (peak)   | 5,000                                                   |
| Products / contexts     | 5,000 (variants TBD) / one, growing to multi-market     |
| Price changes per day   | 2                                                       |

Derived (Speculation: 5 page views per visitor, 60% of peak in the busiest 4 hours, about 7.5 min average session): about 83 page views/s, about 7,500 open SSE connections, about 3.5 order webhooks/min averaged (higher in peak hours). Origin renders per page view = on-demand + live fragments; expected origin load = page views/s × that number plus cache misses. A deployment over the origin budget (set by S-4) fails its readiness check, and live fragments get a per-route ceiling.

## 5. Shopify facts

- 2026-10 is the latest stable version, accessible until 2027-10-16. Stable versions are supported for at least 12 months. Retired versions fall forward to the oldest supported one; check `X-Shopify-API-Version`.
- Bulk operations: up to 5 concurrent bulk queries and 5 bulk mutations per shop (2026-01 and later). S-9 confirms `contextualPricing` and translations in bulk.
- 430 "Security Rejection" answers requests judged malicious. Rate limits apply to bot traffic; buyer traffic is exempt. Web Bot Auth signed traffic gets higher limits once its keys are registered.
- Customer Account API refresh tokens go to customer-account clients configured on the shop. Storefront checkout creation is throttled per minute.

## 6. CDN facts (Cloudflare, the researched candidate)

- Purge by tag on every plan: Free 5 requests/min, Pro 5/s, Business 10/s; up to 100 tags per request. The `Cache-Tag` header holds up to 16 KB in total (about 1,000 tags), which bounds read-set tagging.
- The origin response timeout is 125 s by default (Enterprise up to 6,000 s). SSE: heartbeat every 25 s and send `Cache-Control: no-store`.
- Cloudflare for SaaS: 100 custom hostnames included on Free, Pro and Business, then $0.10 each. Pro costs $20 a month billed annually, or $25 monthly.
- Video and large files are served through the CDN when hosted on Cloudflare Stream, Images or R2.
- Cloudflare for SaaS custom certificates (our own, per D-021): plan, price and limits to confirm in S-6.
- Keep purge behind one adapter: `purge_tags(tags[])`, `set_origin_auth()`.

## 7. Acceptance spikes

| ID  | Check                                                                                      | Pass                                                                |
| --- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| S-1 | `mise install` clean on the Mac and in the amd64 container                                 | `mise run lint` and `mise run test` pass in both                    |
| S-2 | An Odin shared-library vendor lib loads into a host                                        | Symbols resolve; struct versions agree                              |
| S-3 | Odin links the wasmtime C API and runs a `freestanding_wasm32` module importing only the plugin ABI | The call returns; a forbidden import fails at load                  |
| S-4 | h2o from Odin, multi-threaded, shell plus SSE, on L2                                       | 10 min of SSE with heartbeats, stable memory; yields the origin budget |
| S-5 | StardustDB from Odin with the token file; confirm each §3 assumption                       | Write, restart, read back; each assumption marked true or false     |
| S-6 | CDN: tag purge, multi-tag response, SSE past the timeout, authenticated origin pull limits, origin rejects direct hits, uploading our ACME certificates for tenant hostnames (D-021) | Purge is visible within seconds                                     |
| S-7 | Datastar CSP mode on a cached shell                                                        | Runs without `unsafe-eval`, from cache                              |
| S-8 | Fetching C deps on a clean machine                                                         | Every commit and hash matches                                       |
| S-9 | Shopify bulk query with `contextualPricing` per market and translations on a dev store     | Both return complete data                                           |

## Sources

Odin github.com/odin-lang/Odin/releases · wasmtime github.com/bytecodealliance/wasmtime/releases · lexbor, curl, zstd, brotli, h2o: their GitHub releases · Datastar data-star.dev/reference/security · StardustDB stardustdb.com · PostgreSQL postgresql.org · Shopify shopify.dev/docs/api/usage/versioning, …/bulk-operations/queries, …/response-codes, …/rate-limits, shopify.dev/docs/api/customer · Cloudflare developers.cloudflare.com/cache/how-to/purge-cache/, …/error-524/, …/cloudflare-for-saas/plans/, blog.cloudflare.com/updated-tos/ · Hetzner hetzner.com/cloud · OrbStack orbstack.dev/pricing · Codespaces docs.github.com/en/billing/concepts/product-billing/github-codespaces
