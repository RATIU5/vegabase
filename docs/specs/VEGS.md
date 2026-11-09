# VegaBase Schema Language (`.vegs`): Spec v0.13 draft

A small, typed schema language for a plugin-based, hypermedia-first CMS. One language describes **content shapes, page shapes, server data inputs, and function contracts**. A `check` step validates everything before publish. The admin UI is generated from the schema.

It is a typing and contract layer. It does not describe behavior: logic lives in Go.

**Design rules**

- The core is bare: four scalars and a reference. Everything else comes from an owner (`std`, a plugin, or your project) and is imported with `use`.
- Two sigils: `@` (directive) and `?` (nullable). Declarations use `::`, fields use `:`, values use `=`.
- One declaration shape: `Name :: ...`. One construction shape: `Type { field = value }`.
- Structure is words, decoration is directives: the field roles `slot` and `data` are keywords in type position; `@` directives only decorate or constrain.
- Values are pure literals. No variables, expressions (outside `@show`), floats, or I/O.
- The language has no file, folder, or name rules. Location carries no meaning.
- Extend by adding names, never by changing meanings.

---

## 1. Files and ownership

The host scans configured roots for `*.vegs` (schemas). Go files carry logic. Each `.vegs` file is a list of `use` lines followed by declarations. A file's name and location mean nothing to the language.

```
project/
  types.vegs
  pages.vegs
  locales/en.vegs
  plugins/shopify/
    shopify.go
    types.vegs
```

**Ownership.** The loader assigns every file an **owner**. This is a host rule, not a language rule.

| Owner    | Files                                 | Written as                                        |
| -------- | ------------------------------------- | ------------------------------------------------- |
| `app`    | the project's own files               | bare name in app files; `app.Name` from elsewhere |
| `std`    | first-party types shipped by the host | `std.Image`                                       |
| a plugin | files under that plugin               | `shopify.Product`                                 |

- In a file, a **bare name resolves to the file's own owner**, then to the core types.
- A name from any other owner is **qualified** (`owner.Name`) and needs a `use` line in that file (§2).
- Names are unique per owner **across all its files**. A duplicate is an error.
- Every declaration is visible to the whole project; there is no export keyword.
- `app` and `std` are reserved owner names. Plugins cannot use them. Redeclaring a core name is an error.
- To use a short local name for another owner's type, declare an alias: `Product :: shopify.Product` (needs `use shopify` in that file). The alias is an ordinary `app` declaration, so other app files write `Product` without `use shopify`.

**Types are typesafe components.** A record type's fields are its props. The admin form is generated from the fields.

**Identity.** Every type has one identity: `owner.Name` (`app.Hero`, `shopify.Hero`). Identity never depends on file or folder, so moving, copying, or deeply nesting a `.vegs` file changes nothing. A copy of `Testimonials` in a second file of the same owner is a duplicate-declaration error that names both file paths. The same name in two owners is two different types (`app.Testimonials`, `acme.Testimonials`). Stored content records the full identity, and the admin shows it (owner badge plus source path) wherever a component is picked or listed.

---

## 2. Imports: `use`

```
use std
use shopify
use shopify as shop
```

- `use` imports an **owner**, never individual names. Names stay qualified at each use site, so their origin is always visible.
- `use` lines come first in the file, before any declaration.
- `use` is **non-transitive**: it affects only the file it is in and is never re-exported.
- `as` is optional and renames the owner inside that file only. With `use shopify as shop`, write `shop.Product`.
- A `use` is **required** for every qualified reference to that owner in the file: types, functions, `t(...)` keys, and plugin directives.
- Core types and the file's own owner need no `use`. `use app` is an error.
- Unknown owner → error. Duplicate `use` → error. Unused `use` → warning.
- An alias must not collide with another owner or with a declared name in the file.

---

## 3. Lexical

| Item           | Rule                                                                                             |
| -------------- | ------------------------------------------------------------------------------------------------ |
| Comments       | `// to end of line`                                                                              |
| Separators     | Newline **or** comma, in bodies and lists. One-line forms need commas.                           |
| Strings        | `"..."`, escapes `\" \\ \n \t \uXXXX`                                                            |
| Int            | `42`, `-7`                                                                                       |
| Decimal        | `19.99d`, `0d`. Must end in `d`.                                                                 |
| Float          | **Not supported.** `1.5` is a lex error.                                                         |
| Bool / null    | `true` `false` `null`                                                                            |
| `Upper` ident  | `[A-Z][A-Za-z0-9]*`: type names                                                                  |
| `lower` ident  | `[a-z_][A-Za-z0-9_]*`: fields, fns, locales, owners, directives                                  |
| Qualified name | `owner.Name` or `owner.fn`                                                                       |
| Keywords       | `use as fn loader action directive on locale slot data any except and or not in true false null` |

**Casing carries meaning:** `Upper` declares a type (record, alias, union); `lower` declares a function (`fn`, `loader`, `action`), a directive, or a locale table.

After `on` in a directive declaration (§4), the words `field data alias type fn loader action` name targets. They are contextual and are not reserved elsewhere.

### Sigils and punctuation

| Token | Meaning                                               |
| ----- | ----------------------------------------------------- |
| `::`  | Declares a name (is defined as)                       |
| `:`   | Declares a type: field or parameter                   |
| `=`   | Assigns a value: default, record entry, locale string |
| `@`   | Directive                                             |
| `?`   | Nullable                                              |

---

## 4. Declarations

Every top-level item has the shape `Name :: ...`.

### Record type

```
Image :: {
  src:   Text
  alt:   Text
  width: Int? @min(1)
}
```

- The body holds **directive lines** first (they apply to the record), then **fields**.
- Empty `{}` is an empty record.

### Alias

```
Headline :: Text @max(80) @label("Headline") @hint("Shown as the banner H1")
Product  :: shopify.Product
```

- An alias names another type, optionally with directives.
- A field of the alias type inherits its directives. A field directive overrides the same one, except `@validate`, which accumulates (§7.4).

### Union

```
Tone :: "light" | "dark"
```

- A bare union is allowed only for string literals (an enum).

### Functions: `fn`, `loader`, `action`

The kind is visible in the declaration. It decides what the function may do and where it may be used.

```
money     :: fn(m: shopify.Money, locale: Text? = null) -> Text
productBy :: loader(handle: Text) -> shopify.Product?
addToCart :: action(product: Ref(shopify.Product), qty: Int = 1) -> shopify.Cart
clearCart :: action()
```

| Kind     | May do                                      | `->`     | Used for                                                      |
| -------- | ------------------------------------------- | -------- | ------------------------------------------------------------- |
| `fn`     | Nothing outside its arguments: pure, no I/O | required | `@show`, template expressions, `@validate(check = ...)`       |
| `loader` | Read-only I/O (database, network)           | required | Backing a `data` field with `@load`; `@validate(check = ...)` |
| `action` | Reads and writes                            | optional | Write endpoints invoked by the host. Not usable as a value    |

- Params: `name: Type [= default]`.
- Only `fn` is callable in templates and `@show`. Only `loader` can back a `data` field. Only `action` is a write endpoint. `@validate(check = ...)` accepts `fn` or `loader` (read-only).
- An `action` always has a name and may omit `->`. A function with no return value cannot be used as a value, in a default, in `@show`, or in `@validate`.
- Bodies are implemented by the host or a plugin (Go, or a guest language such as WASM). The schema declares the contract. The host links I/O capabilities by kind, so a pure `fn` has no way to reach the network or the database.
- A function with no registered implementation is a `check` error.
- In `@validate`, a function follows the **field-function contract**:
  - `@validate` functions return `Bool` (`true` = pass) or `Text?` (`null` = pass, text = the failure message, §7.4);
  - a param named `value` receives the field's own value, and its type must match the field;
  - every other param binds **by name to a sibling field** of the same record (type must match);
  - `data` fields cannot be bound (same rule as §7.3).
- In `@show`, calls use **named arguments** like any call in the expression grammar (§7.3). The implicit binding above is the one documented exception, and exists only for `@validate`.

### Directive

```
swatch :: directive on field | alias (format: "hex" | "rgb" = "hex")
store  :: directive on type (kind: Text)
```

- `name :: directive on target { | target } [ ( params ) ]` declares a directive. Targets are `field` (a prop or slot), `data`, `alias`, `type` (a record), `fn`, `loader`, `action`.
- Params are written like function params. A directive with exactly one param may be called positionally (`@max(80)`); otherwise arguments are named (`@swatch(format = "hex")`). No params, no parentheses (`@internal`).
- Any `Text` param accepts `t(...)`.
- The declaration is static and checked without running any plugin code. The behavior (validation, storage, processing) ships with the plugin as Go or WASM.
- Used as `@owner.name`. A bare `@name` resolves to the file's own owner, then to the core directives, the same as types.

### Locale table

```
// locales/en.vegs
en :: locale {
  hero = {
    label   = "Hero banner"
    hint    = "Full-width banner with heading and CTA"
    heading = { label = "Headline" }
  }
}
```

- `name :: locale { ... }` declares one language's strings. The name is a `lower` ident (`en`, `fr`, `pt_BR` for `pt-BR`).
- The body is a tree: `name = "string"` leaves and `name = { ... }` groups. **Leaves are strings only.**
- Tables with the same language name merge by key path across all files of an owner. A duplicate key path is an error.
- Looked up by `t(...)` (§7.5).

---

## 5. Types

### Core types (the entire core)

| Type      | Notes                                                                                           |
| --------- | ----------------------------------------------------------------------------------------------- |
| `Text`    | UTF-8 string                                                                                    |
| `Int`     | 64-bit integer                                                                                  |
| `Decimal` | Exact decimal, no floats                                                                        |
| `Bool`    |                                                                                                 |
| `Ref(T)`  | Stored identifier of a `@collection` type or a plugin-registered type; the admin shows a picker |

The core defines **no content types and no commerce types**. They come from `std`, a plugin, or the project.

### `std` (first-party owner, shipped by the host)

| Type           | Shape (illustrative)                                |
| -------------- | --------------------------------------------------- |
| `std.Image`    | `src: Text`, `alt: Text`, `width: Int?`             |
| `std.Link`     | `url: Text`, `label: Text`                          |
| `std.RichText` | structure owned by `std` (for example `html: Text`) |

`std` is ordinary: it is an owner that follows every rule here. A project can ignore it and define its own `Image`.

### Type forms

| Form             | Meaning                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------ |
| `T`              | Required, non-null                                                                         |
| `T?`             | Nullable. Absent = `null`                                                                  |
| `"a" \| "b"`     | Union of string literals (enum)                                                            |
| `T[0..3]`        | List with min..max items. `[1..]` open-ended, `[..5]` no minimum, `[..]` any               |
| `(A \| B)[0..3]` | List of a union of record types. **Union must be parenthesized.** Only valid after `slot`. |
| `any[0..6]`      | List of any component. Only valid after `slot`. Narrowed with `any(...)` (§6.1)            |
| `Ref(T)`         | Reference to `T`                                                                           |

- Lists are **never null**: empty = `[]`. `T[0..3]?` is an error.
- A list binds to the nearest atom or parenthesized group.

---

## 6. Fields

```
name: [slot | data] Type [= default] [@directive ...]
```

A field is exactly one of three kinds. The kind is always visible right after the colon.

| Kind     | How it looks                    | Meaning                                                   |
| -------- | ------------------------------- | --------------------------------------------------------- |
| **Prop** | `name: Type`                    | Set by editors                                            |
| **Slot** | `name: slot (A \| B)[0..3]`     | Child area: editors add, order, and remove components     |
| **Data** | `name: data Type @load(loader)` | Resolved by the server, read-only, never in the editor UI |

```
Hero :: {
  heading: Headline = "Welcome"
  content: slot (Button | Callout)[0..3] = [Button { label = "Shop now" }]
  product: data shopify.Product @load(shopify.productBy) @route("handle")
}
```

`slot` and `data` are **keywords**, not directives. Directives trail a field and decorate or constrain it; the role is structure, so it sits in type position, like `chan` or `map` in Go.

### Required fields (see also §6.1 for slot sets)

A prop is **required** when it has no `?`, no `=`, and is not a list with `min = 0`. A required field with no value **blocks publish** (it is not a compile error). A field hidden by `@show` skips the check.

### Slots

- `slot` must be followed by a list of **components**: a record type, a parenthesized union of them, or a slot set (§6.1).
- A slot is never null (`slot ...?` is an error). Its default is `[]`. `min > 0` with no default makes it required.
- A plain list of types (without `slot`) is an ordinary list, for example `Image[1..5]`, a gallery.

### 6.1 Components and slot sets

A **component** is a record type marked `@component`: it may be placed in slots. Unmarked records (`Seo`, `Image`) are plain values and never appear in a slot or in `any`. A component cannot also be `@page` or `@collection`.

```
Hero :: {
  @component
  @group(sections)
  ...
}
```

`@group(name)` is optional on components. It is an **owner-scoped tag** written in the declaration, not a folder. Groups are not declared anywhere else; a group exists when a component names it.

A slot's allowed children are one of:

| Form                                            | Allows                                  |
| ----------------------------------------------- | --------------------------------------- |
| `slot (A \| B)[0..3]`                           | exactly the listed components           |
| `slot any[0..6]`                                | every component in the project          |
| `slot any(in shopify)[0..6]`                    | every component of an owner             |
| `slot any(in app.sections)[0..6]`               | every component of an owner's group     |
| `slot any(except Button \| shopify.Cart)[0..6]` | everything except the listed components |
| `slot any(in app.sections, except Hero)[0..6]`  | combine: `in` first, then `except`      |

- `in X`: `X` is an owner (`shopify`) or `owner.group` (`app.sections`). An owner's own name never needs `use`; another owner does.
- `except` takes components, qualified like any name. Excluding a type outside the `in` set is a warning.
- A set is evaluated by `check` against all declarations, so adding a component to an owner or group extends every slot that selects it. Pin a slot to an explicit list when new components must not appear automatically.
- An empty set is an error. An explicit member that is not `@component` is an error.
- Default values still use `Type { ... }` and must be members of the set.

**Placeable vs renderable.** A record type with a bound template (§6.3) is **renderable** from templates. `@component` additionally makes it **placeable** in slots and visible in admin pickers. A `@component` with no bound template and no engine-provided default would render nothing in a slot, so that is a `check` error. A dev-only partial needs no new directive: it is a plain record with props and a template, and optionally `@internal`.

**`@yields`.** A record directive for a type whose template accepts markup from its caller:

```
MaybeLink :: {
  @component
  @yields
  link: std.Link?
}
```

- `@yields` has no admin UI and stores no data. It is not a `slot`: a `slot` is editor-placed component content, whereas a yielded body is template markup supplied by the caller.
- An editor-placed `@yields` component simply gets an empty body.
- It lets `check` verify that templates pass a body to yielding types only, and not to others. Valid on any record type.

### 6.2 Composition and `@internal`

Composition needs no extra syntax:

- **Nesting:** a field's type can be any record (`seo: Seo`, `cta: std.Link`). Shared field sets are a record used as a field.
- **Aliases:** `Headline :: Text @max(80)` shares one field type with its directives.
- **Slots:** components inside components (§6.1).

**Flattening** copies another record's fields into this one with no nesting level:

```
BasePage :: {
  seo:    Seo
  header: Header
  footer: Footer
}

MarketingPage :: {
  @page
  ..BasePage
  main: slot any(in app.sections)[1..]
}
```

Flattening is strict. It is a line holding only `..Name`:

- **Fields only.** The fields arrive exactly as declared, with their own types, defaults, directives, and roles (`slot`, `data`). The record-level directives of the source (`@page`, `@component`, `@collection`, `@label`, `@internal`, and so on) are **not** copied.
- **No directives on the line**, no renaming, no picking, no overriding. `..BasePage @label("x")` is a syntax error.
- A field name that collides with another field or another spread is an error.
- The source must be a record type, qualified as usual (`..shopify.Base`, needs `use`), and cannot be `@internal` to another owner. Spreads cannot be cyclic.
- Field order follows the position of the spread line.
- The result is flat: stored data has no trace of `BasePage`. `check --expand` prints each field's source type.
- `data` fields come along and are checked against the including record's `@page` route.

If one field needs a change, write it out in full or use nesting.

`@internal` limits who may use a name:

```
Seo :: {
  @internal
  title: Text @max(60)
}
```

- A type or function marked `@internal` can be referenced only by declarations of its **own owner**. A reference from any other owner is an error.
- An internal component never appears in another owner's `any` set, and an explicit mention from another owner is an error. It still appears in slots of its own owner.
- Internal stays valid inside shared data: a public type may have a field of an internal type, so the plugin can expose a type without exposing its parts. Other owners cannot name that type but can read or edit the value through the field.
- Unmarked records that are not `@component` are already unplaceable in slots. `@internal` is about visibility to other owners, not placement.
- It is a visibility marker, not access control (§9).

**Origin stays visible.** Folders mean nothing, so origin is the owner:

- Explicit names are qualified (`shopify.Hero`), so a reader sees the owner in the source.
- `any(in ...)` names the owner or group in the source.
- Stored children keep their full identity (`app.Testimonials`), so a copied or nested `Testimonials` is never ambiguous.
- `vegs check --expand` prints each slot's resolved set with identity and source file. The admin picker groups by owner and group, and shows each item's source path on hover.

### Data

```
product: data shopify.Product @load(shopify.productBy) @route("handle")
```

- Exactly one `@load(loader)`: a declared `loader` (§4) that produces the value. The loader's return type must equal the field type.
- **Parameters.** Each loader param binds **by name** to a `@route` param. A param with a default may be left unbound. A param with no default and no matching `@route` is an error. `@route("name")` may appear more than once on a field.
- A `@route` param name must be a valid identifier, and the loader param it binds must be `Text` or `Int` (something a URL can carry).
- No `=` default. The UI directives `@label`, `@hint`, `@show` are errors on a data field.
- Non-null type: not found → 404. `Type?`: not found → `null`.
- A plugin supplies data by declaring a `loader`. There are no separate source directives.

### 6.3 Templates and types

Templates are specified separately. The schema only needs one rule: **a template binds to exactly one record type, and names that type in its own header** (for example `type Hero`, qualified through the template's own `use` lines).

- The `.vegs` side is unaware of templates; no name or folder rule is involved. Moving or renaming a template file changes nothing.
- A template naming an unknown type, or two templates naming one type, is a `check` error.
- "One schema per template" is therefore "one type per template". A `.vegs` file can still hold many types and functions.
- There is no per-component CSS directive. Styling uses the design system's classes.

### 6.4 Ambient data: `@context` and `@personal`

```
Site :: {
  @context
  settings: data SiteSettings @load(siteSettings)
    @cache(ttl = "10m")
}

cart :: loader() -> shopify.Cart @personal
```

- `@context` marks a record whose fields are **in scope in every template of its owner** (`site`, `market`, `request`, and so on). Plugins supply their own (`shopify.cart`), qualified and needing `use`.
- A `@context` record holds `data` fields only. They resolve with the ordinary data rules (`@load`, `@cache`, `@timeout`, `@fallback`) but have no URL, so every loader param needs a default. Field names must be unique across all `@context` records of one owner. A `@context` cannot be `@page`, `@collection`, or `@component`.
- `@personal` marks a loader (or a single `data` field) whose result depends on who is asking.
- **Personal data is never cached.** `@cache` on a `@personal` field, or on a `@page` or data type that reads one, is an error. This makes "personalized data never enters the shared cache" a compile-time rule.
- A personal field may be read only from an **island** (a template construct, specified separately). `check` fails any inline component that reads one.

---

## 7. Directives

One concept: a directive is a named instruction starting with `@`.

```
@name
@name(value)
@name(key = value, key = value)
```

### 7.1 Placement

- A directive **after a field or declaration on the same line** applies to it. Several may follow each other.
- A directive **line before the first field** of a record body applies to the **record**.
- A directive **line right after a field, alias, or function line** (with no other field between) **continues that field or declaration**.
- Parentheses, brackets, and braces may span lines.

```
Post :: {
  @collection("posts")                    // before the first field: applies to Post
  @label("Blog post")

  title: Text @max(120)                   // same line: applies to title
  slug:  Text
    @validate(pattern = "^[a-z0-9-]+$", message = "Lowercase letters, digits, dashes")
    @validate(pattern = "^[^-]", message = "Must not start with a dash")
}
```

### 7.2 Core directives

| Directive                           | Applies to                                                 | Meaning                                                                                |
| ----------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `@label(text)`                      | fields, types                                              | Editor title. Default: field name, title-cased                                         |
| `@hint(text)`                       | fields, types                                              | Small helper text, always visible under a field. On a type, the subtitle in pickers    |
| `@max(n)` / `@min(n)`               | `Text` → length; `Int`, `Decimal` → value                  | Bounds. Decimal arguments must be decimal literals                                     |
| `@validate(...)`                    | fields, aliases                                            | Pattern or function rule with optional message (§7.4)                                  |
| `@show(expr)`                       | non-data fields                                            | Show the field in the admin only when `expr` is true; `expr` may call functions (§7.3) |
| `@internal`                         | types, functions                                           | Usable only inside its own owner (§6.2)                                                |
| `@cache(ttl, stale?, vary?, tags?)` | `data` fields, `@page` and `@collection` types, data types | Cache the resolved value or page (§7.8)                                                |
| `@timeout("2s")`                    | `data` fields                                              | Max time for the loader (§7.8)                                                         |
| `@fallback(mode)`                   | `data` fields                                              | What to do when the loader fails: `"stale"`, `"null"`, `"error"` (§7.8)                |
| `@editor("route")`                  | fields, aliases, types                                     | Replace the generated input with a server route that renders it (§7.7)                 |
| `@load(loader)`                     | `data` fields                                              | The loader that produces the value (§6)                                                |
| `@route("param")`                   | `data` fields                                              | Binds a URL route parameter to the loader param of the same name (§6, §8)              |
| `@yields`                           | record types                                               | The template accepts a caller-passed body (§6.1)                                       |
| `@context`                          | record types                                               | Fields are ambient in every template of the owner (§6.4)                               |
| `@personal`                         | loaders, `data` fields                                     | Result depends on the requester; never cached (§6.4)                                   |
| `@component`                        | record types                                               | May be placed in slots (§6.1)                                                          |
| `@group(name)`                      | components                                                 | Owner-scoped tag for slot sets (§6.1)                                                  |
| `@page` / `@page("/route/{param}")` | record types                                               | Routable page (§8)                                                                     |
| `@collection("name")`               | record types                                               | Stored documents (§8)                                                                  |

Text arguments (`@label`, `@hint`, `message`) accept a string or `t(...)`.

Reserved, not yet active: `@private`, `@unique`, `@placeholder`.

### 7.3 Expressions

One expression grammar, defined here. `@show` uses it; the template language reuses it. `check` restricts what is in scope by context (for example, `data` fields and loops are not available in `@show`).

```
overlay:  Text? @show(tone == "dark")
ctaStyle: "solid" | "outline" = "solid" @show(cta != null and tone in ["light", "dark"])
discount: Decimal? @show(isWholesale(customer = customer))
bulk:     Text?    @show(qty > 5 and tone == "dark")
```

| Element    | Forms                                                                                                                               |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Comparison | `==`, `!=`, `<`, `<=`, `>`, `>=` (ordering on `Int`, `Decimal`, and `Text`), `in [list]`                                            |
| Logic      | `and`, `or`, `not`, parentheses                                                                                                     |
| Operands   | in-scope names, string, int, decimal, `true`, `false`, `null`                                                                       |
| Call       | `fnName(name = expr, ...)` or `owner.fnName(...)`: a declared `fn`. **Named arguments only.** A param with a default may be omitted |

- In `@show`, a bare name refers to a **sibling field** in the same record. `data` fields cannot be read.
- A call used as a condition must return `Bool`. It is usable with `and`, `or`, `not`. Only `fn` may be called (§4). The `value` param does not exist here: the field is not being validated.
- Qualified calls need `use`. The function needs an implementation.
- The admin may call it on every edit, so it must be fast. A call that errors or panics counts as `true` (field shown) and logs a warning.
- No arithmetic, `??`, or assignment.
- A hidden field skips the required check. Its stored value is kept.
- An unknown name, a type mismatch (`tone == 3`), or ordering on non-ordered types is an error.

### 7.4 `@validate`

```
slug: Text
  @validate(pattern = "^[a-z0-9-]+$", message = "Lowercase letters, digits, dashes")
  @validate(pattern = "^[^-]", message = t(errors.slug_start))
```

| Parameter | Meaning                                                                                                                                                         |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pattern` | Go RE2 regular expression the value must match. `Text` fields only                                                                                              |
| `check`   | A declared `fn` or `loader` following the field-function contract (§4), returning `Bool` or `Text?`. Any field type. Named bare, with the implicit binding (§4) |
| `message` | Text shown when the rule fails. String or `t(...)`. Optional: the host supplies a default. Not allowed with a `Text?` check                                     |

```
endDate: Int
  @validate(check = afterStart, message = t(errors.end_after_start))
slug: Text
  @validate(check = slugFree)

afterStart :: fn(value: Int, startDate: Int) -> Bool
slugFree   :: loader(value: Text) -> Text?  // reads the database; null = ok, text = the message
```

**Messages from a function.** A `check` that returns `Text?` supplies its own message. `null` passes (nullable already means "maybe nothing"), and any text fails with that text. The returned text is shown as-is, so the implementation picks the language. A `Bool` check uses `message`, then the host default.

- All parameters are optional, but **exactly one rule parameter** (`pattern` or `check`) is required per directive. `message` alone, both rules in one directive, or `message` with a `Text?` check is an error. Use two directives for two rules.
- `check` runs server-side and is authoritative. A `fn` is pure; a `loader` may read (for example a uniqueness lookup) but never write. A `check` error or panic fails validation with the host's default message.
- A `check` function is not evaluated while its field is hidden by `@show`.
- A field may carry **several** `@validate` directives. Each is an independent rule. All are evaluated in declaration order and each failing rule reports its own message.
- **Accumulates:** an alias's `@validate` rules and the field's own rules all apply.
- Enforced **server-side** on save and in the API. The admin shows messages inline.
- The server uses RE2. A browser's regex differs, so client-side checks are advisory and the server is authoritative.
- `@min` / `@max` remain the short form. They also drive widget hints such as character counters.
- Reserved for later, additively: `min`, `max`, and a cross-field `expr`.

### 7.5 `t(path)`: locale lookup

```
@label(t(hero.heading.label))
@hint(t(shopify.cart.title))
```

- `t` is a built-in call, valid only as the argument of a text parameter (`@label`, `@hint`, `message`). It is not allowed in defaults, which stay pure literals.
- The path walks `locale` tables. Keys of the file's own owner are bare; keys of another owner start with that owner's name, which needs `use`. The path must end at a string leaf; a group is an error.
- Resolved when the admin renders, for the editor's locale, then the project default locale. The default locale is project configuration, not part of the language.
- A key missing in the default locale is an error. Missing in another locale is a warning (falls back to the default).
- A top-level key group may not share a name with an owner.
- Plain strings remain valid: `@label("Headline")` is default-language text with no lookup.

### 7.6 Rules

- Every directive is **declared**: core directives by the host in the same `directive` syntax (§4), plugin directives in the plugin's `.vegs` files. A declaration fixes the targets and parameters.
- A directive takes one positional value (only if it has exactly one param) or named arguments, as its declaration says.
- **An unknown directive is an error.** A directive on the wrong target, or with bad arguments, is an error. None of this needs plugin code to run.
- Plugin directives are namespaced: `@shopify.swatch`, and need `use shopify`.
- A field's kind is set only by the words `slot` and `data`, never by a directive.

### 7.7 `@editor("route")`

By default the admin generates the input for each field from its type. `@editor` replaces that with a **server route** that renders the input.

```
Swatch :: Text @editor("/admin/widgets/swatch")

Hero :: {
  tone:  "light" | "dark" @editor("/admin/widgets/toggle")
  image: std.Image        @editor("/admin/widgets/image-crop")
}

Gallery :: {
  @editor("/admin/widgets/gallery")      // replaces the whole record form
  images: std.Image[1..12]
}
```

- **Replaces every generated input** for its target. On a field or alias, the whole input for that value (a record value gets one editor, not its sub-fields). On a type, the whole form of that record. No generated widget, no `@min` / `@max` widget hint (counter, stepper) is used.
- **What does not change:** the field's label, hint, and error messages still frame it; `@show` still decides visibility; `@validate`, types, and required rules are still enforced **server-side**. A custom editor cannot bypass validation.
- **Targets:** a field, an alias (every field of that alias inherits it; a field-level `@editor` overrides it), or a record type. One `@editor` per target. Not valid on `data` fields (they have no input).
- **The route** is an absolute path served by the host or a plugin, written as a string. It is a **URL, not a file**, so folders of widgets can live anywhere the host chooses (for example an `admin/` folder) without the schema knowing.
- `check` verifies the route is **registered** by the host or a plugin. An unregistered route is an error. It cannot verify that the fragment is correct.
- **Contract (illustrative):** the admin loads the route as a hypermedia fragment, passing the document id, the field path, the input `name`, and the current value. The fragment returns HTML whose inputs use that `name` (sub-fields as `name.sub`). Saves go through the normal form post, so the server validates and re-renders.
- Plugins may ship routes for their own types (`/shopify/admin/swatch`). Qualified names are not used, because a route is not a language name.

### 7.8 Server directives: `@cache`, `@timeout`, `@fallback`

```
Hero :: {
  product: data shopify.Product @load(shopify.productBy) @route("handle")
    @cache(ttl = "5m", stale = "1h")
    @timeout("2s")
    @fallback("stale")
}

BlogPost :: {
  @page("/blog/{slug}")
  @cache(ttl = "10m", vary = ["locale"])
  post: data Post @load(postBy) @route("slug")
}
```

| Directive                           | Meaning                                                                                                                                                                            |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@cache(ttl, stale?, vary?, tags?)` | `ttl`: fresh time. `stale`: how long a stale copy may be served while it refreshes. `vary`: extra cache-key parts (`"locale"`, or plugin-defined). `tags`: extra invalidation tags |
| `@timeout(duration)`                | Max time for the loader before it counts as failed                                                                                                                                 |
| `@fallback(mode)`                   | On failure or timeout: `"stale"` serve the cached copy, `"null"` return `null` (type must be `T?`), `"error"` fail the request (default)                                           |

- **Durations** are strings: `"30s"`, `"5m"`, `"1h"`, `"1d"`. `ttl` is required in `@cache`.
- **Targets:** `data` fields, and `@page` or `@collection` types. On a page, `@cache` caches the rendered response. On a record or alias used as a data type, `@cache` is the default for every `data` field of that type; the field's own `@cache` overrides it. On any other prop it is an error.
- **Cache key:** the loader params (the `@route` values) plus `vary`. `@personal` data is never cached (§6.4).
- **Invalidation:** entries are tagged `owner.Type` automatically, and saving a document of that type clears them. `tags` adds more, for plugins to clear from Go.
- `@fallback("stale")` needs a `@cache` (own or inherited) with `stale`.
- Rate limits, CDN headers, retries, and similar belong in plugin directives, not the core.

---

## 8. Pages and collections

A type has one of three roles, set only by directives:

| Role           | Directive                      | Meaning                                                        |
| -------------- | ------------------------------ | -------------------------------------------------------------- |
| Embedded value | none                           | Lives inside other records                                     |
| Stored entity  | `@collection("name")`          | Stored documents with an admin list view; makes `Ref(T)` legal |
| Routable page  | `@page` or `@page("/pattern")` | Appears under "New page"; one instance has one URL             |

- **A page type is separate from its routes.** Routes are created in the admin (pattern → page type). The type's **param set** is derived from the `@route` params of its `data` fields.
- `@page("/blog/{slug}")` gives only an optional **default pattern** for the "New page" flow. `@page` alone has no default.
- Admin-created routes are validated against the param set when saved, since `check` cannot see them: every `{param}` must be in the set, and every param in the set must appear.
- If a default pattern is present and its `{param}` names differ from the param set, `check` warns.
- `@route` param names must be valid identifiers, and each binds a `Text` or `Int` loader param (§6). A name used by several fields is one param with one type.
- A type has at most one of `@page`, `@collection`.
- A **layout** is just a page type whose fields are regions (`slot`) and data.
- Page types are the names that reverse routing uses (specified with templates).

---

## 9. Plugins

A plugin is an owner. It adds names; it never changes the language.

| A plugin can add            | How                                                                                                      |
| --------------------------- | -------------------------------------------------------------------------------------------------------- |
| Types                       | Declarations in its `.vegs` files, referenced `plugin.Name`                                              |
| Functions, loaders, actions | `fn`, `loader`, `action` declarations; bodies in Go or WASM, with I/O linked by kind                     |
| Directives                  | `directive` declarations in its `.vegs` files, namespaced `@plugin.name`; behavior shipped as Go or WASM |
| Contexts                    | `@context` records whose loaders it implements                                                           |
| Locale strings              | `locale` tables in its files                                                                             |

A plugin cannot add keywords, sigils, or syntax, redefine core types or directives, or declare in `app` or `std`.

**Access control is a plugin, not language.** The language defines no permissions. An access plugin declares namespaced directives (for example `@access.role("editor")` on types and fields, or `@access.owner`), whose Go handlers receive the user and the target and return allow, deny, or hide. Directive targets and arguments are checked by `check` like any other, and the admin and API call the plugin's hook. `@show` and `check` functions can also read the current user only if the plugin exposes it as a function (`access.can("publish")`).

A project with **no plugins and no `std`** uses the whole language: the five core types plus its own declarations under `app`.

---

## 10. `check` rules

| Level            | Rule                                                                                                                                                                                                                                                   |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Error            | Unresolved name; unknown owner; qualified reference with no `use` for that owner in the file; bare name that belongs to another owner                                                                                                                  |
| Error            | `use` after a declaration; duplicate `use`; `use app`; alias colliding with an owner or declared name                                                                                                                                                  |
| Error            | Duplicate declaration in an owner; redeclaring a core name; plugin using `app` or `std`                                                                                                                                                                |
| Error            | `Upper` declaration that is not a type, or `lower` declaration that is not `fn`, `loader`, `action`, `directive`, or `locale`                                                                                                                          |
| Error            | `fn` or `loader` with no `->`; function with no implementation; `action` or a function with no return value used as a value                                                                                                                            |
| Error            | `loader` or `action` called in `@show` or a template expression; `@load` naming a non-loader; `check =` naming an `action`                                                                                                                             |
| Error            | Default does not type-check; union default not a member; list default outside `[min..max]`; `null` on a non-nullable                                                                                                                                   |
| Error            | `T[..]?` (nullable list); `(A \| B)` not after `slot`; bare union of non-strings                                                                                                                                                                       |
| Error            | `slot` not followed by a list of components (or a union or slot set of them); `slot` on a nullable                                                                                                                                                     |
| Error            | Slot member (explicit, or default value) that is not `@component` or not in the slot's set; empty slot set; unknown owner or group in `any(in ...)`                                                                                                    |
| Error            | `@component` together with `@page` or `@collection`; `@group` on a non-component                                                                                                                                                                       |
| Warning          | `except` entry outside the `in` set                                                                                                                                                                                                                    |
| Error            | `data` with no `@load`, more than one, a `=` default, or a UI directive (`@label`, `@hint`, `@show`)                                                                                                                                                   |
| Error            | `@load` return type differs from the field type; loader param with no default and no matching `@route`; `@route` bound to a param that is not `Text` or `Int`, or with an invalid name                                                                 |
| Error            | `@load` or `@route` on a field that is not `data`                                                                                                                                                                                                      |
| Error            | `directive` declaration with an unknown target or duplicate param; directive used on a target it does not list                                                                                                                                         |
| Error            | Unknown directive; directive on the wrong target; bad directive arguments                                                                                                                                                                              |
| Error            | `@validate` with no rule parameter, only `message`, or both `pattern` and `check`, `message` with a `Text?` check; invalid RE2 pattern; `pattern` on a non-`Text` field                                                                                |
| Error            | `@show` call that is not a `fn` returning `Bool`; `check` function that returns neither `Bool` nor `Text?`; `check` param that is not `value` or a type-matching sibling name; call with a positional or missing required argument; `value` in `@show` |
| Error            | `@show` with an unknown name, type mismatch, ordering on unordered types, or reference to a `data` field                                                                                                                                               |
| Error            | Reference to an `@internal` name from another owner; `@internal` on a non-type, non-function                                                                                                                                                           |
| Error            | `@cache`, `@timeout`, or `@fallback` on a target they do not apply to; bad duration; `ttl` missing; `stale` shorter than `ttl`; `@fallback("null")` on a non-nullable; `@fallback("stale")` with no `stale` cache                                      |
| Error            | `@editor` route not registered, on a `data` field, or more than one on a target                                                                                                                                                                        |
| Error            | `Ref(T)` where `T` is not `@collection` or plugin-registered                                                                                                                                                                                           |
| Error            | `@component` with no bound template and no engine default; template naming an unknown type; two templates naming one type                                                                                                                              |
| Error            | `@context` that is not a record of `data` fields only, has a loader param with no default, repeats a field name within the owner, or is also `@page`, `@collection`, or `@component`                                                                   |
| Error            | `@cache` on a `@personal` field, or on a `@page` or data type that reads one; inline (non-island) read of a `@personal` field                                                                                                                          |
| Warning          | `@page` default pattern whose `{param}` names differ from the `@route` param set                                                                                                                                                                       |
| Error            | `@page` together with `@collection` on one type                                                                                                                                                                                                        |
| Error            | `..Name` of a non-record, cyclic, `@internal` to another owner, or colliding with a field name; directives on a `..` line                                                                                                                              |
| Error            | `t(...)` outside a text parameter; key not found in the default locale; key resolves to a group                                                                                                                                                        |
| Error            | Locale leaf that is not a string; duplicate key path for one language; key group named like an owner                                                                                                                                                   |
| Error            | Positional record entry; float literal                                                                                                                                                                                                                 |
| Warning          | Unused `use`; `t(...)` key missing in a non-default locale                                                                                                                                                                                             |
| Warning          | Field named like a reserved directive; redundant `= null`                                                                                                                                                                                              |
| Publish-blocking | Required prop or slot left empty (not a compile error)                                                                                                                                                                                                 |

---

## 11. Grammar (EBNF)

```
file      = { use } { decl } ;
use       = "use" IDENT [ "as" IDENT ] NEWLINE ;

decl      = TYPENAME "::" ( record | typeexpr { dir } { dirline } )
          | IDENT "::" ( "fn" | "loader" ) "(" [ param { "," param } ] ")" "->" typeexpr { dir } { dirline }
          | IDENT "::" "action" "(" [ param { "," param } ] ")" [ "->" typeexpr ] { dir } { dirline }
          | IDENT "::" "directive" "on" target { "|" target } [ "(" [ param { "," param } ] ")" ]
          | IDENT "::" "locale" "{" { lentry } "}" ;
target    = "field" | "data" | "alias" | "type" | "fn" | "loader" | "action" ;

record    = "{" { dirline } { field | spread } "}" ;
spread    = ".." qname NEWLINE ;
dirline   = NEWLINE dir { dir } ;
field     = IDENT ":" [ "slot" | "data" ] typeexpr [ "=" value ] { dir } { dirline } ;
param     = IDENT ":" typeexpr [ "=" value ] ;

typeexpr  = elem [ list ] [ "?" ] ;
elem      = atom | "(" atom { "|" atom } ")" | STRING { "|" STRING } | anyset ;
anyset    = "any" [ "(" [ "in" scope ] [ "," ] [ "except" qname { "|" qname } ] ")" ] ;   (* only after slot *)
scope     = IDENT [ "." IDENT ] ;
atom      = qname [ "(" typeexpr ")" ] | STRING ;
qname     = [ IDENT "." ] TYPENAME ;
list      = "[" [ INT ] ".." [ INT ] "]" ;

value     = STRING | INT | DECIMAL | "true" | "false" | "null"
          | "[" [ value { SEP value } ] "]"
          | qname "{" [ entry { SEP entry } ] "}" ;
entry     = IDENT "=" value ;

dir       = "@" qident [ "(" [ arg { "," arg } ] ")" ] ;
qident    = [ IDENT "." ] IDENT ;
arg       = value | tcall | qident | IDENT "=" ( value | tcall | qident ) | expr ;   (* bare qident: @load(f), check = f; expr only for @show *)
tcall     = "t" "(" IDENT { "." IDENT } ")" ;

expr      = andexpr { "or" andexpr } ;
andexpr   = notexpr { "and" notexpr } ;
notexpr   = [ "not" ] cmp ;
cmp       = operand [ ( "==" | "!=" | "<" | "<=" | ">" | ">=" ) operand | "in" "[" [ value { "," value } ] "]" ]
          | "(" expr ")" ;
operand   = IDENT | STRING | INT | DECIMAL | "true" | "false" | "null" | call ;
call      = qident "(" [ narg { "," narg } ] ")" ;
narg      = IDENT "=" expr ;

lentry    = IDENT "=" ( STRING | "{" { lentry } "}" ) ;
SEP       = "," | NEWLINE ;
```

---

## 12. Examples

### Project types (`types.vegs`, owner `app`)

```
use std

Headline :: Text @max(80) @label("Headline") @hint("Shown as the banner H1")

Button :: {
  @component
  label: Text @max(40)
  url:   Text = "/"
}

Callout :: {
  @component
  text: std.RichText
}
```

### A component (`Hero`)

```
use std
use shopify

Hero :: {
  @component
  @group(sections)
  @label(t(hero.label))
  @hint(t(hero.hint))

  heading:  Headline = "Welcome"
  body:     std.RichText?
  image:    std.Image = std.Image { src = "/placeholder.jpg", alt = "" }
  cta:      std.Link? = std.Link { url = "/", label = "Shop now" }
  tone:     "light" | "dark" = "light"
  featured: Ref(shopify.Product)?
  overlay:  Text? @show(tone == "dark")

  content:  slot (Button | Callout)[0..3] = [Button { label = "Shop now" }]

  product:  data shopify.Product @load(shopify.productBy) @route("handle")
}
```

### Locale files

```
// locales/en.vegs
en :: locale {
  hero = {
    label = "Hero banner"
    hint  = "Full-width banner with heading and CTA"
  }
}
```

```
// locales/fr.vegs
fr :: locale {
  hero = {
    label = "Bannière principale"
    hint  = "Bannière pleine largeur avec titre et bouton"
  }
}
```

### Pages and collections (`pages.vegs`)

```
use std
use shopify

Seo :: {
  title:       Text @max(60)
  description: Text? @max(160)
  image:       std.Image?
}

Post :: {
  @collection("posts")

  title:  Text @max(120)
  slug:   Text
    @validate(pattern = "^[a-z0-9-]+$", message = "Lowercase letters, digits, dashes")
    @validate(pattern = "^[^-]", message = "Must not start with a dash")
  author: Ref(Author)
  body:   std.RichText
}

MarketingPage :: {
  @label("Marketing page")
  @page

  seo:    Seo
  header: Header
  main:   slot any(in app.sections)[1..]       // every app component tagged sections
  footer: Footer
}

LandingPage :: {
  @page
  main: slot any(except Button | Callout)[0..]  // everything but small inline pieces
  shop: slot any(in shopify)[0..4]              // only shopify components
}

BlogPost :: {
  @label("Blog post")
  @page("/blog/{slug}")

  post:    data Post @load(postBy) @route("slug")
  sidebar: slot (Newsletter | Promo)[0..2]
  seo:     Seo
}

ProductPage :: {
  @page("/products/{handle}")

  product: data shopify.Product @load(shopify.productBy) @route("handle")
  main:    slot (Hero | Reviews | RelatedProducts)[0..]
  seo:     Seo
}
```

### Functions and an alias

```
use shopify
use intl

Product :: shopify.Product

money     :: fn(m: shopify.Money, locale: Text? = null) -> Text
postBy    :: loader(slug: Text) -> Post
addToCart :: action(product: Ref(shopify.Product), qty: Int = 1) -> shopify.Cart
clearCart :: action()
```

### A directive and a context

```
// plugins/shopify/types.vegs (owner shopify)
swatch :: directive on field | alias (format: "hex" | "rgb" = "hex")

Brand :: Text @swatch(format = "rgb")

// app: ambient data, available in every app template
Site :: {
  @context
  settings: data SiteSettings @load(siteSettings) @cache(ttl = "10m")
}
siteSettings :: loader() -> SiteSettings
```

---

## 13. Stored data and schema drift

Stored content is keyed by type identity (`owner.Name`) and field name. When the schema changes (a rename, a delete, a type change), old data no longer matches. The language has no rename syntax. The host detects drift instead and never deletes data on its own.

| Drift             | What the host finds                                                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------------ |
| **Unknown field** | A stored field name that the type no longer declares                                                   |
| **Unknown type**  | A stored document or slot child whose `owner.Name` no longer exists                                    |
| **Invalid value** | A stored value that fails its type (wrong kind, outside `@min` / `@max` / list bounds, not in a union) |

Where it shows:

- **On the document, in the admin.** An unknown field is still shown, read-only, under an alert: "Unknown field `heading`: not in the schema. Stored value: ...". An unknown slot child appears as a placeholder card ("Unknown component `app.Testimonials`") that holds its raw data. An invalid value is shown in its field with an alert and the stored value.
- **A hint, not a command.** The alert may list a likely match: an undeclared field of the same type on that record, or a similarly named type. The editor can copy the value across in the form, then delete the orphan. Nothing is moved automatically.
- **Project report.** `vegs check --data` lists each drift with its document count. The admin shows a project-level banner while any drift exists.
- **Publish.** Unknown fields and types are ignored when rendering. An invalid value blocks publish like an empty required field.
- **Cleanup is explicit.** Orphans are removed only by an editor deleting them in the admin, or a host-level cleanup the project runs on purpose.

## 14. Extension policy

Additive, never breaking:

- New directives, core types, declaration kinds, loaders, `@validate` parameters, and function features.
- Existing meanings never change. An unknown directive is always an error, so semantics are never silently ignored.

## 15. Open items

1. **Date and time types** (`std` or a plugin), and parameterized queries as data sources.
2. **`t(...)` parameters and plural forms**, and where the default locale is configured.
3. **Translating content values** (separate from editor labels).
4. **`@validate` extras:** `min`, `max`, and cross-field `expr` parameters.
5. **Reading the current user in `@show`:** left to access plugins (§9).
6. **Multiple groups per component** (`@group(a, b)`), and groups spanning owners.
7. **Per-slot-instance overrides** in the admin (for example hiding a component from one page).
8. **Template binding:** header-based (§6.3, current) versus a file-stem rule with an optional `@template("stem")` override. Header-based keeps `.vegs` free of name rules.
9. **Islands and reverse routing:** `check` rules that depend on the template spec (§6.4, §8) are listed here until that spec is final.
