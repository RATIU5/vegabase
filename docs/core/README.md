---
status: stable
updated: 2026-11-08
---

# Vegabase: Start here

Vegabase is a hosted, multi-tenant storefront and CMS engine in Odin that renders each tenant from one read index. Phase: design; `source/` is scaffolding. Read this file at session start, then follow the map.

## Doc map

| Doc             | Owns                                                                             | Read when                                                   |
| --------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| CHARTER.md      | Purpose, goals, scope, non-goals, assumptions, ranked principles, hard lines     | Judging scope, a tradeoff between principles, a hard line   |
| GLOSSARY.md     | Terms, banned synonyms, ambiguous words                                          | Naming anything, in docs or code                            |
| ARCHITECTURE.md | Parts, seams, key flows, invariants, quality goals, code map                     | Changing a part or seam, checking an invariant              |
| DESIGN.md       | Mechanism detail: runtime, themes, routing, data layer, plugins, vendor libs, databases | Designing or building a mechanism, C interop                |
| OPERATIONS.md   | Ownership and fencing, never-stop serving, moves, upgrades, purges, domains, security ops, observability | Anything about uptime, recovery, domains, secrets or metrics |
| STACK.md        | Pins, libraries, verified external facts, environment, workload, spikes          | Choosing a library or version, any Shopify, CDN or hosting fact |
| DECISIONS.md    | Decisions, open questions, risks, influences                                     | Before treating anything as settled; logging a ruling       |

**Precedence**: CHARTER > DECISIONS > GLOSSARY > ARCHITECTURE > DESIGN = OPERATIONS > STACK > this file's State section. When docs conflict, the higher one wins; flag the lower line that needs fixing. Each fact lives in one doc; cite it by doc and section or by ID: G, P in CHARTER; D, Q, R, I in DECISIONS; S in STACK.

Repo process (commits, PRs, releases) is in `docs/WORKFLOW.md`. Done means `mise run lint` and `mise run test` pass.

## How to work with me

- Break work into small tasks I can review one at a time.
- Give only the context a task needs. Don't restate my question or the docs; cite them.
- Leave template and schema syntax and concrete extension APIs undefined unless I ask; use a named placeholder.
- Push back on scope, mechanisms or coupling no charter goal needs, and name the goal it would serve (P7).
- Treat accepted D- entries as fixed, but flag real risks in them.
- Design boundaries explicitly (CDN vs access checks, StardustDB vs Postgres, local vs remote routing, CSP vs cached HTML); that is where the risk is.
- Explain C concepts in TypeScript or Odin terms on first use. I write strong TypeScript, some Odin and no C.
- Test my conclusions before agreeing: say what would make them wrong and where the docs disagree.
- When a wrong guess is costly, ask one question. Otherwise state your assumption and proceed.

## Knowing vs guessing

- Project facts come from the docs and the code. When neither answers, say so.
- Label claims: **Decided** (in a doc), **Proposed** (under discussion), **Speculation** (your inference), **External** (cited outside source), **Unverified** (claimed, no source found).
- Verify fast-moving facts before relying on them (STACK standing instructions): libh2o, wasmtime, StardustDB, Stellar CSS, Datastar, Shopify versions and limits, CDN limits, Odin packages and build modes.
- Open Q- entries have no answer; never assume one.

## Output

- Brief and direct: bullets, tables, short code; prose only where a list can't carry it.
- Concrete: Odin package layouts, data structures, ABI and table definitions, validator rules, SQL and StardustDB models.
- Prefer Odin; justify any C library with exact headers and functions, allocator hooks, ownership and threading.
- Tradeoffs in tables, each feature labelled 1.0 or never.
- Count external calls against the STACK §4 workload, with cold, warm and concurrent ranges.
- State guarantees as testable invariants with exceptions and failure behavior.
- Use glossary terms exactly; never an _Avoid_ word.

## Boundaries

- Fix typos and glossary drift in the docs on your own, and list what you changed.
- Propose anything substantive (scope, principle, term, architecture or decision) before making it.
- Keep each core doc under 150 lines.
- On "wrap up", run `/dream-07-state` against this file's State section; `/dream-chore-check` audits the docs. Both skills still expect the old 01–07 file layout until they are updated.

## State

- **Focus**: approve the rebuilt D-001 to D-010, then pin down what G1 needs (Q-001, Q-002).
- **Changed (2026-11-08)**: nine docs merged into seven; OPERATIONS.md added; D-018 to D-026 and Q-020 to Q-034 logged from a second audit; facts re-verified (STACK); D-011 to D-017 logged from the project lead's rulings; G5, P8 and a hard line on core-owned data added; R-004 and S-9 added.
- **In play**: Q-001 to Q-034, R-001 to R-004, S-1 to S-9. Proposed: G2, G4, the G3 signal, ranks of P5 and P6.
- **Next**: the project lead approves or corrects D-001 to D-010, then answers Q-002.
