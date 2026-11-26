---
status: draft
updated: 2026-11-25
---

# Vegabase: Roadmap

> The order we build in, kept coarse on purpose. Each stage names what it proves and when it is done, not how. Stages change as we learn; the docs they cite own the detail.

## Next up

The next five tasks, in order. Take the top one; when it is done, delete it and add one at the bottom from the current stage.

1. Load a theme: parse every `.vega` file in one folder into one checked set. Each error carries its file, and an error can point at a second place. `specs/examples/Map.vega` stays out until lang D-64 says how a file joins its plugin.
2. Declared twice (lang D-24): report both places, across components, content types and aliases. Locale tables wait until the spec says whether two tables for one locale merge or collide. Built-in names are left alone while that point is *Open*.
3. Template errors (VEGA §5, lang D-61): the four listed there, plus `template Name` naming a component the theme declares. What counts as HTML is not defined yet; propose it for lang D-61 first.
4. Resolve bare names: type names, union members and `render` targets, against theme declarations and the built-in types (VEGA §4.1). A prefixed name only needs a matching `use`.
5. Spike S-4, first slice: vendor h2o by commit, build it, and serve one static response from Odin.

## Waiting on the lead

These block later tasks; answer them before the task that needs them reaches "Next up". Never add anything that's considered scope-creep; when in doubt, you must ask the user.

| Item                                                        | Blocks                                             |
| ----------------------------------------------------------- | -------------------------------------------------- |
| How a file joins its plugin (lang D-64 *Open*)              | Checking `Map.vega` and plugin files               |
| `std` built-ins (Q-043), site settings (lang Q-27), a `shopify` surface (no entry yet) | Type checking and rendering |
| PoC data sources and fixture format (lang Q-12)             | Rendering in stage 1, and stage 3                  |
| How the host finds the shell component (lang Q-40)          | Stage 3                                            |
| Which stores are ours (Q-002), then their baseline (Q-001)  | Stage 4                                            |

## Stages

| #   | Stage                | Proves                                                       | Done when                                                                                           |
| --- | -------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| 1   | Check and render     | A type error names the file, line and field; a page renders from sample data (BRIEF PoC 1, 2) | The theme in `specs/examples/` checks clean, a broken copy gives the expected errors, and a product page renders from fixtures |
| 2   | Foundation spikes    | The pinned stack works from Odin (STACK §7)                  | S-1 to S-9 each pass, or a failed one has a D- or Q- entry that replaces it                         |
| 3   | One page, end to end | Renders read only local data (ARCHITECTURE quality goal 2)   | A product page renders through the request pipeline from a read index in StardustDB loaded from fixtures, a composition and a fetch plan |
| 4   | First store, measured | G1 on real data                                             | One of our stores serves real catalog pages on a preview host, with LCP and JS weight measured against its baseline |
| 5   | The rest of 1.0      | CHARTER scope (1.0), D-013                                   | Our stores are activated on the engine, and every 1.0 scope line works                                   |

Stages 1 and 2 run side by side. Stage 3 needs stage 1's renderer and spikes S-4 and S-5. Stage 4 needs S-9, and its baseline is measured on the current theme before the store moves. Serving real traffic (cart, domains, CDN), the admin app, plugins, editions, and the distributable toolchain with its editor support all sit in stage 5 until they are next.

## Keeping this current

- Update this file when a stage finishes, a spike fails, the order changes or a "Waiting on the lead" item is answered.
- Add detail to a stage only when work on it starts, and keep that detail in the doc that owns it.
