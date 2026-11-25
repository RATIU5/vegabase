---
status: draft
updated: 2026-11-25
---

# Vegabase: Roadmap

> The order we build in, kept coarse on purpose. Each stage names what it proves and when it is done, not how. Stages change as we learn; the docs they cite own the detail.

## Next up

The next five tasks, in order. Take the top one; when it is done, delete it and add one at the bottom from the current stage.

1. Check pass: a name declared twice is an error naming both places (lang D-24). This adds a second span to `Error`.
2. Check pass: two `template` lines, a `template` line with no HTML, HTML with no `template` line (VEGA §5).
3. Check pass: at most one admin block, `fields` and `props` per declaration, moved out of the parser (VEGA-GRAMMAR §5).
4. Spike S-4: h2o from Odin, multi-threaded, shell plus SSE (STACK §7).
5. Check pass: every name resolves, to a declaration, a `use` library or a built-in (VEGA §2).

## Stages

| #   | Stage                     | Proves                                                           | Done when                                                                              |
| --- | ------------------------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 1   | Language toolchain        | Broken themes fail before activation (G2)                        | Every file in `specs/examples/` checks, and renders to HTML from fixture data         |
| 2   | Foundation spikes         | The pinned stack works from Odin (STACK §7)                      | S-1 to S-9 each pass, or a failed one has a D- or Q- entry that replaces it            |
| 3   | One page, end to end      | A request renders from local data only (P2)                      | A product page renders from a fixture read index through the request pipeline         |
| 4   | Our first store           | G1 on real data                                                  | One of our stores serves real catalog pages, and LCP and JS weight are measured        |
| 5   | The rest of 1.0           | CHARTER scope (1.0)                                              | Every 1.0 scope line works for our own stores                                          |

Stages 1 and 2 run side by side. Stage 3 needs the render part of stage 1 and spikes S-4 and S-5. Stage 4 needs S-9.

## Stage 1: language toolchain

- Done: scanner, lexer and parser in `source/vega/` (specs/VEGA-GRAMMAR.md).
- Next: a check pass that resolves names and reports the check errors in VEGA.md and VEGA-TEMPLATE.md, then type checking, then rendering.

## Stage 2: spikes, riskiest first

S-4 (h2o and SSE), S-5 (StardustDB), S-9 (Shopify bulk pricing), S-3 (wasmtime), then the rest. A failed spike can change ARCHITECTURE, so log the outcome in DECISIONS before building on it.

## Keeping this current

- Update the table when a stage finishes, a spike fails or the order changes.
- Add detail to a stage only when work on it starts, and keep that detail in the doc that owns it.
