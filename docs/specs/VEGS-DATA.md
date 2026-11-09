---
status: draft
updated: 2026-11-08
---

# Vegabase schema language: data, pages and caching

Part of the `.vegs` spec; index in README.md. Shared rules (namespaces, `use`, directive syntax, expressions, `check` levels) are in COMMON.md. Declarations, types, fields, components and the other directives are in VEGS.md. Mechanisms (fetch plans, caches, fragments, status codes) are in `docs/core/DESIGN.md` §4-§5; this file links to them and never restates them.

## 1. Data fields

```
name: data Type @load(loader) [@route("param")...] [@cache(...)] [@timeout(...)] [@fallback(...)] [@private]
```

A `data` field is a **data need** (GLOSSARY). The theme declares what a component reads; the core resolves it (D-008). It never appears in the admin app's editor form (VEGS §5).

- Exactly one `@load(loader)`. The loader is a declared `loader` (VEGS §4.4). Its return type equals the field type.
- No `=` default. `@label`, `@hint`, `@show` and `@editor` on a `data` field are errors.
- Type `T`: no acceptable value is handled by `@fallback` (§7) or, for a route subject, by §4. Type `T?`: a missing value is `null`.
- A theme cannot declare a loader (VEGS §4.4). It names a loader of `std` or an extension: `@load(shopify.productBy)`.
- `@load` and `@route` are valid on `data` fields only.

A `data` field has one **source role** (GLOSSARY), set by what binds its loader parameters:

| Source role | Schema construct | Binds |
| --- | --- | --- |
| Route subject | `@route("param")` on the field (§3) | a URL parameter of the page |
| Tenant globals and request | a `@global` record (§6) | loader parameters that all have defaults |
| Entity-reference setting | a `Ref(T)` prop, set by an editor (VEGS §3) | an entity chosen in the admin app |

## 2. Loaders are read contracts

A `loader` declares what can be read and with which parameters. It is not a call made at request time.

- **Invariant: no loader runs per render.** The data layer serves every `data` field from the read index, then the shared cache, then the session cache (DESIGN §5). When a value is missing or stale, the data layer batches the missing keys into one resolver call per type owner. Template code and schema code never trigger a loader directly.
- The loader's `@load` target contributes to the **fetch plan** (GLOSSARY): the merged fields per entity type and context that a deployment's components and compositions need. The core computes it at deploy and on composition save.
- A loader implemented by a vendor lib or plugin is that extension's resolver for its entity types. A plugin loader runs in the sandbox only inside a batched resolver call (D-011); it is never on the render path.
- A loader has no side effects. Writes are `action`s (VEGS §4.4).
- `@validate(check = ...)` may call a `loader` (VEGS §7.4). That is an editor-time read in the admin app, not a render-time read.

## 3. `@route`

```
product: data shopify.Product @load(shopify.productBy) @route("handle")
```

- `@route("name")` binds the URL parameter `name` to the loader parameter of the same name. It may repeat on one field (several parameters).
- The name is a valid identifier. The loader parameter it binds is `Text` or `Int`: something a URL carries.
- A loader parameter with a default may stay unbound. One with no default and no matching `@route` is an error.
- A name used by several fields of one type is one parameter with one type.

**Components in slots.** A component may carry `@route` fields. When it is placed in a slot, its route parameters are read from the URL of the page that holds it. Therefore:

- A component's `@route` parameters must be a subset of the **param set** (§4) of the page type that holds it.
- The core checks this when an editor saves a composition. `check` also checks it at deploy for explicit slot lists (`slot (A | B)[0..3]`) and for `{render}` calls whose page type is known (VEGT §5.3). A violation is an Error at deploy and a Content error on save.
- A component with `@route` fields cannot be placed in a slot of a page type whose param set lacks them. A `slot any[..]` set is checked per placed instance on save only.

## 4. Pages and collections

A record type has one role, set by directives:

| Role | Directive | Meaning |
| --- | --- | --- |
| Value | none | Lives inside other records |
| Entity type | `@collection("name")` | A stored entity type; makes `Ref(T)` legal |
| Page type | `@page` or `@page("/pattern")` | Routable page |
| Not-found page | `@not_found` | The page served for unmatched URLs |
| Component | `@component` | Placed in slots (VEGS §6.1) |

A type has at most one of `@page`, `@collection`, `@not_found`, `@component`; any combination is an error. `@global` records also exclude all four (§6).

### Page kinds

The page kind (GLOSSARY) follows from the type:

| Page kind | Declared as | Served for |
| --- | --- | --- |
| Fixed page | `@page` type with no `@route` params | one editor-set URL |
| Entity page | `@page` type with `@route` params | the route subject named by the URL |
| Not-found | `@not_found` type | unmatched URLs and missing route subjects |

- There is no layout construct. A page type nests shared records or components (`header: Header`, VEGS §6.4).
- Plugin page kinds served through gates: Q-046.

### `@not_found`

- A record directive with no parameters. At most one type per theme carries it.
- The type has no `@route` data. It is served with status 404, or 410 when the route subject is tombstoned (DESIGN §4).
- A missing route subject on a `@page` type serves the `@not_found` page. Elsewhere, a `data` field with no acceptable value applies `@fallback` (§7).
- No `@not_found` type in a theme: the core serves its minimal built-in page and alerts (DESIGN §4).

### Routes and the param set

- A page type is separate from its routes. Editors create routes in the admin app (pattern to page type, D-009, D-017). `check` cannot see them.
- The type's **param set** is the union of the `@route` parameters of its `data` fields.
- `@page("/blog/{slug}")` takes one optional positional parameter: the default pattern offered by "New page". `@page` alone has none. A default pattern whose `{param}` names differ from the param set is a Warning.
- The admin app validates a route on save: every `{param}` in the pattern is in the set, and every parameter in the set appears.

### Canonical route

Several routes may map to one entity page type. An editor marks one **canonical**. The built-in `url(page = PageType, param = expr, ...)` returns the path of the canonical route, with market and language prefix (VEGT §7). With no canonical route, `url` renders the not-found path and the core alerts. Links to fixed pages come from `std.Link` props (VEGS §3), not from `url`.

### `@collection`

- `@collection("name")` declares an **entity type** (GLOSSARY). The declaring namespace is its type owner.
- It is valid only in `std` or an extension namespace. In `theme` it is an Error.
- `std` declares the core content types page, post and media (D-020). Their fields: Q-049.
- `Ref(T)` requires `T` to be a `@collection` type.

## 5. Cache class and `@fragment`

The **cache class** (GLOSSARY) of a component instance is derived from the schema (D-031). No directive is needed for the common cases.

| Derived from | Cache class |
| --- | --- |
| Reads no `@private` data, directly or through a `@private` global | part of the shell (cacheable, CDN) |
| Reads `@private` data | on-demand fragment, session-bound |

A component **reads** `@private` data when one of its own `data` fields, or a `@private` field of a `@global` record it uses, is private. A `@page` template must not read `@private` data. That is an Error: move the read into a component.

`@fragment(class?, push?)` on a `@component` may only **tighten** the derived class. It never loosens it.

| Parameter | Values | Meaning |
| --- | --- | --- |
| `class` | `"cached"`, `"on_demand"`, `"live"` | Minimum class. Order: shell, cached, on_demand, live. A value below the derived class is an Error |
| `push` | `true` | Opt in to push by read-set match (DESIGN §5). Default: pull |

- `"cached"` makes the component a cached fragment: signed endpoint, `s-maxage` (DESIGN §5). It cannot read `@private` data.
- Pull triggers (visibility, interval, interaction): Q-048.
- A component with `@fragment` and no `data` fields is valid; it renders the same, only its serving class changes.

## 6. `@global` and `@private`

### `@global`

```
Site :: {
  @global
  settings: data SiteSettings @load(std.siteSettings) @cache(ttl = "10m")
}
```

- Marks a record whose fields are in scope in every template of its namespace (VEGT §6).
- It holds `data` fields only. They follow the ordinary data rules (§1, §7) but have no URL, so every loader parameter has a default. Source role: tenant globals and request.
- Field names are unique across all `@global` records of a namespace.
- It cannot be `@page`, `@collection`, `@component` or `@not_found`.
- Another namespace's globals are qualified (`shopify.cart`) and need `use` (COMMON §2).
- A theme may declare `@global` records whose `data` fields load core or extension loaders.

### `@private`

- Valid on a `data` field or on a `loader` declaration. Marks the result as **storage class private** (GLOSSARY): per customer or per authorization.
- Private data never enters the read index, shared cache or CDN. The session cache holds it (DESIGN §5).
- `@cache` together with `@private` is an Error, on the field, on the loader, and on a `@page` type that reads private data.
- Reading private data makes a component an on-demand fragment (§5).
- Reserved, not active: `@unique`, `@placeholder`.

## 7. `@cache`, `@timeout`, `@fallback`

```
Hero :: {
  @component
  product: data shopify.Product @load(shopify.productBy) @route("handle")
    @cache(ttl = "5m", stale = "1h", vary = ["market", "language"])
    @timeout("2s")
    @fallback("stale")
}
```

| Directive | Targets | Meaning |
| --- | --- | --- |
| `@cache(ttl, stale?, vary?, tags?)` | a `loader` declaration, a `data` field, a `@page` type | Cache policy |
| `@timeout(duration)` | `data` fields, loaders | Longest wait for the value; after it, the value counts as not acceptable |
| `@fallback(mode)` | `data` fields | What to render when no acceptable value exists |

`@cache` is not valid on records, aliases or other props. Durations are strings: `"30s"`, `"5m"`, `"1h"`, `"1d"`.

### `@cache` parameters

| Parameter | Meaning |
| --- | --- |
| `ttl` | **Freshness window** (GLOSSARY). Required |
| `stale` | Extra time after `ttl` during which a stale value may be served. The **staleness limit** is `ttl + stale` |
| `vary` | Context dimensions the entry varies by: `"market"`, `"language"`, `"currency"`, `"channel"`, `"b2b_location"`. Never `"customer"` (that is `@private`, §6) |
| `tags` | Extra invalidation tags for extensions to purge |

- Invalidation tags `ns.Type` are added automatically; saving or ingesting an entity of that type clears the entries.
- **Tighten only.** The type owner's loader declares the default (`@cache` on the `loader`). A `data` field's `@cache` may only tighten it: a shorter `ttl` and a shorter `stale`. A longer value is an Error (DESIGN §5).
- On a `@page` type, `@cache` caches the rendered response for the shell.
- Rate limits, retries and CDN headers are not core directives; extensions declare them as directives (VEGS §8).

### `@fallback` modes

| Mode | Behavior |
| --- | --- |
| `"unavailable"` (default) | The component instance renders empty output, the page still renders, and the core logs an alert (D-018). Custom markup: Q-047 |
| `"stale"` | Serve the stale value. Needs a cache (own or the loader's) with `stale` |
| `"null"` | Render with `null`. The field type must be `T?` |

There is no `"error"` mode: the origin never returns an error page (D-018). The resulting **fallback view** is one of these three. A dangling `Ref(T)` counts as no acceptable value.

## 8. Compositions

A **composition** (GLOSSARY) is the slot contents an editor saves for a route, with setting values. It is stored data, not schema.

- The admin app validates a composition on save against the current schema: slot sets and counts (VEGS §5), prop types and bounds, `@route` subsets (§3), and the derived cache class (§5). A failure saves the composition as a draft that cannot be activated (Content level, COMMON §6).
- The core sets a **depth limit** for nested slots. Exceeding it on save is a Content error. The value is core configuration, not language.
- **Type cycles are allowed.** A component may allow itself or an ancestor in a slot (`Section` accepts `any`). The depth limit and per-composition checks bound the actual tree.
- `check` verifies the declared slot sets and `{render}` calls at deploy. It cannot see compositions (VEGS §6.1).
- On save, the core recomputes the fetch plan (§2). A composition that raises a read beyond plan limits fails save with a Content error (DESIGN §5).

## 9. Stored data and drift

Stored content is keyed by type identity (`ns.Name`) and field name (COMMON §1). A schema change (rename, delete, type change) leaves old data that no longer matches. The language has no rename syntax. The core detects drift and never deletes content on its own.

| Drift | What the core finds |
| --- | --- |
| Unknown field | A stored field name the type no longer declares |
| Unknown type | A stored entity or slot child whose `ns.Name` no longer exists |
| Invalid value | A stored value that fails its type: wrong kind, outside `@min`, `@max` or list bounds, not in a union |

- **In the admin app.** An unknown field is shown read-only under an alert with its stored value. An unknown slot child appears as a placeholder card holding its stored data. An invalid value shows in its field with an alert and the stored value.
- **A hint, not a command.** The alert may suggest a likely match: an undeclared field of the same type on that record, or a similarly named type. The editor copies the value in the form, then deletes the orphan. Nothing is moved automatically.
- **Theme report.** `check --data` lists each drift with its entry count (COMMON §6). The admin app shows a banner while any drift exists.
- **Rendering and activation.** Unknown fields and types are ignored when rendering. An invalid value is a Content error: the content stays a draft and cannot be activated, the same as an empty required field.
- **Cleanup is explicit.** An editor deletes orphans in the admin app, or the operator runs a cleanup on purpose.

## 10. `check` rules

References are to this file unless noted.

| Level | Rule | § |
| --- | --- | --- |
| Error | `data` field with no `@load`, more than one, a `=` default, or `@label`, `@hint`, `@show`, `@editor` | 1 |
| Error | `@load` or `@route` on a field that is not `data` | 1 |
| Error | `@load` return type differs from the field type | 1 |
| Error | `@load` names a non-loader, or a loader the theme declared | 1 |
| Error | Loader parameter with no default and no matching `@route` | 3 |
| Error | `@route` bound to a parameter that is not `Text` or `Int`, or with an invalid name | 3 |
| Error | Component `@route` parameter outside the param set of the page type that holds it | 3 |
| Error | More than one of `@page`, `@collection`, `@not_found`, `@component` on a type | 4 |
| Error | More than one `@not_found` type in a theme; `@not_found` with `@route` data | 4 |
| Error | `@collection` in the `theme` namespace | 4 |
| Error | `Ref(T)` where `T` is not a `@collection` type | 4 |
| Error | `@page` template reads `@private` data | 5 |
| Error | `@fragment` class below the derived class; `@fragment` on a non-component | 5 |
| Error | `@global` that is not a record of `data` fields only, has a loader parameter with no default, repeats a field name in its namespace, or is also `@page`, `@collection`, `@component` or `@not_found` | 6 |
| Error | `@private` on a target other than a `data` field or loader | 6 |
| Error | `@cache` on a `@private` field or loader, or on a `@page` type that reads private data | 6 |
| Error | `@cache`, `@timeout` or `@fallback` on a target they do not apply to; bad duration; `ttl` missing | 7 |
| Error | Field `@cache` looser than the loader's; unknown `vary` dimension | 7 |
| Error | `@fallback("null")` on a non-nullable; `@fallback("stale")` with no `stale` cache | 7 |
| Warning | `@page` default pattern whose `{param}` names differ from the param set | 4 |
| Content | Composition breaks a slot set, count, bound or depth limit; `@route` subset violated | 3, 8 |
| Content | Stored value fails its type (invalid value drift) | 9 |

Rules for declarations, types, slots, components, `@validate`, `@editor` and `t(...)`: VEGS §10. Template rules: VEGT §10.

## 11. Example

```
// theme namespace: types.vegs
use std
use shopify

Seo :: {
  title: Text @max(60)
}

Site :: {
  @global
  settings: data std.SiteSettings @load(std.siteSettings)
    @cache(ttl = "10m")
}

Header :: {
  @component
  cart: data shopify.Cart @load(shopify.cart) @private
}

Price :: {
  @component
  product: data shopify.Product @load(shopify.productBy) @route("handle")
    @cache(ttl = "1m", stale = "5m", vary = ["market", "currency"])
    @fallback("stale")
}

ProductPage :: {
  @page("/products/{handle}")
  @cache(ttl = "5m", stale = "1h")
  product: data shopify.Product @load(shopify.productBy) @route("handle")
  header:  Header
  main:    slot (Price | Gallery)[0..]
  seo:     Seo
}

HomePage :: {
  @page
  main: slot any[1..]
}

NotFound :: {
  @not_found
  heading: Text = "Page not found"
}
```

- `Header` reads `@private` data, so it is an on-demand fragment (§5). `ProductPage` itself reads none, so it stays a cacheable shell (§5, §6).
- `Price` sits in `ProductPage`, whose param set is `{handle}`; its `@route("handle")` is a subset (§3). Placing `Price` in `HomePage` (no params) is a Content error on save.
- `Price`'s `@cache` tightens the type owner's loader default (§7). The loader and the types come from `std` and `shopify`, not from the theme (VEGS §4.4).
- `NotFound` serves unmatched URLs with status 404 (§4).
