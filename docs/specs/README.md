---
status: draft
updated: 2026-11-18
---

# Vegabase language specs: Start here

The `.vega` language is one file type for schema code and templates (lang D-16). It is one **edition** (GLOSSARY: Edition). These files are the single source of truth for its syntax and semantics. Mechanisms (parser, caches, sandbox) are in `docs/core/DESIGN.md`.

**Precedence**: CHARTER > DECISIONS > these specs > GLOSSARY > ARCHITECTURE > DESIGN = OPERATIONS > STACK. An Accepted D- entry binds the specs; a spec rule binds the glossary and every lower doc.

Edition: **draft** (no edition shipped yet). This is pass 1: it states only what is decided, and marks every other point *no entry* or *open*.

**Citations.** `lang D-59` and `lang Q-10` are entries of `docs/temp_lang_ctx/decisions.md`, until they move into `core/DECISIONS.md`. `core D-031` is an entry of `core/DECISIONS.md`.

## File map

| File             | Owns                                                                                                             | Read when                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| VEGA.md          | Files and blocks, names and `use`, brackets, types, components, fields, props, content types, locale tables, plugins | Declaring a type, a component or a content type |
| VEGA-TEMPLATE.md | Binding, tags, slots in a template, `$id`, expressions, output and escaping, whitespace                          | Writing or checking a template               |

Each fact lives in one file. Other files link to it by file and section (`VEGA §6.1`).

Worked examples: `docs/temp_lang_ctx/examples/` (fifteen `.vega` files) and `docs/temp_lang_ctx/examples.md`. Nothing has been parsed or run, and no grammar exists yet.

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

## Where these specs disagree with the core docs

Pass 1 follows the language decisions. These lower or older lines now disagree and need a ruling or a fix:

| Core line | Says | Specs say |
| --- | --- | --- |
| core D-029 | entity types come only from `std` or extensions | a theme may declare a `content` type (lang D-63, ruled 2026-11-18); D-029 needs amending |
| GLOSSARY: Type owner | the one extension that provides an entity type | open: who owns the entries of a theme's content type (VEGA §8) |
| GLOSSARY: Component replacement; core Q-045 | a theme component may take the place of a plugin component | not in this edition (lang D-64, ruled 2026-11-18) |
| GLOSSARY: Page kind, Storage class, Fallback view | `@page`, `@private`, `@fallback` | not in pass 1 (lang D-13, Q-11, Q-41) |
| GLOSSARY: Plugin, Extension | a plugin is always untrusted; an extension is "a vendor lib or plugin" | a vendor lib is a first-party plugin (lang D-66); the wording needs one pass, the rules agree (lang D-67) |
| core D-027 | the specs cover `.vegs` and `.vegt` | one file type, `.vega` (lang D-16) |
| core Q-013 | file extensions are open | `.vega` (lang D-16) |

## Open language questions

`docs/temp_lang_ctx/decisions.md`, section "Open questions", and each *Open* line in the two spec files. Q-035 to Q-049 in `core/DECISIONS.md` predate this rewrite and have not been checked against it.
