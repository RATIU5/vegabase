# Brief

Updated: 2026-11-09. Source: the project lead's starting context. Kept current; changes need a D- entry in decisions.md.

## What this is

Two small languages for a typed, SSR-first CMS: a template language and a schema language. Spec-only planning phase. Implementation comes later.

**The PoC question:** is this meaningfully better than Liquid? Nothing else.

## Audience

- Authors: Shopify and non-commerce devs who want control, performance and simplicity; agencies that need custom sections.
- Editors never write syntax. They only use UI generated from the schema.

## Power budget

- Templates are declarative and pure: same data in, same HTML out, no side effects.
- No user-defined functions. Variables are immutable. Loops iterate only over data.
- No IO in templates. Data needs are declared; the runtime fetches and caches them.
- Complex logic lives outside the core language. Plugins (Odin to WASM) only define data sources and transform data to and from the template; they add no filters and no schemas (D-6).
- One unit of composition: the component, with or without a slot (D-7).
- The language never names the CMS, only a host that supplies field values, loaders and page constants (D-28).
- Output is escaped by default, with an explicit opt-out: the type `std.RichText` (D-37). There is no `raw`.
- The schema language describes shape and validation only; no logic beyond simple constraints.
- A feature that can't be statically checked doesn't go in core.
- Schema code and templates share one file type, `.vega`; a component is one file or split (D-16). All code sits inside `{{ }}` (D-17).

## Principles, ranked

1. Simplicity over power.
2. Static checks over flexibility.
3. Explicit over implicit.
4. Compile-time over runtime.

Also:

- Errors point to the exact template line and schema field.
- One obvious way to do each thing.
- Implicit globals are allowed only if typed and visible in tooling.

## Non-goals

- Liquid compatibility or migration.
- Non-dev or no-code users.
- Turing-completeness.
- Client-side reactivity (hypermedia only).
- Shopify theme store compatibility.
- Checkout or cart logic.

## PoC success criteria

1. Render a realistic product page with nested sections from schema, template and sample data.
2. A type error shows the correct file, line and field.
3. Render-time or payload comparison against an equivalent Liquid page.
4. One working plugin.
5. A section schema produces a validated editing form definition.

## Process rules (from the lead)

- A construct enters a spec only if at least two distinct examples need it.
- No syntax without an example.
- Flag anything that adds IO, mutation, user-defined functions or Turing-completeness, or that can't be statically checked.
- Runtime and hosting choices stay out of the specs unless a PoC criterion needs them.
- Claims are labeled Decided (in a file), Proposed, or Speculation.
- Accepted entries change only with the lead's approval. Open questions are never assumed.

## Open questions

Tracked in decisions.md (Q-1 onward).
