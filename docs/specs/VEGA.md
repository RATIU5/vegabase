---
status: draft
updated: 2026-11-18
---

# The `.vega` language: declarations

What a `.vega` file may declare: names, types, components, content types, locale tables, and what a plugin adds. Tags, slots in a template, expressions and output are in VEGA-TEMPLATE.md. Index and term map: README.md.

**Citations.** `D-` and `Q-` numbers in this file are the entries of `docs/temp_lang_ctx/decisions.md`, written `lang D-59`, until they move into `core/DECISIONS.md`. Core entries are written `core D-031`.

**Status of every rule.** A rule with a `lang D-` number is decided. A rule marked *no entry* is shown in the examples but has no decision yet. A point marked *open* is not decided and must not be assumed.

**Design rules**

- The language never names the CMS. Everything from outside a file arrives through the host: field values, loaders and `$` values (lang D-28, D-30).
- A feature that cannot be checked before rendering is not in the language (brief).
- Undefined is an error. An unknown name is never silently ignored (examples E-5b).
- Any code inside `{{ }}` works the same written on one line or across several (lang D-19).

---

## 1. Files and blocks

- A `.vega` file is HTML. Code sits inside `{{ }}`, as a block or inline (lang D-10, D-16, D-17).
- Declarations appear only in the first `{{ }}` block of a file. Later blocks hold tags and output (lang D-17).
- A file may hold declarations, a template, or both (lang D-16).
- Folders and file names carry no meaning (lang D-13). Declaration order and file order never matter (lang D-25).
- Pages are defined only in the admin, never in code (lang D-13).
- `#` starts a comment. It runs to the end of the line or to `}}`, whichever comes first, and outputs nothing (lang D-39). *Open:* a comment that holds `}}`.
- The parser counts braces inside a block, so `}}}` closes a `{ }` and then the block (lang D-17, D-49).

## 2. Names

| Rule | Entry |
| --- | --- |
| `.` is the only separator in a name: `std.Image`, `shopify.money` | lang D-18 |
| A type starts with a capital letter. Every other name starts lowercase. The checker enforces it | lang D-47 |
| A name the theme declares is written bare and is visible from every file of the theme | lang D-24 |
| A prefix always names a library: the core's `std`, or a plugin | lang D-18, D-24 |
| `use name` in the first block names a library. Every file that reads a value typed by a library has `use` for it, however the value arrived | lang D-9 |
| Declaring the same name twice is an error naming both places | lang D-24 |

**Cycles** (lang D-25). Errors: an alias cycle; a type that contains itself directly, not through `List` or `?`; a `render` cycle. Allowed: a slot that accepts its own component.

*Open:* which words are reserved; whether a loop variable may share a name with a field.

## 3. Brackets and separators

| Form | Holds | Entry |
| --- | --- | --- |
| lowercase name with `( )` | a function call; values by position, never `name =` | lang D-43, D-47 |
| capitalised name with `{ }` | a type being filled in; `name = value` entries in any order | lang D-44, D-47 |
| `[ ]` | a list of values | lang D-47 |
| `@{ }` | admin settings; `name = value` entries | lang D-46 |
| `component { }`, `content { }`, `fields { }`, `props { }`, `locale { }` | a block that belongs to that word | lang D-36, D-59, D-63 |

- `fields { }` and `props { }` hold `name: Type` lines, not `name = value` (lang D-59).
- Entries are separated by a comma or a newline. Entries that share a line need a comma. A comma at a line end is allowed (lang D-45).

## 4. Types

### 4.1 Built-in and core types

| Type | Meaning | Entry |
| --- | --- | --- |
| `Text` | a string | used throughout; *no entry* |
| `Int` | a whole number | used throughout; *no entry* |
| `Bool` | true or false | *no entry* |
| `List { of = T }` | a list of `T` | lang D-50 |
| `std.Image` | a stored image; a picker in the admin | lang D-55 |
| `std.Url` | `http`, `https`, `mailto`, `tel` or a relative path; anything else is rejected on save | lang D-41 |
| `std.RichText` | the only value output as HTML | lang D-37 |

*Open:* decimal, date and colour types.

### 4.2 Limits, null and defaults

- Limits go in a `{ }` block after the type: `Text { max = 80 }`, `Int { min = 0, max = 90 }`, `List { of = Text, min = 1, max = 12 }`. A pattern is a string: `Text { pattern = "^[a-z-]+$" }` (lang D-44, D-50).
- `Type?` may be null. A type without `?` never is (lang D-38, examples E-5a).
- On a field or prop line the order is: type, limits, `?`, default, admin block (lang D-44, D-46).

```
overlay: Int { min = 0, max = 90 } = 40 @{ show = tone == "dark" }
```

### 4.3 Aliases and unions

- `Name :: Type` gives a type a name: `Headline :: Text { max = 80 }`. lang D-25 names aliases; the form itself has *no entry*.
- `A | B` in a type is a union. `|` in a value is a pipe; position tells them apart (lang D-26).
- A group of components is a named union. There is no `group` construct: `Blocks :: Title | Price | BuyButton` (lang D-29).
- A union of string literals is a fixed set of values: `Tone :: "light" | "dark"` (*no entry*).

## 5. Components

The component is the only unit of composition (lang D-7). "Section" and "block" are not words in the language.

```
Hero :: component {
  @{ label = "Hero banner" }

  fields {
    heading: Text { max = 80 } = "Welcome"
  }
  props {
    site: std.SiteSettings = std.siteSettings()
  }
}

template Hero
```

| Part | Rule | Entry |
| --- | --- | --- |
| `Name :: component { }` | defines a component | lang D-59 |
| `@{ }` at the root | the component's own admin settings, outside `fields` | lang D-60 |
| `fields { }` | what an editor fills in; the host stores it and the admin shows it. Optional | lang D-59 |
| `props { }` | what code passes or loads; the admin never sees it. Optional | lang D-51, D-59 |
| `template Name` | says the HTML in this file is the template of `Name` | lang D-61 |

- A field and a prop with the same name is an error (lang D-59).
- The template reads fields and props by bare name (lang D-59).
- The component may be defined in the same file as its template or in another (lang D-16, D-61).
- The admin offers a component only if a union used by a slot lists it. A component in no union is code-only and is output with `render` (lang D-59).
- The root of a page is a shell component with `head` and `body` slots (lang D-31). *Open:* how the host knows which component is the shell (lang Q-40).

**`template` errors** (lang D-61): HTML in a file with no `template` line; two `template` lines in one file; two files that supply a template for one component; a `template` line in a file with no HTML.

## 6. Fields

- Every field is always stored. A condition never changes the stored shape, so `if` never wraps a field (lang D-27).
- A field whose type names a stored thing is a picker: `std.Image`, a plugin type such as `shopify.Product`, or a content type (§8). The host stores a reference and supplies the full value at render (lang D-55, D-63). *Open:* what a picker field without `?` holds after its entry is deleted.
- A list of picks: `List { of = shopify.Product, max = 4 }` (lang D-55).

### 6.1 Slots

- A slot is a field: the word `slot` in front of a union or a component (lang D-48).
- The slot accepts the components its union names (lang D-7, D-29).
- A slot may have default content, a list of component values (lang D-31).

```
blocks: slot Blocks { min = 1, max = 12 } = [
  BuyButton {}
]
```

### 6.2 Admin blocks

- Everything that starts with `@` is for the admin and nothing else is. Deleting every `@{ }` block changes neither the stored data nor the HTML (lang D-22, D-46).
- Entries: `label`, `hint`, `show` (lang D-46).
- `show` hides a field in the admin when its condition is false. The field keeps its value (lang D-27).
- There is one spelling. `@label("X")` is not allowed (lang D-46).

## 7. Props

Three forms (lang D-51):

| Form | Meaning | Entry |
| --- | --- | --- |
| `product: shopify.Product` | a parent must pass it, on its `slot` or `render` line | lang D-49, D-51 |
| `product: shopify.Product = $shopify.product` | a parent may pass it; if none does, the page supplies it | lang D-52 |
| `site: std.SiteSettings = std.siteSettings()` | the engine loads it | lang D-51 |

- `$` marks a value the host supplies. A plugin declares which kind of page supplies a page value (lang D-52, D-65).
- A loader may read a prop or a field. The engine orders the fetches. A loop between loaders is an error (lang D-53).
- Equal loader calls run once per render, in one component or in several (lang D-42).
- A loader that finds nothing: with `Type`, the host stops and renders the site's not-found page with status 404. With `Type?`, the value is null (lang D-38).
- A value passed to a slot flows down to every block inside it, and the nearest one wins. Components in between write nothing (lang D-54).
- For every component with a prop that must be passed, the checker proves that every chain of slots that can reach it passes that name with a matching type (lang D-54). Whether a page supplies a `$` value is checked by the host when the component is placed (lang D-52).

## 8. Content types

A content type is the shape of a thing an editor creates many of and does not place on a page: a blog post, a recipe, an event (lang D-63).

```
Recipe :: content {
  @{ label = "Recipe" }

  fields {
    title:   Text { max = 80 }
    minutes: Int { min = 1 }
  }
}
```

- A theme or a plugin may declare one (lang D-63, D-64).
- It is written like a component: its own `@{ }` block, then `fields { }`. It has no `props` and no template (lang D-63).
- Its name is a type. As a prop it is a value a parent passes; as a field it is a picker (lang D-63).

*Open:* who owns and stores the entries of a theme's content type; how a component loads one entry or a list; the `$` value on an entry's own page; whether a content type may hold a slot; a plain group of fields with no entries of its own.

## 9. Locale tables

```
en :: locale {
  hero = {
    label = "Hero banner"
    button = "Shop now"
  }
}
```

- A `locale` table holds the translations for one language (lang D-36).
- A key is read as a string: `t("hero.label")`. A key missing from any locale table is a check error. There is no fallback to another locale (lang D-34).

*Open:* locale names that hold a hyphen, such as `pt-BR`; values and plural forms in a translation (lang Q-33).

## 10. Plugins

- A plugin may ship `.vega` files with components, unions, aliases, content types and locales (lang D-64).
- In a theme, a plugin's names keep their prefix, and the admin offers a plugin component only when a theme union lists it (lang D-64):

```
use maps

Sections :: Hero | maps.Map
```

- Only a plugin can define loaders, kinds of page and form actions (lang D-64). Functions a template calls come only from the core and from first-party plugins (lang D-67).
- A vendor lib is a plugin that the core team maintains as first-party. The contract is the same for both; the host runs a first-party plugin as native code and every other plugin in WASM (lang D-66, D-67).
- A theme cannot replace a plugin component in this edition. It writes its own component and lists that one in its union (lang D-64).
- A plugin may `use` a first-party plugin: `use shopify`, then `product: shopify.Product`. No plugin depends on a plugin that is not first-party (lang D-67).
- A plugin's shape carries a name, a type and a one-line description for everything it offers, so an editor can list what `shopify.` and `$shopify.` offer (lang D-56).

*Open:* how a plugin declares a loader, a kind of page, a function or an action; how a `.vega` file is tied to its plugin; whether form actions are in the first edition (lang Q-16).

## 11. Check errors

Every row is an error before rendering.

| Error | Section |
| --- | --- |
| A name declared twice, or an unknown name | §2 |
| A type that does not start with a capital letter, or another name that does | §2 |
| A value typed by a library in a file with no `use` for it | §2 |
| An alias cycle, a directly self-containing type, a `render` cycle | §2 |
| `name =` inside `( )` | §3 |
| A field and a prop with the same name | §5 |
| A `template` error | §5 |
| A prop that must be passed and is not, on any chain of slots that can reach it | §7 |
| A loop between loaders | §7 |
| A translation key missing from any locale table | §9 |

*Open:* the wording and layout of error messages (examples E-5 is a sketch).

## 12. Not in this edition

Removed from the earlier draft and not replaced: pages, routes and query declarations in code (lang D-13); `global` (lang D-35); `data` and `given` (lang D-51); `declare` and the naming line (lang D-59); `raw` (lang D-37); directives other than the admin block (lang D-46).

*Open:* whether cache windows, timeouts, fallbacks, routes and actions from the earlier draft return (lang Q-11).
