---
status: draft
updated: 2026-11-18
---

# Vegabase language specs: Start here

The `.vega` language is one file type for schema code and templates (lang D-16). It is one **edition** (GLOSSARY: Edition). These files are the single source of truth for its syntax and semantics. Mechanisms (parser, caches, sandbox) are in `docs/core/DESIGN.md`.

**Precedence**: CHARTER > DECISIONS > these specs > GLOSSARY > ARCHITECTURE > DESIGN = OPERATIONS > STACK. An Accepted D- entry binds the specs; a spec rule binds the glossary and every lower doc.

Edition: **draft** (no edition shipped yet). The spec files state only what is decided, and mark every other point *no entry*, *reading* or *open*.

**Citations.** `lang D-59` and `lang Q-10` are entries of `docs/specs/DECISIONS.md`. `core D-031` is an entry of `core/DECISIONS.md`.

## File map

| File             | Owns                                                                                                             | Read when                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| VEGA.md          | Files and blocks, names and `use`, brackets, types, components, fields, props, content types, locale tables, plugins | Declaring a type, a component or a content type |
| BRIEF.md         | The PoC question and its five criteria, the power budget, the ranked language principles, non-goals, process rules | Judging whether a construct belongs in the language |
| DECISIONS.md     | The language decisions (`lang D-`), open questions (`lang Q-`) and prior art                                     | Before treating a language rule as settled   |
| EXAMPLES.md      | The example set, three check errors with their messages, the buy button in Liquid and in `.vega`                 | Showing the syntax or an error message       |
| VEGA-TEMPLATE.md | Binding, tags, slots in a template, `$id`, expressions, output and escaping, whitespace                          | Writing or checking a template               |

Each fact lives in one file. Other files link to it by file and section (`VEGA §6.1`).

Worked examples: `examples/` (fifteen `.vega` files) and EXAMPLES.md. Nothing has been parsed or run, and no grammar exists yet.

## Spec terms and glossary terms

| Spec term                            | Glossary term                    | Note                                                        |
| ------------------------------------ | -------------------------------- | ----------------------------------------------------------- |
| bare name                            | Theme                            | A name the theme declares (VEGA §2)                         |
| `std` prefix                         | Core                             | Types and functions the core ships                          |
| plugin prefix (`shopify`, `maps`)    | Extension (vendor lib or plugin) | A vendor lib is a first-party plugin (lang D-66, VEGA §10)  |
| `component` plus its template        | Component                        | VEGA §5                                                     |
| named union of components            | (replaces `@group`)              | VEGA §4.3                                                   |
| slot field                           | Slot                             | VEGA §6.1                                                   |
| prop filled by a loader              | Data need                        | VEGA §7                                                     |
| `$` value                            | Source role                      | VEGA §7                                                     |
| `$id`                                | instance ID (GLOSSARY: Fragment) | VEGA-TEMPLATE §4.3                                          |
| `content` type                       | Entity type                      | VEGA §8                                                     |
| function from the core or a first-party plugin | Transform              | VEGA §10                                                    |
| host                                 | —                                | Whatever supplies field values, loaders and `$` values (lang D-28) |

Banned in the specs: Go, island, document, partial, region, default slot, template-safe, publish (for content), bare owner.

## Where the core docs disagree with these specs

These specs outrank the lines below. Each line needs a fix in its own doc.

| Core line | Says | Specs say |
| --- | --- | --- |
| GLOSSARY: Plugin, Extension | a plugin is always untrusted; an extension is "a vendor lib or plugin" | a vendor lib is a first-party plugin (lang D-66) |
| GLOSSARY: Type owner | the one extension that provides an entity type | a theme may declare a content type; its owner is open (VEGA §8) |
| GLOSSARY: Entity, Namespace, Source role, Edition, Language toolchain, Theme | `@collection`, `theme.Hero`, `@route`, `@global`, `Ref(T)`, "template and schema languages", "default route patterns" | none of these exist in the language (VEGA §2, §12) |
| GLOSSARY: Page kind, Storage class, Fallback view, Cache class, Route | `@page`, `@private`, `@fallback`, `@cache` | not specified; open under lang Q-11 and Q-41 |
| ARCHITECTURE: seams, code map | "data fields"; separate `source/template/` and `source/schema/` | props filled by loaders (VEGA §7); one language (lang D-16) |
| DESIGN §6 | a plugin's WASM imports from vendor lib namespaces and uses vendor lib connectors | a plugin's code never calls another plugin (lang D-67) |
| OPERATIONS | a component's `unavailable` state | a loader that finds nothing gives the not-found page or null (lang D-38) |
| core D-028 to D-032 | the `theme` namespace, `{type Name}`, `@fallback`, `@cache`, COMMON §4 | each needs a pass against VEGA.md and VEGA-TEMPLATE.md |
| core Q-036 to Q-042 | open questions on `t(...)`, whitespace, slot loops, template locals | lang D-34, D-40 and D-62 answer three; lang Q-10 and Q-33 hold the rest |

## Open language questions

DECISIONS.md, section "Open questions", the *Open* points inside its entries, and each *Open* line in the two spec files.
