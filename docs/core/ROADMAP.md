---
status: draft
updated: 2026-11-25
---

# Vegabase: Roadmap

> The order we build in, kept coarse on purpose. Each stage names what it proves and when it is done, not how. Stages change as we learn; the docs they cite own the detail.

## Next up

The next five tasks, in order. Take the top one; when it is done, delete it and add one at the bottom from the current stage.

1. Load a theme: parse every `.vega` file in one folder into one checked set. Each error carries its file, and an error can point at a second place. `specs/examples/Map.vega` stays out until lang D-64 says how a file joins its plugin.
2. Spike S-9: one Shopify bulk query on a dev store, no Odin needed. Its result sets the ingestion design.
3. Declared twice (lang D-24): report both places, across components, content types and aliases. Locale tables wait until the spec says whether two tables for one locale merge or collide. Built-in names are left alone while that point is *Open*.
4. Template errors (VEGA §5, lang D-61): the four listed there, plus `template Name` naming a component the theme declares. What counts as HTML is not defined yet; propose it for lang D-61 first.
5. Resolve bare names: type names, union members and `render` targets, against theme declarations and the built-in types (VEGA §4.1). A prefixed name only needs a matching `use`.

## Waiting on the lead

These block later tasks; answer them before the task that needs them reaches "Next up". Never add anything that's considered scope-creep; when in doubt, you must ask the user.

| Item | Blocks |
| --- | --- |
| How a file joins its plugin (lang D-64 *Open*) | Checking `Map.vega` and plugin files |
| `std` built-ins (Q-043), site settings (lang Q-27), a `shopify` surface (no entry yet) | Type checking and rendering |
| PoC data sources and fixture format (lang Q-12) | Rendering in stage 1, and stage 3 |
| The local theme loop (Q-033), which decides where the renderer lives (D-012) | Rendering in stage 1 |
| Lease timing and where the generation check sits (Q-023) | S-5 |
| Index-backed vs request-time types (Q-010); where the deploy pipeline runs (Q-011) | Stage 3 |
| How stage 3 gets a composition before the admin app exists (no entry yet) | Stage 3 |
| How the host finds the shell component (lang Q-40) | Stage 3 |
| Which stores are ours (Q-002), then their baseline and G1 pass line (Q-001) | Stage 4 |

## Stages

| # | Stage | Proves | Done when |
| --- | --- | --- | --- |
| 1 | Check and render | A type error names the file, line and field; a page renders from sample data (BRIEF PoC 1, 2) | The theme in `specs/examples/` checks clean, a broken copy gives the three errors in specs EXAMPLES E-5, and a product page renders from fixtures |
| 2 | Foundation spikes | The pinned stack works from Odin (STACK §7) | Each spike passes before the stage that needs it, or a failed one has a D- or Q- entry that replaces it |
| 3 | One page, end to end | Renders read only local data (ARCHITECTURE quality goal 2) | A product page renders through the request pipeline from a read index in StardustDB loaded from fixtures, a composition and a fetch plan |
| 4 | First store, measured | G1 on real data | One of our stores serves real catalog pages on a preview host behind the CDN, with LCP and JS weight meeting the Q-001 pass line |
| 5 | Run our stores | Never-stop serving and fencing (D-018, OPERATIONS) | Our stores are activated on the engine, and a tenant move and a rolling upgrade happen without a failed request |
| 6 | The rest of 1.0 | CHARTER scope (1.0), D-013 | Every 1.0 scope line works |

Stages 1 and 2 run side by side, and each spike runs ahead of the stage that needs it:

- Stage 3 needs stage 1's renderer, S-1, S-4, S-5 and S-8. S-4 needs S-8, a pinned h2o commit (STACK §1) and the base image (STACK §4, TBD).
- Stage 4 needs S-9, S-2 (the Shopify vendor lib is a signed `.so`, DESIGN §7), S-6, and the store's theme ported to `.vega` (D-025). Its baseline is measured on the current theme before the store moves.
- Stage 5 needs S-7. Stage 6 needs S-3.

Stages 5 and 6 build their features in this order, named as in CHARTER "Scope (1.0)". Reorder when one of our stores needs something sooner.

Stage 5, run our stores:

1. Ownership, leases and fencing (D-018, Q-023)
2. Activation
3. Per-tenant logs and metrics (D-024)
4. Routes, redirects, and market and language URLs; their admin screens come in stage 6
5. SEO basics
6. Custom domains with our own certificates (D-021), behind the CDN
7. Shopify webhooks, cart, customer login and B2B context
8. Gates
9. Tenant moves, then rolling upgrades

Stage 6, the rest of 1.0:

1. The admin app and composer
2. Core content types: page, post, media (D-020)
3. Push fragments over SSE
4. Vendor libs and sandboxed WASM plugins (D-011)
5. Two supported editions with migrations
6. The distributable toolchain with its editor support (D-012)
7. The theme porting guide (D-025)

## Keeping this current

- Update this file when a stage finishes, a spike fails, the order changes or a "Waiting on the lead" item is answered.
- Add detail to a stage only when work on it starts, and keep that detail in the doc that owns it.
