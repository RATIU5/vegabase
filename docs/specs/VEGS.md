---
status: draft
updated: 2026-11-08
---

# Vegabase schema language (.vegs)

Edition draft; index in [README.md](README.md). Shared rules (namespaces, `use`, expressions, directive syntax, `check` levels, extension policy) are in [COMMON.md](COMMON.md). Data, routes and caching are in [VEGS-DATA.md](VEGS-DATA.md).

## 1. Overview

A `.vegs` file declares typed content shapes, component shapes, function contracts and locale strings. The admin app generates its forms from these declarations. `check` validates them on deploy (COMMON §6).

The schema is a contract layer. It describes no behavior: functions are implemented by the core, a vendor lib or a plugin (§4.4).

- The core is bare: four scalars and a reference (§3). Everything else is declared by a namespace and imported with `use` (COMMON §2).
- One declaration shape: `Name :: ...`. One construction shape: `Type { field = value }`.
- Field roles are keywords in type position (`slot`, `data`). Directives only decorate or constrain (COMMON §5).
- The theme manifest (`theme.vegs`: edition, name, vendor libs, global settings) has no syntax yet: Q-044.

## 2. Lexical

Strings, numbers, identifiers and qualified names: COMMON §3.

| Item       | Rule                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------------ |
| Comments   | `//` to end of line                                                                              |
| Separators | Newline or comma, in bodies and lists. One-line forms need commas. A `use` line ends at its newline |
| Keywords   | `use as fn loader action directive on locale slot data any and or not in true false null`        |

After `on` in a directive declaration (§4.5), the words `field data alias type fn loader action for render` name targets. They are contextual and not reserved elsewhere.

**Casing.** `Upper` declares a type (record, alias, union). `lower` declares a function (`fn`, `loader`, `action`), a directive or a locale table.

| Sigil | Meaning                                    |
| ----- | ------------------------------------------ |
| `::`  | Declares a name                            |
| `:`   | Declares a type (field or parameter)       |
| `=`   | Assigns a value (default, entry, string)   |
| `@`   | Directive                                  |
| `?`   | Nullable                                   |

## 3. Types

| Core type | Notes                                                                                    |
| --------- | ---------------------------------------------------------------------------------------- |
| `Text`    | UTF-8 string                                                                             |
| `Int`     | 64-bit integer                                                                           |
| `Decimal` | Exact decimal, no floats                                                                 |
| `Bool`    |                                                                                          |
| `Ref(T)`  | Stored identifier of entity type `T`; `T` must be a `@collection` (VEGS-DATA §4). The admin app shows a picker |

The core defines no content or commerce types. Date and time types: Q-035.

`std` ships first-party types:

| Type                    | Shape (illustrative)                         |
| ----------------------- | -------------------------------------------- |
| `std.Image`             | `src: Text`, `alt: Text`, `width: Int?`      |
| `std.Link`              | `url: Text`, `label: Text`                   |
| `std.RichText`          | Structure owned by `std`. Sanitized on output (VEGT §8) |
| `std.Page`, `std.Post`, `std.Media` | Core content types (D-020). Fields: Q-049 |

`std` follows every rule here. A theme may ignore it and declare its own `Image`. Domain helpers in `std`: Q-043.

| Type form        | Meaning                                                                                      |
| ---------------- | -------------------------------------------------------------------------------------------- |
| `T`              | Required, non-null                                                                           |
| `T?`             | Nullable. Absent = `null`                                                                    |
| `"a" \| "b"`     | Union of string literals (enum)                                                              |
| `T[0..3]`        | List with min..max items. `[1..]` open-ended, `[..5]` no minimum, `[..]` any                 |
| `(A \| B)[0..3]` | List of a union of record types. The union must be parenthesized. Valid only after `slot`    |
| `any[0..6]`      | List of any component. Valid only after `slot`; narrowed in §6.2                             |

- Lists are never null: empty is `[]`. `T[0..3]?` is an error.
- A bare union is valid only for string literals. A union of non-strings is an error.
- `Ref(T)?` is a nullable reference; `Ref(T)[0..5]` is a list of references.

## 4. Declarations

Every top-level item has the shape `Name :: ...`. A theme declares records, aliases, unions and locale tables only. It has no code, so it declares no `fn`, `loader`, `action` or `directive` (an error).

### 4.1 Record

```
Image :: {
  src:   Text
  alt:   Text
  width: Int? @min(1)
}
```

- The body holds directive lines first (they apply to the record), then fields. `{}` is an empty record.
- A record value is written `Type { field = value }`. A positional entry is an error.

### 4.2 Alias

```
Headline :: Text @max(80) @label("Headline")
Product  :: shopify.Product
```

- An alias names another type, optionally with directives. A field of the alias type inherits them.
- A field directive overrides the same directive on the alias, except `@validate`, which accumulates (§7.4).
- An alias is an ordinary declaration of its namespace: other files of that namespace use it without `use` of the aliased namespace.

### 4.3 Union

```
Tone :: "light" | "dark"
```

### 4.4 Functions: `fn`, `loader`, `action`

```
money     :: fn(m: shopify.Money, currency: Text? = null) -> Text
productBy :: loader(handle: Text) -> shopify.Product?
addToCart :: action(product: Ref(shopify.Product), qty: Int = 1) -> shopify.Cart
clearCart :: action()
```

A declaration is valid only in `std` or an extension namespace. The kind decides what the function may do, who implements it and where it is callable.

| Kind     | May do                                      | `->`     | Implemented by          | Callable from                                                                                  |
| -------- | ------------------------------------------- | -------- | ----------------------- | ---------------------------------------------------------------------------------------------- |
| `fn`     | Nothing outside its arguments: pure, no I/O | required | core, vendor lib, plugin | Templates: core and vendor lib `fn` only (a plugin `fn` in a template is an error). `@show` and `@validate(check = ...)`: any `fn` |
| `loader` | Read-only I/O                               | required | core, vendor lib, plugin | Backs a `data` field (VEGS-DATA §1). `@validate(check = ...)`. Never a template or `@show`    |
| `action` | Reads and writes                            | optional | any extension           | Write endpoints invoked by the core. Not a value, not callable from expressions                |

- Params: `name: Type [= default]`. A function with no return value cannot be used as a value, in a default or in an expression.
- A template-callable `fn` is a transform (GLOSSARY). A plugin `loader` is a resolver the data layer batches, never called per render (VEGS-DATA §2).
- An `action` runs behind core mechanisms: CSRF, Origin, authorization and idempotency key (DESIGN §5).
- The core links I/O capabilities by kind, so a `fn` cannot reach the network or the database.
- A function with no registered implementation is an error.
- Built-in functions (`t`, `url`, `length`, ...) are core-only. Their generic notation is not valid `.vegs` and they cannot be declared: VEGT §7.

### 4.5 Directive declarations

```
swatch :: directive on field | alias (format: "hex" | "rgb" = "hex")
store  :: directive on type (kind: Text)
```

- Syntax: `name :: directive on target { | target } [ ( params ) ]`.
- Targets: `field` (a prop or slot), `data`, `alias`, `type` (a record), `fn`, `loader`, `action`, and the template targets `for` and `render` (VEGT §9).
- Params are written like function params. Calling rules: COMMON §5. Any `Text` param accepts `t(...)`.
- Only the core and vendor libs may declare directives with a template target. A theme declares none.
- A declaration is checked without running extension code. The behavior ships with the declaring extension.

### 4.6 Locale tables

```
en :: locale {
  hero = {
    label   = "Hero banner"
    heading = { label = "Headline" }
  }
}
```

- `name :: locale { ... }` declares one language's strings. The name is a `lower` ident (`en`, `fr`, `pt_BR` for `pt-BR`).
- The body is a tree of `name = "string"` leaves and `name = { ... }` groups. Leaves are strings only.
- Tables with the same language name merge by key path across all files of a namespace. A duplicate key path is an error.
- Read by `t(...)` (§7.5).

## 5. Fields

```
name: [slot | data] Type [= default] [@directive ...]
```

A field is exactly one of three kinds. The kind is visible right after the colon.

| Kind | Form                              | Meaning                                                  |
| ---- | --------------------------------- | -------------------------------------------------------- |
| Prop | `name: Type`                      | Set by editors                                           |
| Slot | `name: slot (A \| B)[0..3]`       | Child area: editors add, order and remove components     |
| Data | `name: data Type @load(loader)`   | Resolved by the server, read-only, never in the editor UI |

Data fields, `@load`, `@route` and the source roles they map to: VEGS-DATA §1.

**Props.** A prop is required when it has no `?`, no `=` and is not a list with `min = 0`. A required prop left empty is a Content error: the entity stays a draft (COMMON §6). `@show` hides a prop and skips the check (§7.3). `= null` on a nullable prop is redundant (Warning).

**Defaults** are literals or `Type { ... }` values. A default must type-check: a union default is a member, a list default fits `[min..max]`, `null` only on a nullable.

**Slots.**

- `slot` is followed by a list of components: one record type, a parenthesized union of them, or a slot set (§6.2). Otherwise it is an error.
- A slot is never null (`slot ...?` is an error). Its default is `[]`. `min > 0` with no default makes it required.
- Default entries must be members of the slot's set.
- A plain list without `slot` is an ordinary list (`Image[1..5]`, a gallery).
- Editor-saved slot contents are compositions, and the core limits their depth: VEGS-DATA §8.

## 6. Components

### 6.1 `@component`

A **component** is a record type marked `@component` that has a template. Its fields are its props and slots; the admin app form is generated from them.

```
Hero :: {
  @component
  @group(sections)
  heading: Headline = "Welcome"
}
```

| Concept     | Rule                                                                                                 |
| ----------- | ---------------------------------------------------------------------------------------------------- |
| Binding     | A template starts with `use` tags, then exactly one `{type Name}` tag naming its subject (VEGT §1)    |
| Bindable    | Any record type that is not `@collection` or `@global`                                                |
| Renderable  | A bound record can be output with `{render}` (VEGT §5.3)                                              |
| Placeable   | Only a `@component` can be placed in a slot or matched by `any`, and appears in admin app pickers     |
| No template | A `@component` with no template is an error. The engine supplies no default                           |

- Two templates naming one type, or a template naming an unknown type, is an error.
- A plain record with a template and no `@component` is a helper: renderable, never placeable. Add `@internal` to hide it from other namespaces (§6.4).
- A `@component` cannot also be `@page`, `@collection`, `@not_found` or `@global`.
- Page types are `@page` records (VEGS-DATA §4). A page type nests shared records or components for a shared frame (`header: Header`, §6.4). There is no layout construct.
- Cache class of a component: `@fragment` (VEGS-DATA §5). A component placed in a composition may use `@route` data (VEGS-DATA §3).
- Replacing a plugin's component with a theme component: Q-045.

### 6.2 Slot sets and `@group`

`@group(name)` is an optional namespace-scoped tag on a component. A group exists when a component names it. A component has one group (Q-038).

A slot's allowed children are one of:

| Form                              | Allows                                        |
| --------------------------------- | --------------------------------------------- |
| `slot (A \| B)[0..3]`             | Exactly the listed components                 |
| `slot any[0..6]`                  | Every component                               |
| `slot any(in shopify)[0..6]`      | Every component of a namespace                |
| `slot any(in theme.sections)[0..6]` | Every component of a namespace's group      |

- In `in X`, `X` is a namespace or `ns.group`. A namespace other than the file's own needs `use`.
- `check` evaluates a set against all declarations, so adding a component to a namespace or group extends every slot that selects it. Pin a slot to an explicit list when new components must not appear automatically. `check --expand` prints the resolved set (COMMON §6).
- An empty set is an error. An explicit member that is not a `@component` is an error. An unknown namespace or group in `any(in ...)` is an error. `@group` on a non-component is an error.
- An `@internal` component never appears in another namespace's `any` set (§6.4).

### 6.3 `@yields`

`@yields` marks a record whose template accepts a **body**: markup passed by the caller.

```
MaybeLink :: {
  @component
  @yields
  link: std.Link?
}
```

- A caller passes a body only to a `@yields` type: `{render X(...)}body{/render}`. A bare `{slot}` in the template outputs the body (VEGT §5.3, §5.4).
- A body is template markup. It is not a `slot` field and stores no data. An editor-placed `@yields` component gets an empty body.
- Valid on any record type.

### 6.4 Composition by nesting, aliases and `@internal`

- **Nesting.** A field's type can be any record (`seo: Seo`, `base: BasePage`). A shared field set is a record used as a field.
- **Aliases** share one field type with its directives (§4.2).
- **Slots** place components inside components (§5).

`@internal` limits a type or function to its own namespace:

```
Seo :: {
  @internal
  title: Text @max(60)
}
```

- A reference from another namespace is an error. `@internal` on anything but a type or function is an error.
- A public type may have a field of an internal type. Other namespaces cannot name the internal type but can read or edit the value through the field.
- `@internal` is visibility, not access control. Permissions are not language: Q-029.
- Origin stays visible: explicit names are qualified (COMMON §1), stored children keep their full identity, and the admin app picker shows namespace and source path.

## 7. Directives

Syntax, resolution and unknown-directive rules: COMMON §5. This section covers placement, the core directive table and the schema-only directives.

### 7.1 Placement

- A directive after a field or declaration on the same line applies to it. Several may follow.
- A directive line before the first field of a record body applies to the record.
- A directive line right after a field, alias or function line (no field between) continues that line.
- Parentheses, brackets and braces may span lines.

```
Post :: {
  @label("Blog post")                      // before the first field: the record

  title: Text @max(120)                    // same line: title
  slug:  Text
    @validate(pattern = "^[a-z0-9-]+$", message = "Lowercase letters, digits, dashes")
    @validate(pattern = "^[^-]", message = "Must not start with a dash")
}
```

### 7.2 Core directive table

Every core directive. Text arguments (`@label`, `@hint`, `message`) accept a string or `t(...)`.

| Directive                           | Applies to                           | Meaning                                                           | Detail         |
| ----------------------------------- | ------------------------------------ | ----------------------------------------------------------------- | -------------- |
| `@label(text)`                      | fields, types                        | Editor title. Default: field name, title-cased                    | here           |
| `@hint(text)`                       | fields, types                        | Helper text under a field; on a type, the subtitle in pickers     | here           |
| `@min(n)` / `@max(n)`               | `Text` (length), `Int`, `Decimal` (value) | Bounds; also drive widget hints (counter). `Decimal` args are decimal literals | here |
| `@validate(...)`                    | fields, aliases                      | Pattern or function rule                                          | §7.4           |
| `@show(expr)`                       | non-data fields                      | Show the field only when `expr` is true                           | §7.3           |
| `@editor("route")`                  | fields, aliases, types               | Replace the generated input with a server route                   | §7.6           |
| `@internal`                         | types, functions                     | Usable only in its own namespace                                  | §6.4           |
| `@component`                        | record types                         | May be placed in slots                                            | §6.1           |
| `@group(name)`                      | components                           | Namespace-scoped tag for slot sets                                | §6.2           |
| `@yields`                           | record types                         | Template accepts a caller-passed body                             | §6.3           |
| `@load(loader)`                     | `data` fields                        | The loader that produces the value                                | VEGS-DATA §1   |
| `@route("param")`                   | `data` fields                        | Binds a route param to the loader param of the same name          | VEGS-DATA §3   |
| `@page` / `@page("/pattern")`       | record types                         | Routable page; optional default pattern                           | VEGS-DATA §4   |
| `@not_found`                        | record types                         | The page served for unmatched URLs and missing route subjects     | VEGS-DATA §4   |
| `@collection("name")`               | record types                         | Entity type; only in `std` or an extension                        | VEGS-DATA §4   |
| `@global`                           | record types                         | Fields are in scope in every template of the namespace            | VEGS-DATA §6   |
| `@private`                          | loaders, `data` fields               | Result is storage class private; never cached shared             | VEGS-DATA §6   |
| `@cache(ttl, stale?, vary?, tags?)` | loaders, `data` fields, `@page` types | Freshness window and staleness limit                             | VEGS-DATA §7   |
| `@timeout(duration)`                | loaders, `data` fields               | Maximum time for the loader                                       | VEGS-DATA §7   |
| `@fallback(mode)`                   | `data` fields                        | What a field with no acceptable value does                        | VEGS-DATA §7   |
| `@fragment(class?, push?)`          | components                           | Tighten the derived cache class; opt in to push                   | VEGS-DATA §5   |
| `@limit(n)` `@offset(n)` `@reverse` | `for` tags                           | Template list directives                                          | VEGT §9        |

Reserved, not active: `@unique`, `@placeholder`.

### 7.3 `@show`

`@show(expr)` shows a field in the admin app only when `expr` is true.

```
overlay:  Text? @show(tone == "dark")
discount: Decimal? @show(shopify.isWholesale(customer = customer))
```

- Grammar and scope: COMMON §4 (`@show` row). A bare name is a sibling prop of the same record. `data` fields cannot be read.
- A call must be a `fn` returning `Bool` (§4.4). A plugin `fn` is allowed. `value` does not exist here.
- The admin app may evaluate `@show` on every edit, so a `fn` must be fast. A call that errors counts as `true` (field shown) and logs a warning.
- A hidden field skips the required check. Its stored value is kept. UI directives on `data` fields are errors (VEGS-DATA §1).

### 7.4 `@validate`

A field may carry several `@validate` directives. Each is an independent rule, evaluated in declaration order; each failing rule reports its own message. An alias's rules and the field's own rules all apply.

| Parameter | Meaning                                                                                              |
| --------- | ---------------------------------------------------------------------------------------------------- |
| `pattern` | Regular expression the value must match. `Text` fields only                                          |
| `check`   | One call to a declared `fn` or `loader` with explicit named arguments (COMMON §4). Any field type    |
| `message` | Text shown when the rule fails: a string or `t(...)`. Optional. Not allowed with a `Text?` check    |

```
endDate: Int
  @validate(check = acme.notBefore(value = value, floor = startDate), message = t(errors.end_after_start))
slug: Text
  @validate(check = acme.slugFree(value = value))

notBefore :: fn(value: Int, floor: Int) -> Bool            // declared by acme
slugFree  :: loader(value: Text) -> Text?                  // reads; null = pass
```

- Exactly one rule parameter (`pattern` or `check`) per directive. `message` alone, both rules in one directive, or `message` with a `Text?` check is an error. Use two directives for two rules.
- `value` is in scope inside `@validate` only and holds the field's own value. Other arguments are sibling props or literals. There is no implicit binding.
- A `check` returns `Bool` (`true` = pass; failure uses `message`, then the host default) or `Text?` (`null` = pass; text = the failure message, shown as-is). Any other return type is an error.
- A `loader` may read (a uniqueness lookup) and never writes. A `check` that errors fails validation with the host default message.
- A `check` is not evaluated while its field is hidden by `@show`.
- Enforced on the server, on save and in the API. The admin app shows messages inline. `@min` and `@max` are the short form.
- Extra parameters (`min`, `max`, cross-field expression): Q-037.

**Regex dialect.** `pattern` uses the Odin `core:text/regex` dialect:

| Supported                                                   | Not supported            |
| ----------------------------------------------------------- | ------------------------ |
| Alternation, classes and negated classes, `.`, `* + ?`, `{m,n}`, lazy variants | Lookaround     |
| Capture and non-capture groups, `^ $`, `\b \B`              | Backreferences           |
| `\d \s \w` and negations (ASCII only)                       |                          |

An invalid pattern, or `pattern` on a non-`Text` field, is an error. A browser's regex differs, so browser checks are advisory; the server is authoritative.

### 7.5 `t(path)`

```
@label(t(hero.heading.label))
@hint(t(shopify.cart.title))
```

- `t` is valid only as the argument of a `Text` parameter of a schema directive (`@label`, `@hint`, `message`). It is not valid in defaults.
- The path walks locale tables (§4.6). Keys of the file's own namespace are bare; keys of another namespace start with its name and need `use`. The path must end at a string leaf; a group is an error.
- In the schema, `t` resolves for the editor's admin language, then the default locale. Where the default locale is configured, placeholders and plurals: Q-036.
- A key missing in the default locale is an error. Missing in another locale is a Warning (falls back to the default).
- A top-level key group may not share a name with a namespace.
- Plain strings stay valid: `@label("Headline")` is default-language text. In templates `t` has its own rules: VEGT §7. Translating merchant content: Q-031.

### 7.6 `@editor`

`@editor("route")` replaces the generated input of its target with a server route that renders it.

```
Swatch :: Text @editor("/admin/widgets/swatch")

Hero :: {
  tone:  Tone      @editor("/admin/widgets/toggle")
  image: std.Image @editor("/admin/widgets/image-crop")
}
```

- Targets: a field, an alias (every field of that alias inherits it; a field-level `@editor` overrides) or a record type (replaces the whole form). One `@editor` per target. Not valid on `data` fields.
- It replaces every generated input for its target, including `@min`/`@max` widget hints. Label, hint and error messages still frame it. `@show`, `@validate`, types and required rules are still enforced on the server, so a custom editor cannot bypass validation.
- The route is an absolute path served by the core or a vendor lib. It is a URL, not a file. `check` verifies it is registered; an unregistered route is an error. It cannot verify the HTML.
- A plugin never serves an `@editor` route and never renders HTML. A plugin that needs a custom input ships a theme component that the core renders.
- Contract (illustrative): the admin app loads the route with the entity ID, the field path, the input `name` and the current value. The response is HTML whose inputs use that `name` (sub-fields as `name.sub`). Saves use the normal form post.

## 8. Extensions

An extension is a namespace that adds names. It never changes the language (COMMON §7).

| An extension can add        | How                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------------------ |
| Types                       | Records, aliases, unions; entity types with `@collection` (VEGS-DATA §4)                    |
| Functions, loaders, actions | Declarations (§4.4); the tier decides who may implement and call each                      |
| Directives                  | Declarations (§4.5), used as `@ns.name`. Template targets: vendor libs only                 |
| `@global` records           | Records whose `data` fields load its loaders (VEGS-DATA §6)                                 |
| Locale strings              | Locale tables (§4.6)                                                                        |
| Page kinds                  | Plugin page kinds served through gates: Q-046                                               |

An extension cannot add keywords, sigils or syntax, redefine core names, or declare in `theme` or `std`. Namespace collisions and component replacement: Q-045. Permissions are not language: Q-029.

A theme with no extensions and no `std` uses the whole language: the core types plus its own records.

## 9. Grammar

EBNF. Tokens (`IDENT`, `TYPENAME`, `STRING`, `INT`, `DECIMAL`, `NEWLINE`): COMMON §3. `expr`, `call` and `qident`: COMMON §4. A directive argument is a literal, `t(...)` or a function name; only `@show` and `check =` take an expression.

```
file      = { useline } { decl } ;
useline   = "use" IDENT [ "as" IDENT ] NEWLINE ;

decl      = TYPENAME "::" ( record | typeexpr dirs )
          | IDENT "::" ( "fn" | "loader" ) "(" [ params ] ")" "->" typeexpr dirs
          | IDENT "::" "action" "(" [ params ] ")" [ "->" typeexpr ] dirs
          | IDENT "::" "directive" "on" target { "|" target } [ "(" [ params ] ")" ]
          | IDENT "::" "locale" "{" [ lentry { SEP lentry } ] "}" ;
target    = "field" | "data" | "alias" | "type" | "fn" | "loader" | "action"
          | "for" | "render" ;
params    = param { "," param } ;
param     = IDENT ":" typeexpr [ "=" value ] ;

record    = "{" { dirline } [ field { SEP field } ] "}" ;
field     = IDENT ":" ( "slot" slottype | [ "data" ] typeexpr ) [ "=" value ] dirs ;
dirs      = { dir } { dirline } ;
dirline   = NEWLINE dir { dir } ;

typeexpr  = base [ "?" | list ] ;
base      = refexpr | qname | STRING "|" STRING { "|" STRING } ;
refexpr   = "Ref" "(" qname ")" ;
slottype  = ( qname | "(" qname { "|" qname } ")" | anyset ) list ;
anyset    = "any" [ "(" "in" scope ")" ] ;
scope     = IDENT [ "." IDENT ] ;
qname     = [ IDENT "." ] TYPENAME ;
list      = "[" [ INT ] ".." [ INT ] "]" ;

value     = STRING | INT | DECIMAL | "true" | "false" | "null"
          | "[" [ value { SEP value } ] "]"
          | qname "{" [ entry { SEP entry } ] "}" ;
entry     = IDENT "=" value ;

dir       = "@show" "(" expr ")"
          | "@" qident [ "(" [ arg { "," arg } ] ")" ] ;
arg       = "check" "=" call
          | [ IDENT "=" ] ( value | tcall | qident ) ;
tcall     = "t" "(" IDENT { "." IDENT } ")" ;

lentry    = IDENT "=" ( STRING | "{" [ lentry { SEP lentry } ] "}" ) ;
SEP       = "," | NEWLINE ;
```

- `Text`, `Int`, `Decimal` and `Bool` are `TYPENAME`s resolved as core names. `Ref` is a special form: its argument is a `qname`.
- `arg` alternatives are tried in order; `check = call` applies only to `@validate`. A bare `qident` argument names a function (`@load(f)`).

## 10. `check` rules

Namespace, `use`, expression and directive-syntax errors: COMMON §1 to §5. Rules for data, routes and caching: VEGS-DATA §10. Template rules: VEGT §10.

| Level   | Rule                                                                              | §    |
| ------- | --------------------------------------------------------------------------------- | ---- |
| Error   | `Upper` declaration that is not a type; `lower` that is not a function, directive or locale | §2 |
| Error   | Bare union of non-strings; `(A \| B)` outside `slot`; nullable list; `Ref(T)` with `T` not a `@collection` | §3 |
| Error   | Theme declares `fn`, `loader`, `action` or `directive`                            | §4   |
| Error   | `fn` or `loader` without `->`; function with no implementation                    | §4.4 |
| Error   | Plugin `fn` called in a template; `loader` or `action` called in an expression    | §4.4 |
| Error   | Function with no return value used as a value                                     | §4.4 |
| Error   | Directive declaration with unknown target or duplicate param; template-target directive from a theme or plugin | §4.5 |
| Error   | Locale leaf that is not a string; duplicate key path for one language             | §4.6 |
| Error   | Positional record entry                                                           | §4.1 |
| Error   | Default does not type-check; union default not a member; list default out of bounds; `null` on a non-nullable | §5 |
| Error   | `slot` without a list of components; nullable slot                                | §5   |
| Error   | `@component` with no template; template naming an unknown type; two templates for one type | §6.1 |
| Error   | Template bound to a `@collection` or `@global` record                             | §6.1 |
| Error   | `@component` together with `@page`, `@collection`, `@not_found` or `@global`      | §6.1 |
| Error   | Slot member or default that is not a `@component` or not in the set; empty set; unknown namespace or group | §6.2 |
| Error   | `@group` on a non-component                                                       | §6.2 |
| Error   | Reference to an `@internal` name from another namespace; `@internal` on a non-type, non-function | §6.4 |
| Error   | `@show` with unknown name, type mismatch, `data` field read, or a call that is not a `Bool` `fn` | §7.3 |
| Error   | `@validate` with no rule parameter, both rules, or `message` alone / with a `Text?` check | §7.4 |
| Error   | `check` that is not one call to a `fn` or `loader`, or returns neither `Bool` nor `Text?`; `value` outside `@validate` | §7.4 |
| Error   | Invalid `pattern`; `pattern` on a non-`Text` field                                | §7.4 |
| Error   | `t(...)` outside a text parameter; key missing in the default locale; key resolves to a group; key group named like a namespace | §7.5 |
| Error   | `@editor` route not registered, served by a plugin, on a `data` field, or more than one on a target | §7.6 |
| Warning | `= null` on a nullable prop                                                       | §5   |
| Warning | `t(...)` key missing in a non-default language                                    | §7.5 |
| Content | Required prop or slot left empty                                                  | §5   |

## 11. Example

A theme's schema (namespace `theme`) with an extension's declarations (`acme`, a plugin) shown as comments.

```
// acme declares: slugFree :: loader(value: Text) -> Text?
//                swatch   :: directive on field | alias (format: "hex" | "rgb" = "hex")
use std
use shopify
use acme

Headline :: Text @max(80) @label(t(headline.label))
Tone     :: "light" | "dark"
Brand    :: Text @acme.swatch(format = "rgb")

Button :: {
  @component
  @group(inline)
  label: Text @max(40)
  url:   Text = "/"
}

Callout :: {
  @component
  @group(inline)
  text: std.RichText
}

MaybeLink :: {
  @component
  @yields
  link: std.Link?
}

Hero :: {
  @component
  @group(sections)
  @label(t(hero.label))
  @hint(t(hero.hint))

  heading:  Headline = "Welcome"
  tone:     Tone = "light"
  overlay:  Text? @show(tone == "dark")
  image:    std.Image
  cta:      std.Link? = std.Link { url = "/", label = "Shop now" }
  featured: Ref(shopify.Product)?
  content:  slot (Button | Callout)[0..3] = [Button { label = "Shop now" }]
}

Seo :: {
  title:       Text @max(60)
  description: Text? @max(160)
}

MarketingPage :: {
  @page
  seo:  Seo
  main: slot any(in theme.sections)[1..]
}

Contact :: {
  @component
  @group(sections)
  slug: Text
    @validate(pattern = "^[a-z0-9-]+$", message = t(errors.slug_chars))
    @validate(check = acme.slugFree(value = value))
}

en :: locale {
  headline = { label = "Headline" }
  hero     = { label = "Hero banner", hint = "Full-width banner with heading and button" }
  errors   = { slug_chars = "Lowercase letters, digits, dashes" }
}
```
