---
status: draft
updated: 2026-11-08
---

# Vegabase language specs: Start here

The schema language (`.vegs`) and template language (`.vegt`) are one **edition** (GLOSSARY: Edition). These files are the single source of truth for their syntax and semantics. Mechanisms (parser, caches, sandbox) are in `docs/core/DESIGN.md`.

**Precedence**: CHARTER > DECISIONS > these specs > GLOSSARY > ARCHITECTURE > DESIGN = OPERATIONS > STACK. An Accepted D- entry binds the specs; a spec rule binds the glossary and every lower doc.

Edition: **draft** (no edition shipped yet). File extensions are kept (Q-013).

## File map

| File         | Owns                                                                                          | Read when                                         |
| ------------ | --------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| COMMON.md    | Lexical rules, namespaces and `use`, the expression grammar and its subsets, directive syntax, `check` levels, extension policy | Reading or writing either language |
| VEGS.md      | Schema declarations, types, fields, components and slots, core directives, `@validate`, `t(...)`, `@editor`, schema `check` rules, grammar | Declaring types, components, functions or directives |
| VEGS-DATA.md | `data` fields, loaders, `@route`, pages and collections, `@global`, `@private`, `@cache`/`@timeout`/`@fallback`, cache class, stored data and drift | Anything that reads data, routes or caches |
| VEGT.md      | Template binding, tags, scope, template expressions, output and escaping, template directives, template `check` rules, grammar | Writing or checking a template |

Each fact lives in one file. Other files link to it by file and section (`VEGS §6.1`).

## Spec terms and glossary terms

| Spec term                          | Glossary term                         | Note                                                          |
| ---------------------------------- | ------------------------------------- | ------------------------------------------------------------- |
| namespace (`theme`, `std`, `shopify`) | —                                  | Never "owner"; "type owner" is a different concept           |
| `theme` namespace                  | Theme                                 | The tenant's theme files                                      |
| `std` namespace                    | Core                                  | Types, functions and directives the core ships                |
| extension namespace                | Extension (vendor lib or plugin)      | Shopify is a vendor lib (D-015)                               |
| `@component` record + template     | Component                             | VEGS §6                                                       |
| `@group(name)`                     | (replaces Kind `section`/`block`)     | VEGS §6.2                                                     |
| `@page` type                       | Page kind: fixed page or `entity`     | VEGS-DATA §4                                                  |
| `@not_found` type                  | Page kind: `not-found`                | VEGS-DATA §4                                                  |
| slot field                         | Slot                                  | VEGS §5                                                       |
| editor-saved slot contents         | Composition                           | VEGS-DATA §8                                                  |
| `data` field                       | Data need                             | VEGS-DATA §1                                                  |
| `@route` / `@global` / `Ref(T)` prop | Source role: route subject / tenant globals and request / entity-reference setting | VEGS-DATA §1 |
| `@collection` type                 | Entity type                           | Declared only by `std` or an extension (VEGS-DATA §4)         |
| `@private`                         | Storage class: private                | VEGS-DATA §6                                                  |
| `@cache(ttl, stale)`               | Freshness window, staleness limit     | VEGS-DATA §7                                                  |
| derived cache class, `@fragment`   | Cache class, Fragment                 | VEGS-DATA §5                                                  |
| template-callable `fn`             | Transform                             | Core or vendor lib only (VEGS §4.4)                           |
| `@fallback("unavailable")`         | Fallback view                         | VEGS-DATA §7                                                  |

Banned in the specs: Go, island, document, partial, region, default slot, template-safe, publish (for content), bare owner.

## Open language questions

Q-035 to Q-049 in DECISIONS.
