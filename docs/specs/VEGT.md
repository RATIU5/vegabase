---
status: draft
updated: 2026-11-08
---

# Vegabase template language (.vegt)

Edition draft; index in README.md.

A small, typed template language. A template turns one schema type's data into HTML. `check` validates every template against its schema before a deployment can activate (COMMON §6).

A template renders. It does not declare data, types, caching or I/O: those live in the schema (VEGS.md, VEGS-DATA.md) and in the core, vendor libs and plugins. Shared rules (lexical tokens, `use`, expression grammar, directive syntax, `check` levels) are in COMMON.md and are linked, not repeated.

**Design rules** (beyond COMMON)

- Six tags, one output form, one comment form.
- A tag's kind (void or block) is fixed by its keyword, never by a slash.
- Rendering is pure: the same data gives the same output. No I/O, no side effects, no mutable state.
- Output is escaped for its context, and the template must parse as HTML5 (§8).

---

## 1. Templates and binding

A template file (`*.vegt`) holds markup plus tags. File name and location mean nothing. The first tag after the `use` tags, `{type Name}`, binds the file to one schema type (§4). That type is the template's **subject**.

- The subject's props and `data` fields are in scope by name (§6).
- A template cannot see the props of its slot children (§5.4); it renders them opaquely.
- The data layer resolves every `data` field before the template runs (VEGS-DATA §1, §2). A template never fetches.
- Templates carry no caching vocabulary. Neither `render` nor `slot` decides a component's cache class; the schema derives it (VEGS-DATA §5).
- A component whose `data` field has no acceptable value renders empty; the page still renders (VEGS-DATA §7).

---

## 2. Lexical

Shared tokens (strings, `Int`, `Decimal`, `Bool`, `null`, identifiers, qualified names): COMMON §3.

| Item        | Rule                                                                         |
| ----------- | ---------------------------------------------------------------------------- |
| Output      | `{expr}`                                                                     |
| Tag         | `{keyword ...}`, closed (block tags only) by `{/keyword}`                    |
| Comment     | `{# ... #}`, may span lines, never emitted                                   |
| Keywords    | `use type as if elif else for render slot in and or not true false null`     |

| Token | Meaning                                       |
| ----- | --------------------------------------------- |
| `{ }` | Opens and closes an output or tag             |
| `{/`  | Opens a block closer                          |
| `{#`  | Always starts a comment                       |
| `=`   | Names an argument value                       |
| `\|`  | Pipe                                          |
| `??`  | Fallback when a value is `null`               |
| `.`   | Field access, qualified name                  |
| `@`   | Directive                                     |

- Everything outside `{...}` is literal text, emitted unchanged. Whitespace is never altered, with one exception: a header tag (`use`, `type`) alone on its line emits nothing, line break included. Whitespace control: Q-041.
- A `{` followed by whitespace or a line break is literal text. To emit any other literal `{`, output a string: `{"{"}`. A `}` outside a tag is literal text.
- An expression never spans tags but may span lines inside one pair of braces.

---

## 3. Tags

Six keywords. Each is **void** (no closer) or **block** (always closed by `{/name}`).

| Tag                    | Kind          | Job                                               |
| ---------------------- | ------------- | ------------------------------------------------- |
| `type`                 | void          | Bind the template to its subject type (§4)        |
| `use`                  | void          | Import a namespace (§4, COMMON §2)                |
| `if` / `elif` / `else` | block         | Conditional (§5.1)                                |
| `for`                  | block         | Loop (§5.2)                                       |
| `render`               | void or block | Render a bound type (§5.3)                        |
| `slot`                 | void          | Output a slot field or the body (§5.4)            |

`elif` and `else` are separators inside an `if` (and `else` inside a `for`), not tags: they have no closer. An unclosed block, a stray separator or closer, or a misspelled keyword is an error.

---

## 4. Header: `use` and `type`

A template starts with zero or more `use` tags, then exactly one `type` tag. Only comments and whitespace may sit between or before them.

```
{use shopify}
{use shopify as shop}
{type Hero}
```

**`use`** follows COMMON §2: it imports a namespace; qualified references (`shopify.money`, `shopify.cart`, `t(...)` keys from another namespace) need it; `use theme` is an error; an unused `use` is a warning.

**`type`** names the subject. Binding rules:

- `Name` is a bare `Upper` identifier. It resolves in the file's own namespace only. A theme template cannot bind a `std` or extension type.
- A template may bind any record type that is not `@collection` or `@global`.
- A type is **placeable** in a slot only if it is a `@component` (VEGS §6.1). A plain record with a template can be rendered with `{render}` but not placed.
- A `@component` with no template is an error; the engine has no default template.
- Two templates for one type is an error. A template naming an unknown type is an error.
- `@page` and `@not_found` types bind templates the same way (VEGS-DATA §4). A `@page` template must not read `@private` data; move the read into a component (VEGS-DATA §5).

---

## 5. Tag reference

### 5.1 `if` / `elif` / `else`

```
{if product.compareAt > product.price}
  <s>{product.compareAt | shopify.money}</s>
{elif product.featured}
  <span>{t(badge.featured)}</span>
{else}
  <span>{t(badge.regular)}</span>
{/if}
```

- The condition is `Bool` or a nullable `T?`. Truthiness and narrowing: §7.1.
- There is no `unless`. Use `not`.

### 5.2 `for`

```
{for item in product.images}
  <img src="{item.src}" alt="{item.alt}">
{else}
  <p>{t(gallery.empty)}</p>
{/for}

{for item, i in product.images}
  <li class="n{i}">{item.alt}</li>
{/for}
```

- The source must be a list (lists are never null, VEGS §3). `item` is the element; the optional second name is the zero-based index (`Int`) over the items actually iterated.
- `{else}` renders when there is nothing to iterate: the list is empty, or `@offset`/`@limit` (§9) leave no items. Without `{else}`, an empty loop renders nothing.
- Loop variables are visible only inside the block and may not collide with a name in scope (§6).
- No default cap and no pagination. Shape iteration with `@limit`, `@offset`, `@reverse` (§9).
- Looping over slot children with a wrapper per child: Q-042.

### 5.3 `render`

Renders a type bound to a template. Arguments are named only and bind to the type's **props**.

```
{render Gallery(images = product.images)}
{render shopify.Stock(product = product)}

{render MaybeLink(link = product.vendorLink)}
  <h2>{product.vendor}</h2>
{/render}
```

- The target is a type with a template: a `@component`, or a plain record with a template. A `@page`, `@not_found`, `@collection` or `@global` type cannot be rendered. A template that renders itself, directly or through other `render` tags, is an error.
- **Void or block is decided by the target's schema.** Block `{render X(...)}...{/render}` is required iff `X` is `@yields` (VEGS §6.3); an empty body is allowed. Otherwise `render` is void with no closer.
- The body is evaluated in the caller's scope and reaches the target as its **body** (§5.4).
- Arguments are `name = expr` (COMMON §4). No positional arguments. An omitted prop takes its schema default.
- `check` verifies: the target exists and has a template, every argument names a prop, types match, every required prop is supplied, no prop is given twice. Slot and `data` fields cannot be passed.
- A `render` call does not leak the caller's names into the target. The target sees only its own fields and its namespace's `@global` fields (§6).
- `render` can add directives (`@name`) after its arguments (§9). It never sets the cache class.
- If a rendered component's `data` field has no acceptable value, that component instance renders empty (§1).

### 5.4 `slot` and body

```
{slot main}     {# the subject's slot field "main" #}
{slot}          {# the body passed by render...{/render} #}
```

- `{slot name}` outputs the subject's slot field `name`: its children in editor order, each rendered as its own component. `name` must be a slot field of the subject (VEGS §5).
- Bare `{slot}` outputs the **body**: the markup the caller wrote inside `{render X(...)}...{/render}`. It is valid only in a template whose subject is `@yields` (VEGS §6.3). The body is not a slot field.
- A slot is rendered opaquely. The template cannot read child props or branch on child types. Allowed children, count and ordering are enforced by the schema.
- `slot` takes no directives.

---

## 6. Scope and names

A name in an expression resolves, in order, to:

1. A loop variable of an enclosing `for`.
2. A prop or `data` field of the subject.
3. A field of a `@global` record in the template's own namespace (VEGS-DATA §6).

A `@global` field of another namespace is qualified (`shopify.cart`) and needs `use` (COMMON §2). The qualified form follows COMMON §4: a first part that is a namespace in scope is a qualified reference.

- Anything else is an error. There is no empty-string fallback.
- A **collision is an error**, not shadowing: a loop variable named like a name already in scope; a subject field named like an own-namespace `@global` field; a name equal to a namespace in scope.
- Slot fields are not values. They are reachable only through `{slot name}`.
- A `data` field of non-null type is always present: when its value is unacceptable the component renders empty instead of running the template (VEGS-DATA §7). A `data` field of type `T?` may be `null` and must be narrowed or defaulted before use (§7.1).
- A rendered component sees its own scope only (§5.3).

---

## 7. Template expressions

The grammar, calls, pipes, `??`, `in` and ordering rules are COMMON §4. Templates use the whole grammar, with these additions.

### 7.1 Truthiness and narrowing

- A condition (`if`, `elif`) must be `Bool` or `T?`. A nullable is true when non-null, false when `null`. `Text`, `Int`, `Decimal` and lists are never conditions: compare explicitly (`name != ""`, `length(items) > 0`).
- **Narrowing.** Inside a branch, a condition that tests a nullable for non-null (`{if x}`, `x != null`, joined with `and`) narrows `x` from `T?` to `T`. Narrowing does not carry into `elif` or `else`, nor through `or` or `not`.
- Field access on a nullable `T?` that is not narrowed is an error. `{x ?? ""}` gives a nullable `Text` a fallback.

### 7.2 `Ref(T)` traversal

`featured.title` reads a field of the entity a `Ref(T)` points to (VEGS §3).

- Each traversal adds to the fetch plan. The core caps traversal depth (DESIGN §5); `check` reports a template beyond the cap.
- A nullable `Ref(T)?` must be narrowed before traversal (§7.1).
- A dangling reference counts as no acceptable value: the `@fallback` rule of the field applies (VEGS-DATA §7).

### 7.3 Functions and built-ins

A function callable from a template is a `fn` (VEGS §4.4) implemented by the core or a vendor lib. A `fn` implemented by a plugin is an error in a template; it may be used in `@show` and `@validate` only. Loaders and actions are not callable from templates.

`check` verifies that the function exists, that a core or vendor lib implements it, that argument types match, and that a function with no parameters is not piped into.

**Built-in functions** (core, no `use`, names reserved). Shapes use built-in-only notation (`T[..]`, `Text | list`) that VEGS cannot declare; they are illustrative signatures, not declarations.

| Function          | Shape                                         | Job                                                          |
| ----------------- | --------------------------------------------- | ------------------------------------------------------------ |
| `upper` / `lower` | `(value: Text) -> Text`                       | Case                                                         |
| `truncate`        | `(value: Text, max: Int) -> Text`             | Shorten                                                      |
| `length`          | `(value: Text \| list) -> Int`                | Size                                                         |
| `first`           | `(value: T[..]) -> T?`                        | First item or `null`                                         |
| `join`            | `(value: Text[..], sep: Text = ", ") -> Text` | Join items                                                   |
| `t`               | `t(key.path) -> Text` (special form)          | Translate (§7.4)                                             |
| `url`             | `(page: PageType, ...) -> Text`               | Path of an entity page's canonical route (§7.5)              |

Domain functions (`money`, `date`, image helpers) are not built in. They come from `std` or a vendor lib and are used qualified with a `use` (`shopify.money`). Their set and shapes: Q-043.

### 7.4 `t(path)`

```
<p>{t(cart.empty)}</p>
```

- The argument is a dotted key path, not an expression, written as in the schema (`t(hero.label)`). It names a leaf of a locale table (VEGS §4.6). A key from another namespace starts with that namespace and needs `use`. Key rules are VEGS §7.5.
- It resolves for the request's language, then the default locale. In VEGS, `t()` resolves for the editor's admin language instead.
- An unknown key, or a key that ends at a group, is an error. Placeholders and plural forms: Q-036.
- Piping into `t` is an error.

### 7.5 `url(page = PageType, param = expr, ...)`

```
<a href="{url(page = ProductPage, handle = featured.handle)}">...</a>
```

- Returns the path, with market and language prefix, of the canonical route of an entity page type (VEGS-DATA §4). The path is a `Text` that goes through the URL-attribute check (§8).
- `page` is a page type name (qualified if from another namespace). The other arguments are exactly the page's `@route` params (VEGS-DATA §3), each of the param's type.
- A fixed page, a `@not_found` type or a non-page type as `page` is an error. Links to fixed pages come from `std.Link` props.
- If several routes map to the type, editors mark one canonical (VEGS-DATA §4). With none, `url` renders the not-found path and the core alerts.
- Piping into `url` is an error.

---

## 8. Output, escaping and HTML structure

This section is canonical for escaping. The mechanism (parser, sanitizer) is DESIGN §4.

`{expr}` outputs the value of `expr`.

**Allowed output types.** `Text`, `Int`, `Decimal`, and `std.RichText` in element content only. Any other type (a record, `std.Image`, a list) must be converted by a function or rendered through a component. A nullable value is narrowed (`{if x}`) or given a fallback (`{x ?? ""}`) before output.

**`std.RichText`** is sanitized by the core and wrapped in `data-ignore`. It is allowed only in element content, never in an attribute, tag or script. No function or syntax outputs unescaped `Text`.

**Contextual escaping.** The context is where the output sits in the HTML:

| Context                                             | Rule                                                                 |
| --------------------------------------------------- | -------------------------------------------------------------------- |
| Element content                                     | HTML-escaped                                                         |
| Quoted attribute value                              | Attribute-escaped                                                    |
| URL attribute (`href`, `src`, `action`, `formaction`, others the core lists) | Attribute-escaped, then the final value is checked against the core scheme allowlist. A failing value emits an empty attribute value |

**Errors.** Output inside any of these is a `check` error:

- a tag name, an attribute name, or an unquoted attribute value
- an `on*` attribute
- `<script>` or `<style>`, or a `style` attribute
- a Datastar expression attribute (a `data-*` attribute Datastar evaluates)

Values enter Datastar signals through `data-signals`: Q-048.

**URL attributes.** The URL-attribute check applies to every value placed in a URL attribute, whatever its source. `<a href="{link.url}">` with `link: std.Link` is valid: `link.url` is `Text` in a URL attribute, so the core allowlist runs on the final value at render, and a `javascript:` value emits `href=""`. A static prefix (`href="/p/{slug}"`) is allowed and the check runs on the joined value. Prefer `url(...)` (§7.5) for entity pages.

**HTML5 structure.**

- The template must parse as HTML5. A structure a browser would re-parent (a `<div>` inside a `<p>`, a `<tr>` outside a table) is an error.
- Each block tag's body must contain balanced elements: every element opened inside an `if`, `elif`, `else`, `for` or `render` body closes inside the same body.

---

## 9. Directives

Syntax and rules: COMMON §5. A directive decorates a tag. It never produces a value.

- **Placement.** Trailing on a tag, after its arguments, before the closing `}`: `{for item in list @limit(4)}`.
- **Targets.** A template directive is declared with `directive ... on for | render` (VEGS §4.5). Only the core and vendor libs may declare one; a theme or plugin declaration is an error.
- Arguments are expressions in the tag's scope, so `@limit(pageSize)` is valid.
- An unknown directive, a directive on a tag it does not list, or a bad argument is an error.

**Core directives** (all target `for`)

| Directive          | Meaning                                                                        |
| ------------------ | ------------------------------------------------------------------------------ |
| `@limit(n: Int)`   | Iterate at most `n` items. `n` below 0 is an error; 0 renders nothing          |
| `@offset(n: Int)`  | Skip the first `n` items                                                       |
| `@reverse`         | Iterate in reverse order                                                       |

- Applied in a fixed order, however written: `@reverse`, then `@offset`, then `@limit`.
- There is no `@sort` or filter. Ordering and selection belong in the schema or a `fn`.

```
{for item in product.images @offset(1) @limit(4)}
  <img src="{item.src}" alt="{item.alt}">
{/for}
```

---

## 10. `check` rules

Levels: COMMON §6. All template rules are Error or Warning; none is Content. Each row: phrase and the section that states it.

**Error**

| Rule                                                                                   | §              |
| -------------------------------------------------------------------------------------- | -------------- |
| `use` after other content; `type` before a `use`; missing or second `type`            | §4             |
| `use theme`; unknown or duplicate `use`; qualified reference with no `use`            | COMMON §2      |
| Unknown type; two templates for one type                                               | §4             |
| Subject is `@collection` or `@global`                                                  | §4             |
| `@component` with no template                                                          | §4             |
| `@page` template reads `@private` data                                                 | §4             |
| Unclosed block; stray `elif`, `else` or closer; misspelled keyword                    | §3             |
| Unresolved name or field                                                               | §6             |
| Name collision (loop variable, subject field vs `@global` field, namespace name)       | §6             |
| `if` condition not `Bool` or `T?`                                                      | §7.1           |
| Field access on an un-narrowed nullable; `Ref(T)?` traversal without narrowing        | §7.1, §7.2     |
| `Ref` traversal beyond the core depth cap                                              | §7.2           |
| Type mismatch; ordering on non-numbers; float literal; `??`, `in` misuse              | COMMON §3, §4  |
| Loop source not a list                                                                 | §5.2           |
| `render` target unknown, without a template, a page, `@not_found`, `@collection` or `@global` | §5.3    |
| `render` argument unknown, duplicated, positional or mistyped; required prop missing; slot or `data` field passed | §5.3 |
| `render` cycle                                                                         | §5.3           |
| Block `render` of a type that is not `@yields`; void `render` of one that is          | §5.3           |
| `{slot name}` where `name` is not a slot field of the subject                         | §5.4           |
| Bare `{slot}` in a template whose subject is not `@yields`                            | §5.4           |
| Call to a plugin `fn`; unknown function; wrong arguments; pipe into a zero-parameter function, `t` or `url` | §7.3 |
| `t(...)` with an unknown key or a key that ends at a group                                   | §7.4           |
| `url(...)` with a non-entity-page `page`, or arguments not equal to its route params  | §7.5           |
| Output of a nullable or of a type other than `Text`, `Int`, `Decimal`, `std.RichText` | §8             |
| `std.RichText` outside element content                                                 | §8             |
| Output in a tag name, attribute name, unquoted attribute, `on*`, `<script>`, `<style>`, `style` or Datastar expression attribute | §8 |
| Template does not parse as HTML5; re-parented structure; unbalanced block body        | §8             |
| Unknown directive; directive on the wrong tag; bad directive argument; template directive declared outside the core or a vendor lib | §9 |

**Warning**

| Rule         | §         |
| ------------ | --------- |
| Unused `use` | COMMON §2 |

**Check output** (reported, never fails the check)

| Output                                                                                                              |
| ------------------------------------------------------------------------------------------------------------------- |
| Resolved slot sets: each slot's component set with identity and source file (`check --expand`, COMMON §6)           |
| Cache class per component, as derived from the schema (VEGS-DATA §5)                                                |
| Fixture renders: fixtures generated from the subject's schema (defaults, empty, null, min, max) are rendered; any error or panic fails the check |

---

## 11. Grammar

EBNF. `expr`, `narg`, `qident`, `literal`: COMMON §4. `TYPENAME` is an `Upper` identifier, `IDENT` a `lower` identifier.

```
template  = { use } type { node } ;
use       = "{" "use" IDENT [ "as" IDENT ] "}" ;
type      = "{" "type" TYPENAME "}" ;

node      = TEXT | output | comment | if | for | render | slot ;
output    = "{" expr "}" ;
comment   = "{#" { any } "#}" ;

if        = "{" "if" expr "}" { node }
            { "{" "elif" expr "}" { node } }
            [ "{" "else" "}" { node } ]
            "{/if}" ;
for       = "{" "for" IDENT [ "," IDENT ] "in" expr { dir } "}" { node }
            [ "{" "else" "}" { node } ]
            "{/for}" ;
render    = "{" "render" qname "(" [ narg { "," narg } ] ")" { dir } "}"
            [ { node } "{/render}" ] ;   (* body iff the target is @yields *)
slot      = "{" "slot" [ IDENT ] "}" ;   (* bare form outputs the body *)

dir       = "@" qident [ "(" [ darg { "," darg } ] ")" ] ;
darg      = expr | IDENT "=" expr ;
qname     = [ IDENT "." ] TYPENAME ;
```

Template additions to COMMON §4: `primary` also accepts `tcall = "t" "(" IDENT { "." IDENT } ")"` (a key path, §7.4) and `urlcall = "url" "(" "page" "=" qname { "," narg } ")"`, because `page` takes a type name, not an expression (§7.5).

---

## 12. Example

Schema context, in prose: `SiteHeader` has props `logo: std.Image` and `links: std.Link[..]`; the theme declares `@global` `Site` with `siteName: Text`; `shopify` declares `@global` `cart` with `quantity: Int`. `MaybeLink` is `@yields` with `link: std.Link?`. `FeaturedProduct` has `featured: Ref(shopify.Product)?`. `ProductPage` is an entity page with `@route` param `handle`. `BlogPost` has `title: Text`, `body: std.RichText`, `cta: std.Link?` and a slot `main`.

```
{# SiteHeader.vegt #}
{use shopify}
{type SiteHeader}
<header>
  <img src="{logo.src}" alt="{siteName}">
  <nav>
    {for link, i in links @limit(6)}
      <a class="n{i}" href="{link.url}">{link.label}</a>
    {/for}
  </nav>
  <span>{t(header.cart)}: {shopify.cart.quantity}</span>
</header>
```

`siteName` is an own-namespace `@global` field (§6). `shopify.cart` is qualified and needs `use shopify`. `link.url` is `Text` in a URL attribute: the core allowlist checks it at render (§8).

```
{# MaybeLink.vegt #}
{type MaybeLink}
{if link}
  <a href="{link.url}">{slot}</a>
{else}
  {slot}
{/if}
```

`{if link}` narrows `link` from `std.Link?` to `std.Link`. Bare `{slot}` outputs the body; callers write a block `render`.

```
{# FeaturedProduct.vegt #}
{type FeaturedProduct}
{if featured}
  <article>
    <h2>{featured.title | truncate(max = 60)}</h2>
    <a href="{url(page = ProductPage, handle = featured.handle)}">{t(product.view)}</a>
  </article>
{/if}
```

`featured.title` traverses a `Ref(T)` and adds to the fetch plan (§7.2).

```
{# BlogPost.vegt #}
{type BlogPost}
<article>
  <h1>{title}</h1>
  {body}
  {render MaybeLink(link = cta)}
    <strong>{t(blog.cta)}</strong>
  {/render}
  {slot main}
</article>
```

`{body}` is `std.RichText` in element content: sanitized by the core (§8). The `render` is a block because `MaybeLink` is `@yields`.
