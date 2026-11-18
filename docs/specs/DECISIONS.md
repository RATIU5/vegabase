---
status: draft
updated: 2026-11-18
---

# Language decisions, open questions, prior art

Each entry states the current rule. IDs are local to `docs/specs/` and are cited elsewhere as `lang D-59` and `lang Q-10`; entries of `core/DECISIONS.md` are cited as `core D-031`. IDs are never reused, and a missing number was withdrawn. Earlier wording is in git history.

Status words: a **D-** entry is decided by the project lead. An *Open* point inside an entry, and every **Q-** entry, has no answer and must not be assumed. The lead has the final say.

## Decisions

### Scope and host

**D-2 Rendering runs in the core.** Serve mode renders production traffic; admin mode renders for the admin. The specs set no compile-to-another-target requirement.

**D-3 Data comes from many sources.** A StardustDB server holds pages, content and admin data; third-party APIs supply the rest. The language cannot assume one data source.

**D-13 No pages in code.** Pages are defined only in the admin. Code defines plugins, locales, components, content types, js and css, plus one root settings file. Folders carry no meaning. *Open:* the format of the settings file; links to entity pages.

**D-28 The language never names the CMS, only a host.** Everything from outside a file arrives through three host-supplied things: field values, loaders and `$` values. An admin setting is ignorable by any host (D-22).

**D-30 The language works with and without a CMS.** A host program passes field values, loaders and `$` values and receives HTML. How a host embeds the renderer stays out of the specs.

### Files and names

**D-10 The delimiter is `{{ }}`.** One delimiter for output, tags and declarations. *Why:* single braces clash with literal braces in JSON-LD, inline CSS and JS.

**D-16 One file type, `.vega`.** A file may hold declarations, a template, or both. A component may be one file or split across two.

**D-17 `{{ }}` wraps all code that is not HTML, as a block or inline.** A `.vega` file is HTML by default. Declarations appear only in the first block of the file; later blocks hold tags and output.

**D-18 `.` is the only name separator.** `std.Image`, `std.empty(...)`, `shopify.money`.

**D-19 Any code inside `{{ }}` works inline and in a block.** No rule depends on line position.

**D-9 Every file that reads a value typed by a library names that library with `use`.** This holds however the value arrived, including a value a parent passed. A component's own fields need no `use`.

**D-24 A name the theme declares is written bare and is visible from every file.** There is no `theme.` prefix and no `use theme`. A prefix always names a library. Declaring the same name twice is an error naming both places. *Open:* whether declaring a built-in name is an error.

**D-68 Nineteen words are reserved.** `of`, `use`, `template`, `component`, `content`, `fields`, `props`, `locale`, `slot`, `render`, `if`, `elif`, `else`, `for`, `in`, `not`, `true`, `false`, `null`. None can name a field, a prop, a loop item or a locale key. Any word may follow a `.`, so `site.locale` is valid.

**D-25 Cycles.** Errors: an alias cycle; a type that contains itself directly, not through `List` or `?`; a `render` cycle. Allowed: a slot that accepts its own component, because stored content is finite. Declaration order and file order never matter.

**D-39 A comment starts with `#` inside `{{ }}`.** It runs to the end of the line or to `}}`, whichever comes first, and outputs nothing. A literal `{{` in the output is written as a string, `{{"{{"}}`. *Open:* a comment that holds `}}`.

### Brackets, types and limits

**D-43 Function arguments are passed by position only.** `std.take(galleryLimit)`, `std.imageUrl(1200, 630)`.

**D-44 A type's limits go in a `{ }` block after the type.** `Text { max = 80 }`, `Int { min = 0, max = 90 } = 40`, `Text { max = 160 }?`. The order on a field line is: type, limits, `?`, default, admin block. A pattern is a string: `pattern = "^[a-z-]+$"`. *Why:* `Text(80)` does not say minimum or maximum.

**D-45 Entries are separated by a comma or a newline.** Entries that share a line need a comma. Entries on separate lines need none; a comma at a line end is allowed. This covers every `{ }` and `[ ]` list and the arguments in `( )`. *Open:* where a long value may break across lines; whether the formatter removes commas at line ends.

**D-47 A lowercase name with `( )` is a function call; a capitalised name with `{ }` is a type being filled in.** `( )` holds bare values by position. `{ }` holds `name = value` entries in any order. A `name =` never appears inside `( )`. Types start with a capital letter and every other name starts lowercase; the checker enforces it. `[ ]` holds a list of values.

**D-50 The list type is `List { of = T }`.** `List { of = shopify.Variant }`, `List { of = Text, min = 1, max = 12 }`. No capitalised name is followed by parentheses anywhere in the language. Inside a `{ }` block, `of` is the only entry that takes a type; every other entry takes a value.

**D-26 `|` is both the union and the pipe.** A union sits in a type, a pipe in a value. There is no `|>`.

**D-29 A group is a named union.** `Blocks :: Title | Price | BuyButton`, used as `slot Blocks { min = 1, max = 12 }`. There is no `group` construct. A new component is added to the union by hand. *Open:* a warning for a component that no slot accepts.

**D-41 `std.asset` takes a literal path; link fields have the type `std.Url`.** `std.asset("theme.css")`: the check fails if the file does not exist. `std.Url` allows `http`, `https`, `mailto`, `tel` and relative paths; anything else is rejected on save.

### Components, fields and props

**D-7 One construct: the component.** A component may or may not have a slot. "Section" and "block" are not words in the language. Where a component may be placed is stated by the slot that accepts it.

**D-59 `component` has a `fields { }` block and a `props { }` block.** `fields` holds what an editor fills in: fields, slots, pickers, limits and admin blocks; the host stores it and the admin shows it. `props` holds what code passes or loads; the admin never sees it. Both are optional. A template reads fields and props by bare name. A field and a prop with the same name is an error. The admin offers a component only if a union used by a slot lists it; a component in no union is code-only. A component with no fields that a union lists is still offered.

**D-60 A component's own `@{ }` block sits at the root of `component { }`, outside `fields`.** *Open:* a warning for an admin block on a component that no union lists.

**D-61 A template names its component with `template Name`.** The line sits in the first block, and is required in every file that has HTML, also when the component is defined in the same file. Errors: HTML in a file with no `template` line; two `template` lines in one file; two files that supply a template for one component; a `template` line in a file with no HTML.

**D-51 Fields and props are separate.** Three prop forms: `product: shopify.Product` (a parent must pass it); `product: shopify.Product = $shopify.product` (a parent may pass it, else the page supplies it); `site: std.SiteSettings = std.siteSettings()` (the engine loads it). *Why:* developers pass values to child components, and that must never show in the admin.

**D-22 An admin setting is metadata only.** Deleting every admin block changes neither the stored data nor the HTML. A constraint is a limit on the type (D-44), never an admin setting. *Open:* where a custom validation message goes.

**D-46 Admin settings sit in one `@{ }` block.** `subheading: Text { max = 160 }? @{ label = "Subheading" }`. The block holds `name = value` entries: `label`, `hint`, `show`. Everything that starts with `@` is for the admin and nothing else is. There is one spelling; `@label("X")` is not allowed.

**D-27 `show` hides a field in the admin; `if` never wraps a field.** Every field is always stored, so a condition never changes the stored shape. `if` is for HTML, values, and attributes inside a tag. `use` and declarations never sit inside `if`.

**D-48 `slot` is a word in front of the type.** `blocks: slot Blocks { min = 1, max = 12 } = [ BuyButton {} ]`.

**D-55 A field whose type names a stored thing is a picker.** `product: shopify.Product @{ label = "Product" }`, `image: std.Image`. The admin shows the picker, the host stores a reference, and the engine supplies the full value at render. A list of picks is `List { of = shopify.Product, max = 4 }`. `std.Url` is a plain input checked on save, not a picker. *Open:* what a picker field without `?` holds after its entry is deleted.

**D-63 `content` defines a content type.** A content type is the shape of a thing an editor creates many of and does not place on a page: a blog post, a recipe, an event. `Recipe :: content { @{ label = "Recipe" } fields { ... } }` has the shape of a component with no `props` and no template. A theme or a plugin may declare one. A field of that type is a picker. *Open:* who owns and stores the entries of a theme's content type; how a component loads one entry or a list; the `$` value on an entry's own page; whether a content type may hold a slot; a plain group of fields with no entries of its own.

### Data

**D-35 There is no `global` construct.** A component that needs site-wide data declares it as a prop: `site: std.SiteSettings = std.siteSettings()`. Every name a template reads is declared by its own component.

**D-42 Equal loader calls run once per render.** Two props that call the same loader with equal arguments, in one component or in several, cause one request. The engine reads every data need before rendering.

**D-53 A loader may read a prop or a field.** `similar: List { of = shopify.Product } = shopify.recommendations(product)`. The engine orders the fetches. A loop between loaders is an error.

**D-38 A loader that finds nothing: the type decides.** With `Type`, the host stops and renders the site's not-found page with status 404; that page is an ordinary admin page. With `Type?`, the value is null and the template handles it with `if` or `??`. A template never sets a status and never redirects.

**D-52 A page value is written with `$`, and a plugin declares which kind of page supplies it.** `product: shopify.Product = $shopify.product`. The plugin declares a kind of page, such as a product page, with its URL shape and the values it supplies. The type of a page value is checked from code; whether a given page supplies it is checked by the host when the component is placed. *Open:* how a plugin declares a kind of page.

**D-65 `$` marks a value the host supplies; `$id` is the id of the placed component.** `<section id="{{$id}}">`. `$id` is a `Text`, unique on the page and safe as an HTML id. A template reads only its own; there is no `child.id`. *Open:* whether a parent builds a wrapper's id from its own id and the position, `id="{{$id}}-{{i}}"`; whether `$id` is the same on every render; the id of a component output by `render`.

### Slots in a template

**D-12 A parent can pass data to the components in its slot, and the child's props type it.**

**D-49 A parent passes values to a slot in a field block.** `{{slot blocks { product = product } }}`. A slot that passes nothing is `{{slot head}}`. `render` takes the same form: `{{render ProductCard { product = item } }}`. The parser counts braces, so `}}}` also parses.

**D-54 A value passed to a slot flows down to every block inside it.** Components in between write nothing. The nearest passed value wins. For every component with a prop that must be passed, the checker proves that every chain of slots that can reach it, through the unions, passes that name with a matching type. *Why not a `pass` keyword:* the same cost and more lines.

**D-62 A parent may loop over the children of a slot.** `{{for panel in panels}} ... {{slot panel}} ... {{/for}}`. `{{slot panels}}` is the short form that outputs every child with no wrapper. Limits: (1) a slot allows only `for`, `std.empty` and `std.length`, so code never hides what an editor placed; (2) every child is output exactly once: the template uses the short form once, or exactly one loop over the slot holds one `{{slot child}}` with no `if` between the `for` and it; another loop over the same slot may read fields but not output, and an `if` around the whole loop is allowed; (3) a parent reads fields only, never props, and only fields that every component in the slot's union has with the same type; (4) no branching on which component a child is. *Why exactly once:* a child output twice would write the same `$id` twice. *Open:* how a URL asks the host for one component alone.

**D-31 A page's root is a shell component with `head` and `body` slots.** Metadata is an ordinary component in `head`. The `head` slot has default content, which a page replaces with its own metadata component. Inside that component, nullable fields override and `??` falls back: `title ?? product.title`. *Open:* how the host knows which component is the shell (Q-40); where site-wide editor settings live (Q-27).

### Output

**D-21 A value standing alone is output.** A statement inside `{{ }}` is a declaration, a tag or a value. A value is written at that position, escaped for it. There is no output keyword.

**D-37 The type decides escaping; there is no `raw`.** Every value is escaped for its position: text, attribute or URL. Only a `std.RichText` value is output as HTML, and only between tags. A template cannot turn `Text` into HTML. Whoever produces a `RichText` cleans it: the host on save, or the library that loads it. The language cannot check that a library's `RichText` is clean.

**D-33 A pipe mixed with another operator needs parentheses.** `(a ?? b ?? c) | std.imageUrl(1200)`. A pipe alone needs none. `x | std.length > 0` is an error.

**D-40 There is no whitespace syntax.** (1) A line that holds only a tag or a comment leaves nothing behind, not even its newline. (2) Whitespace inside an HTML start tag is normalised. (3) All other whitespace is kept as written.

**D-15 Not borrowed from DUST: truthiness and `is ... as` narrowing.** Odin stays an influence on declaration syntax: `::` for what is known up front, `:` for a value of a type.

### Translations

**D-36 `locale` is the word for a table of translations for one language.**

**D-34 Translation keys are strings.** `t("hero.label")`, so a key cannot be mistaken for a field. A key missing from any locale table is a check error. There is no fallback to another locale.

### Plugins

**D-8 A plugin ships the typed shape of its data.** The theme author never writes it.

**D-56 A plugin's shape carries a name, a type and a one-line description for everything it offers.** An editor lists what `shopify.` and `$shopify.` offer, with argument names shown while typing. Positional arguments (D-43) depend on this.

**D-64 A plugin may ship anything a `.vega` file can hold, and more.** A plugin may define components, unions, aliases, content types and locales. In a theme, a plugin's names keep their prefix, and the admin offers a plugin component only when a theme union lists it: `Sections :: Hero | maps.Map`. A plugin can also define loaders, kinds of page and form actions. A theme cannot replace a plugin component in the first edition; it writes its own and lists that one. *Open:* how a plugin declares a loader, a kind of page, a function or an action; how a `.vega` file is tied to its plugin; whether a plugin writes its own names bare inside its own files; whether form actions are in the first edition (Q-16).

**D-66 A vendor lib is a plugin that the core team maintains as first-party.** The language has one kind of extension. `shopify` is a plugin; what sets it apart is who maintains it.

**D-67 First-party plugins run as native code; every other plugin runs in WASM.** The contract is the same for both. (1) A plugin may `use` a first-party plugin, and the admin refuses to enable it unless that plugin is enabled. (2) Dependencies point one way: a first-party plugin never depends on another plugin, and no plugin depends on one that is not first-party. (3) The dependency covers types and data only: the core hands a plugin the fields it declared it reads, and a plugin's code never calls another plugin. (4) No WASM runs while a page renders, so only the core and first-party plugins supply functions a template calls.

## Open questions

| ID | Question | Notes |
| --- | --- | --- |
| Q-10 | Does a template have local names? | The brief says "variables are immutable", which presumes they exist. Needs two examples |
| Q-11 | Which engine features enter the first edition: cache windows, timeouts, fallbacks, routes, actions? | None of the five PoC criteria needs them |
| Q-12 | Which data sources does the PoC use? | Local fixtures only · StardustDB · one third-party API |
| Q-16 | Are writes from a template (forms, fetch to a plugin) in the first edition? | No PoC criterion needs a write |
| Q-24 | What happens to a passed value that a slot child does not declare? | Each child takes only what it declares · every child must declare it |
| Q-26 | How does a component read a query-string value, such as a page number or a filter? | A query value can be absent, so it needs a default |
| Q-27 | Where do site-wide editor settings live (logo, colours, menus)? | The examples lean on `std.SiteSettings` |
| Q-29 | Can a value reach `style`, a CSS custom property, JSON-LD or a script expression? | Each is a new escaping position |
| Q-31 | How does a template name a form target? | The examples hand-write `/cart/add` |
| Q-32 | Is `use std` exempt from the `use` rule? | Most files need it |
| Q-33 | Do translations take values and plural forms? | |
| Q-35 | Constructs the examples use with no decision | `Text`, `Int`, `Bool` as built-ins · `elif` · `for item, i` and whether `i` starts at 0 or 1 · the alias form `Name :: Type` · a union of string literals · comparison operators and `not` · what an `if` condition may be · how a pipe passes its left value · `for ... else` |
| Q-39 | How do a component's CSS and JS work? | Proposed: `<style>`, `<script>` and `<link>` pass through as plain HTML; `{{ }}` inside `<style>` or `<script>` is an error |
| Q-40 | How does the host know which component is the shell? | |
| Q-41 | How is per-visitor data, such as a cart, kept out of shared cached output? | |
| Q-52 | Can code fill a slot, and how does a parent pass the markup? | A slot in `props` would be filled by code. No example needs it yet |

## Prior art

### Template language

| ID | Source | Borrow | Avoid |
| --- | --- | --- | --- |
| PA-1 | Liquid | Sections and blocks as the mental model; pipes that read left to right | Undefined renders as an empty string; untyped globals; `assign` and `capture`; two delimiters plus `-` markers; schema JSON inside the template |
| PA-2 | Go `html/template` | Escaping decided by where the output sits | The `.` cursor that changes meaning inside blocks; errors only at render |
| PA-3 | Svelte, Astro, JSX | Typed props; components with slots | Script blocks, reactivity, host-language expressions |
| PA-4 | Handlebars, Mustache | Logic lives outside the template | Untyped helpers; `{{{ }}}` one keystroke from unescaped output |
| PA-5 | Jinja, Twig | Block tags with named closers | Macros, template inheritance, `set` |

Also noted: Elm and Rust compiler messages as the bar for error quality. Askama and Templ as proof that checked templates are practical.

### Schema side

| ID | Source | Borrow | Avoid |
| --- | --- | --- | --- |
| PA-6 | Shopify section schema | A setting type maps to an editor input; blocks with limits; presets | JSON inside the template file; unchecked string ids; no reuse between sections |
| PA-7 | GraphQL SDL | Field lines `name: Type`; named types; lists | Nullable by default; directives as a catch-all |
| PA-8 | Prisma schema | One readable line per field; precise errors | Storage and relation mechanics mixed into the shape |
| PA-9 | Sanity, Contentful | References between content; field-level validation | Schemas written as code with validation callbacks |
| PA-10 | JSON Schema, CUE, Zod | Constraints as data: `min`, `max`, `pattern` | Verbose combinators; unification; code |
| PA-16 | DUST | Newline-separated lists; constraints as data; host-bound constants; four escape contexts | Runtime-only contracts, truthiness, mutation, recursion, macros |

Also noted: Protobuf's schema-evolution discipline (renames and removals against stored content), as a later concern.
