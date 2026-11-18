---
status: draft
updated: 2026-11-18
---

# Vegabase language specs: Start here

The `.vega` language is one file type for schema code and templates (lang D-16). It is one **edition** (GLOSSARY: Edition). These files are the single source of truth for its syntax and semantics. Mechanisms (parser, caches, sandbox) are in `docs/core/DESIGN.md`.

**Precedence**: CHARTER > DECISIONS > these specs > GLOSSARY > ARCHITECTURE > DESIGN = OPERATIONS > STACK. An Accepted D- entry binds the specs; a spec rule binds the glossary and every lower doc.

Edition: **draft** (no edition shipped yet). The spec files state only what is decided, and mark every other point *open*.

**Citations.** `lang D-59` and `lang Q-10` are entries of `docs/specs/DECISIONS.md`. `core D-031` is an entry of `core/DECISIONS.md`.

## File map

| File             | Owns                                                                                                             | Read when                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| VEGA.md          | Files and blocks, names and `use`, brackets, types, components, fields, props, content types, locale tables, plugins | Declaring a type, a component or a content type |
| BRIEF.md         | The PoC question and its five criteria, the power budget, the ranked language principles, non-goals, process rules | Judging whether a construct belongs in the language |
| DECISIONS.md     | The language decisions (`lang D-`), open questions (`lang Q-`) and prior art                                     | Before treating a language rule as settled   |
| EXAMPLES.md      | The example set, three check errors with their messages, the buy button in Liquid and in `.vega`                 | Showing the syntax or an error message       |
| VEGA-TEMPLATE.md | Binding, tags, slots in a template, `$id`, expressions, output and escaping, whitespace                          | Writing or checking a template               |
| VEGA-GRAMMAR.md  | The grammar of the code inside `{{ }}`, how to run it over the examples, and the choices it had to make             | Checking that a construct is well-formed     |

Each fact lives in one file. Other files link to it by file and section (`VEGA §6.1`).

Worked examples: `examples/` (fifteen `.vega` files) and EXAMPLES.md. Nothing has been parsed or run, and no grammar exists yet.

## Spec terms and glossary terms

| Spec term                            | Glossary term                    | Note                                                        |
| ------------------------------------ | -------------------------------- | ----------------------------------------------------------- |
| bare name                            | Theme                            | A name the theme declares (VEGA §2)                         |
| prefix (`std`, `shopify`, `maps`)    | Prefix                           | VEGA §2                                                     |
| plugin                               | Plugin, Extension                | A vendor lib is a first-party plugin (lang D-66, VEGA §10)  |
| `component` plus its template        | Component                        | VEGA §5                                                     |
| named union of components            | (replaces `@group`)              | VEGA §4.3                                                   |
| slot field                           | Slot                             | VEGA §6.1                                                   |
| prop filled by a loader              | Data need                        | VEGA §7                                                     |
| `$` value                            | Source role                      | VEGA §7                                                     |
| `$id`                                | instance ID (GLOSSARY: Fragment) | VEGA-TEMPLATE §4.3                                          |
| `content` type                       | Content type                     | VEGA §8                                                     |
| function from the core or a first-party plugin | Transform              | VEGA §10                                                    |
| host                                 | —                                | Whatever supplies field values, loaders and `$` values (lang D-28) |

Banned in the specs: Go, island, document, partial, region, default slot, template-safe, publish (for content), bare owner.

## Where the core docs disagree with these specs

These specs outrank the lines below. Each line needs a fix in its own doc.

| Core line | Says | Specs say |
| --- | --- | --- |
| core D-028 to D-032 | the `theme` namespace, `{type Name}`, `@fallback`, `@cache`, COMMON §4 | each needs a pass against VEGA.md and VEGA-TEMPLATE.md |
| core Q-036 to Q-042 | open questions on `t(...)`, whitespace, slot loops, template locals | lang D-34, D-40 and D-62 answer three; lang Q-10 and Q-33 hold the rest |
| core Q-044, Q-045 | "global settings" in the manifest; "namespace collision rules" | there is no `global` (lang D-35); the term is prefix (VEGA §2) |

## Open language questions

DECISIONS.md, section "Open questions", the *Open* points inside its entries, and each *Open* line in the two spec files.
