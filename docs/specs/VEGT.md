# VegaBase Template Language (`.vegt`): Spec v0.1 draft

A small, typed template language for a plugin-based, hypermedia-first CMS. A template turns a schema type's data into HTML. A `check` step validates every template against its schema before publish.

It is a rendering layer. It does not define data, types, caching, or I/O: those live in the schema (`.vegs`) and in Go.

**Design rules**

- The core is tiny: five tags, one output form, one comment form.
- Structure is words, decoration is directives: tags are keywords in braces, `@` only decorates a tag.
- A tag's kind (void or block) is fixed by its keyword. Never by a slash.
- Templates are pure. No I/O, no side effects, no mutable state. Data arrives from the schema; logic lives in Go functions.
- Undefined is an error. Output is escaped by default.
- Shares its lexical conventions with the schema language (`use`, `owner.Name`, `=` for values, `@` for directives), but is a separate grammar.
- Extend by adding names (functions, components, directives), never by changing syntax or meanings.

---

## 1. Templates and binding

A template file (`*.vegt`) holds markup plus tags. A file's name and location mean nothing to the language.

- The host **binds** each template to exactly one schema type: a component or a page (`@component`, `@page`). The bound type is the template's **subject**.
- Every prop and `data` field of the subject is in scope by name (§6). Nothing else is.
- A template cannot see the props of its slot children (§5.4). It renders them opaquely.
- Rendering is **pure**: the same data gives the same output. Data resolution, caching, and inline-vs-island decisions are made from the schema before the template runs. The template contains no caching vocabulary.

---

## 2. Lexical

| Item           | Rule                                                                |
| -------------- | ------------------------------------------------------------------- |
| Output         | `{expr}`                                                            |
| Tag            | `{keyword ...}`, closed (block tags only) by `{/keyword}`           |
| Comment        | `{# ... #}`, may span lines, never emitted                          |
| Strings        | `"..."`, escapes `\" \\ \n \t \uXXXX`                               |
| Int            | `42`, `-7`                                                          |
| Decimal        | `19.99d`, `0d`. Must end in `d`                                     |
| Float          | **Not supported.** `1.5` is a lex error                             |
| Bool / null    | `true` `false` `null`                                               |
| `Upper` ident  | `[A-Z][A-Za-z0-9]*`: component and type names                       |
| `lower` ident  | `[a-z_][A-Za-z0-9_]*`: props, variables, functions, owners          |
| Qualified name | `owner.Name` or `owner.fn`                                          |
| Keywords       | `use as if elif else for render slot in and or not true false null` |

- Everything outside `{...}` is literal text and is emitted unchanged. Whitespace is never altered.
- A `{` followed by whitespace or a newline is literal text. To emit any other literal brace, output a string: `{"{"}`.
- `{#` always starts a comment.
- Expressions never span tags, but may span lines inside one pair of braces.

### Punctuation

| Token | Meaning                           |
| ----- | --------------------------------- |
| `{ }` | Opens and closes an output or tag |
| `{/`  | Opens a block closer              |
| `=`   | Names an argument value           |
| `\|`  | Pipe                              |
| `??`  | Fallback when a value is `null`   |
| `.`   | Field access, qualified name      |
| `@`   | Directive                         |

---

## 3. Tags

Five keywords. Each is either **void** (no closer) or **block** (always closed by `{/name}`).

| Tag                    | Kind          | Job                                  |
| ---------------------- | ------------- | ------------------------------------ |
| `use`                  | void          | Import an owner (§4)                 |
| `if` / `elif` / `else` | block         | Conditional (§5.1)                   |
| `for`                  | block         | Loop (§5.2)                          |
| `render`               | void or block | Render a component (§5.3)            |
| `slot`                 | void          | Output a slot or the children (§5.4) |

`elif` and `else` are separators inside an `if` (and `else` inside a `for`), not tags of their own: they have no closer.

---

## 4. Imports: `use`

```
{use shopify}
{use shopify as shop}
```

- `use` imports an **owner**, never individual names. Names stay qualified at each use site (`shopify.money`, `shopify.Stock`).
- `use` tags come first in the file, before any other tag or output.
- `use` is non-transitive and affects only its own file.
- `as` renames the owner inside that file only.
- A `use` is **required** for every qualified reference to that owner in the file: functions, components, directives.
- The subject's own owner and the built-in functions (§7.2) need no `use`. `use app` is an error.
- Unknown owner or duplicate `use` is an error. Unused `use` is a warning.

---

## 5. Tag reference

### 5.1 `if` / `elif` / `else`

```
{if product.compareAt > product.price}
  <s>{product.compareAt | shopify.money}</s>
{elif product.featured}
  <span>Featured</span>
{else}
  <span>Regular price</span>
{/if}
```

- The condition must be `Bool` or a nullable type `T?`. A nullable is true when non-null, false when `null`. Nothing else is truthy or falsy: `Text`, `Int`, and lists are not conditions. Compare explicitly (`name != ""`, `length(items) > 0`).
- **Narrowing:** inside the branch, a condition that tests a nullable for non-null (`{if x}`, `x != null`, joined with `and`) narrows `x` from `T?` to `T`. Narrowing does not carry into `elif`/`else`, nor through `or` or `not`.
- There is no `unless`. Use `not`.

### 5.2 `for`

```
{for item in product.images}
  <img src="{item.src}" alt="{item.alt}">
{/for}

{for item, i in product.images}
  <li class="n{i}">{item.alt}</li>
{/for}
```

- Iterates a list. The source must be a list type (never null).
- An optional `{else}` renders when there is nothing to iterate: the list is empty, or `@offset`/`@limit` (§9) leave no items. Without `{else}`, an empty loop renders nothing.

```
{for item in cart.lines}
  <li>{item.title}</li>
{else}
  <p>Your cart is empty.</p>
{/for}
```

- `item` is the element. The optional second name is the zero-based index (`Int`).
- Loop variables are visible only inside the block and may not shadow anything in scope (§6).
- There is no default loop or pagination cap. Use `@limit`, `@offset`, `@reverse` (§9) to shape iteration.

### 5.3 `render`

Renders a component. Arguments are **named only** and bind to the component's **props**.

```
{render Gallery(images = product.images)}
{render shopify.Stock(product = product)}

{render MaybeLink(link = product.vendorLink)}
  <h2>{product.vendor}</h2>
{/render}
```

- **Void or block is decided by the component's schema.** A component that declares a default slot is a block: it is always written `{render X(...)}...{/render}` (an empty body is allowed). A component without one is void and has no closer. `check` reports a mismatch.
- The body is the component's **children**, rendered inside the component through its default slot (§5.4). The body is evaluated in the caller's scope.
- Arguments use `name = expr`, the same shape as schema record entries. No positional arguments.
- `check` verifies: the component exists and is a `@component` (or an allowed type), every argument names a prop, each type matches, every required prop is supplied, no prop is given twice. Slot and `data` fields cannot be passed as arguments.
- Props that are omitted take their schema default.
- Whether the component renders **inline** or as an **island** is decided by its schema, not here (§1). The `render` tag reads the same either way.

### 5.4 `slot`

```
{slot main}     {# a slot field of the subject #}
{slot}          {# the children passed to this component by render...{/render} #}
```

- `{slot name}` outputs the subject's slot field `name`: its children, in editor order, each rendered as a component. `name` must be a slot field of the subject, else a `check` error.
- Bare `{slot}` outputs the children passed by a block `render`. It is valid only in a component that declares a default slot.
- A slot is rendered **opaquely**: the template cannot read child props or branch on child types. Allowed children, ordering, and min/max are enforced by the schema, not here.
- Each child decides its own inline/island mode (§1). `slot` takes no directives that change this.

---

## 6. Scope and names

A name in an expression resolves, in order, to:

1. A loop variable (`for`) in an enclosing block.
2. A prop or `data` field of the subject.

- Anything else is an error (**undefined is an error**; there is no empty-string fallback).
- A loop variable cannot reuse a name already in scope. There is no shadowing.
- A `render` call does not leak its arguments or the subject's names into the component: the component sees only its own fields.
- Slot fields are not values: they are reachable only through `{slot name}`.
- A `data` field of non-null type is always present. A `data` field of type `T?` may be `null` and must be narrowed or defaulted before use.

---

## 7. Expressions

### 7.1 Grammar summary

| Element      | Forms                                         |
| ------------ | --------------------------------------------- |
| Literals     | string, int, decimal, `true`, `false`, `null` |
| List literal | `["a", "b"]`, only as the right side of `in`  |
| Names        | `lower` identifiers (§6)                      |
| Access       | `a.b.c`: record field access                  |
| Comparison   | `==` `!=` `<` `>` `<=` `>=`                   |
| Membership   | `x in ["a", "b"]`, `x in list`, `"a" in text` |
| Fallback     | `x ?? y`                                      |
| Logic        | `and` `or` `not`, parentheses                 |
| Call         | `fn(name = expr, ...)`, `owner.fn(...)`       |
| Pipe         | `expr \| fn`, `expr \| fn(name = expr, ...)`  |

**Precedence**, tightest to loosest: access and call, pipe, `??`, comparison and `in`, `not`, `and`, `or`.

- **`x ?? y`**: the left side must be nullable (`T?`). The right side is `T` or `T?`. The result is `T` if the right side is `T`, else `T?`. The right side is not evaluated unless the left is `null`. Chains read left to right (`a ?? b ?? ""`). A non-nullable left side is an error.
- **`in`**: `x in list` is true when `x` equals an item (`x` must match the item type). `"a" in text` is true when `a` is a substring (both `Text`). A list literal (`["a", "b"]`) is allowed only as the right side of `in`. A nullable right side must be narrowed first.

- No arithmetic and no assignment. Computing belongs in Go functions.
- `<` `>` `<=` `>=` apply to `Int` and `Decimal` of the same type. `==` `!=` apply to any two values of the same type.
- Accessing a field of a nullable `T?` without narrowing is an error. There is no `?.`.
- Type mismatches and unknown names or fields are `check` errors.

### 7.2 Calls and pipes

A call has the same shape as `render`: **named arguments only**.

```
{shopify.money(m = product.price, locale = "fr")}
```

The **pipe** is sugar: the left value binds to the function's **first parameter**, whatever its name.

```
{product.price | shopify.money}
{product.price | shopify.money(locale = "fr")}
{product.title | truncate(max = 60) | upper}
```

- `x | f(a = 1)` is exactly `f(<first param> = x, a = 1)`. One meaning, two spellings.
- Piping into a function with no parameters, or giving the first parameter again by name, is an error.
- A function used in a template must be declared in the schema (`fn`, with a Go body) and be **template-safe**: pure, no I/O, fast. Loaders and actions are not callable from templates.
- `check` verifies the function exists, has a body, is template-safe, and that argument types match.

**Built-in functions** (core, no `use`, names reserved):

| Function          | Shape (illustrative)                          | Job                       |
| ----------------- | --------------------------------------------- | ------------------------- |
| `upper` / `lower` | `(value: Text) -> Text`                       | Case                      |
| `truncate`        | `(value: Text, max: Int) -> Text`             | Shorten                   |
| `length`          | `(value: Text \| list) -> Int`                | Size                      |
| `first`           | `(value: T[..]) -> T?`                        | First item or `null`      |
| `join`            | `(value: Text[..], sep: Text = ", ") -> Text` | Join items                |
| `raw`             | `(value: Text) -> Text`                       | Mark as trusted HTML (§8) |

Domain functions (`money`, `date`, image helpers) are not core. They come from `std` or a plugin and are used qualified (`std.money`, `shopify.money`), with a `use`.

---

## 8. Output and escaping

`{expr}` outputs the value of `expr`.

- **HTML-escaped by default**, including inside attributes.
- Output is allowed for `Text`, `Int`, and `Decimal`. Any other type (a record, `Image`, `RichText`, a list) must be converted by a function or rendered through a component.
- A nullable value cannot be output directly. Narrow it (`{if x}`) or give it a fallback (`{x ?? ""}`).
- `raw` marks a `Text` as already-safe HTML and skips escaping. It is the only escape hatch, and `check` warns on every use.
- Values inside attributes are escaped for attribute context. A value placed in a URL or script context must come from a typed function (for example one returning a `Link`), not be built by hand.

---

## 9. Directives

```
@name
@name(value)
@name(key = value, key = value)
```

One concept, the same as in the schema language: a named instruction starting with `@` that **decorates** a tag. A directive changes how a tag behaves. It never produces a value and is not a second way to call a function.

- Placement: trailing on a tag, after its arguments, before the closing `}`.
- Every directive has a fixed signature: its allowed tags and its argument types.
- **An unknown directive is an error.** A directive on the wrong tag is an error.
- Plugin directives are namespaced (`@shopify.name`) and need `use shopify`.
- Directive arguments are **expressions** evaluated in the tag's scope, so `@limit(n = pageSize)` is valid.
- Plugins and later versions add directives without touching the grammar.

### Core directives

All target `for`.

| Directive         | Meaning                                                                      |
| ----------------- | ---------------------------------------------------------------------------- |
| `@limit(n: Int)`  | Iterate at most `n` items. `n` below 0 is a `check` error; 0 renders nothing |
| `@offset(n: Int)` | Skip the first `n` items                                                     |
| `@reverse`        | Iterate in reverse order                                                     |

- Applied in this fixed order regardless of how they are written: `@reverse`, then `@offset`, then `@limit`.
- The loop index (`i`) counts from 0 over the items actually iterated.
- There is no `@sort` or filter: ordering and selection belong in Go functions or the schema.

```
{for item in product.images @offset(n = 1) @limit(n = 4)}
  <img src="{item.src}" alt="{item.alt}">
{/for}
```

---

## 10. Plugins

A plugin is an owner. It adds names; it never changes the language.

| A plugin can add                                              | Used in a template as                      |
| ------------------------------------------------------------- | ------------------------------------------ |
| Functions (`fn` in its `.vegs`, Go body)                      | `shopify.money(...)`, `x \| shopify.money` |
| Components (`@component` + a template)                        | `{render shopify.Stock(...)}`              |
| Directives (registered in Go with targets and argument types) | `@shopify.name(...)`                       |

A plugin cannot add tags, keywords, operators, or syntax, nor redefine the built-in functions.

**All I/O goes through the schema.** A template reads data only through the subject's `data` fields, which the server resolves and caches before rendering. This is what keeps templates pure, checkable, and cacheable.

---

## 11. `check` rules

| Level        | Rule                                                                                                                                                                                           |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Error        | Unresolved name or field; unknown owner; qualified reference with no `use`; `use` after other content; duplicate `use`; `use app`                                                              |
| Error        | Type mismatch in a comparison, argument, or condition; `<` `>` `<=` `>=` on non-numbers; float literal                                                                                         |
| Error        | `if` condition that is not `Bool` or `T?`                                                                                                                                                      |
| Error        | Field access on a nullable that is not narrowed; output of a nullable; output of a type other than `Text`, `Int`, `Decimal`                                                                    |
| Error        | `??` with a non-nullable left side or a right side of the wrong type; `in` with mismatched item types, a non-list non-`Text` right side, or a list literal anywhere but the right side of `in` |
| Error        | Loop source that is not a list; loop variable that shadows a name in scope                                                                                                                     |
| Error        | `render` of an unknown or non-component type; argument that is unknown, duplicated, positional, or of the wrong type; required prop missing; slot or `data` field passed as an argument        |
| Error        | Block `render` of a component with no default slot, or void `render` of one that has a default slot; missing or mismatched closer                                                              |
| Error        | `{slot name}` where `name` is not a slot field of the subject; bare `{slot}` outside a component with a default slot                                                                           |
| Error        | Function with no Go body, not template-safe, or whose arguments do not match; pipe into a zero-parameter function                                                                              |
| Error        | Unknown directive, or a directive on the wrong tag; bad directive arguments                                                                                                                    |
| Error        | Unclosed block, stray `elif` / `else` / closer, tag keyword misspelled                                                                                                                         |
| Warning      | Unused `use`; any use of `raw`                                                                                                                                                                 |
| Check output | Resolved slot sets, which components render as islands, and each template's resulting freshness (from the schema)                                                                              |
| Check output | Fixtures generated from the subject's schema (defaults, empty, null, min, max) are rendered; any error or panic fails the check                                                                |

---

## 12. Grammar (EBNF)

```
template  = { use } { node } ;
use       = "{" "use" IDENT [ "as" IDENT ] "}" ;

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
render    = "{" "render" qname "(" [ arg { "," arg } ] ")" { dir } "}"
            [ { node } "{/render}" ] ;        (* body iff the component declares a default slot *)
slot      = "{" "slot" [ IDENT ] "}" ;

arg       = IDENT "=" expr ;
dir       = "@" qident [ "(" [ darg { "," darg } ] ")" ] ;
darg      = expr | IDENT "=" expr ;
qident    = [ IDENT "." ] IDENT ;
qname     = [ IDENT "." ] TYPENAME ;

expr      = orexpr ;
orexpr    = andexpr { "or" andexpr } ;
andexpr   = notexpr { "and" notexpr } ;
notexpr   = [ "not" ] cmp ;
cmp       = coalesce [ ( "==" | "!=" | "<" | ">" | "<=" | ">=" ) coalesce
                 | "in" ( listlit | coalesce ) ] ;
coalesce  = pipe { "??" pipe } ;
listlit   = "[" [ value { "," value } ] "]" ;
pipe      = postfix { "|" qident [ "(" [ arg { "," arg } ] ")" ] } ;
postfix   = primary { "." IDENT } ;
primary   = value | IDENT | call | "(" expr ")" ;
call      = qident "(" [ arg { "," arg } ] ")" ;
value     = STRING | INT | DECIMAL | "true" | "false" | "null" ;
```

---

## 13. Examples

### A page template (`ProductPage`)

```
{use shopify}

<main class="pdp">
  {render Gallery(images = product.images)}

  {render MaybeLink(link = product.vendorLink)}
    <h2>{product.vendor}</h2>
  {/render}

  <h1>{product.title}</h1>

  {if product.compareAt > product.price}
    <s>{product.compareAt | shopify.money}</s>
  {/if}
  {product.price | shopify.money}

  {render shopify.Stock(product = product)}
  {render shopify.AddToCart(product = product)}

  {slot main}
</main>
```

Whether `Stock` and `AddToCart` are inline or islands is decided by their schemas (their `data` cache policy). The template reads the same either way.

### A component with children (`MaybeLink`)

```
{if link}
  <a href="{link.url}">{slot}</a>
{else}
  {slot}
{/if}
```

`link` is a prop of type `std.Link?`. `{if link}` narrows it, so `link.url` is valid. `MaybeLink` declares a default slot, so callers write it as a block.

### Loops and nullable handling

```
<ul class="gallery">
  {for img, i in images}
    <li class="n{i}"><img src="{img.src}" alt="{img.alt}"></li>
  {/for}
</ul>

<p>{subtitle ?? ""}</p>
```

---

## 14. Extension policy

Additive, never breaking:

- New functions, components, directives, and built-ins.
- New tags or keywords only if a real template cannot be written without them. Existing meanings never change.
- An unknown directive or function is always an error, so semantics are never silently ignored.

## 15. Open items

1. **Local variables** (`let name = expr`): deferred. Today, compute in Go or repeat the expression.
2. **Whitespace control** (a trim marker for tag lines).
3. **Passing values into a component that declares a `data` field**, and the exact schema syntax that declares a default slot or marks a function template-safe (both owned by the schema spec).
4. **Looping over slot children** with a wrapper per child (`{for child in main}`), limited to untyped, opaque children.
5. **Domain built-ins** (`money`, `date`, image helpers) in `std`: their exact set and shapes.
