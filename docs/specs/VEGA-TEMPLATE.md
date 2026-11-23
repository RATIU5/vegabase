---
status: draft
updated: 2026-11-18
---

# The `.vega` language: templates

What the HTML part of a `.vega` file may hold: tags, slots, expressions and output. Declarations are in VEGA.md. Index and term map: README.md.

Citations and status marks follow VEGA.md: `lang D-59` is an entry of DECISIONS.md in this folder; *open* is not decided.

**Design rules**

- A template is pure: same data in, same HTML out, no side effects (brief).
- A template has no functions of its own, no assignment and no IO. A loop runs only over data (brief).
- A template never sets a status and never redirects. Redirects stay in the host and the admin (lang D-38).
- Every value that can be null must be handled, or the file fails the check (examples E-5a).

---

## 1. Binding

- `template Name` in the first block says that the HTML in this file is the template of the component `Name` (lang D-61). Its errors are in VEGA §5.
- The template reads the component's fields and props by bare name: `{{heading}}`, `{{product.title}}` (lang D-59).
- A component has exactly one template in the theme (lang D-61).

## 2. Statements

Inside `{{ }}`, a statement is a declaration, a tag or a value (lang D-21).

- A value standing alone is output at that position, escaped for it (§7). There is no output keyword (lang D-21).
- Declarations appear only in the first block of the file (lang D-17).
- A block may sit inline, `<h1>{{heading}}</h1>`, or span lines (lang D-17, D-19).

## 3. Tags

| Tag | Form | Entry |
| --- | --- | --- |
| `if` | `{{if cond}} ... {{else}} ... {{/if}}` | lang D-27 |
| `elif` | `{{elif cond}}` between `{{if}}` and `{{else}}` | lang D-73 |
| `for` | `{{for item in list}} ... {{/for}}` | lang D-73 |
| `for` with position | `{{for item, i in list}}` gives the position as `i`, starting at 1 | lang D-73 |
| `slot` | `{{slot blocks}}`, `{{slot blocks { product = product } }}` | lang D-49 |
| `render` | `{{render ProductCard { product = item } }}` | lang D-49 |

### 3.1 `if`

- `if` may wrap HTML, a value, or an attribute inside a start tag (lang D-27):

```
<button type="submit" {{if not product.available}}disabled{{/if}}>
```

- `if` never wraps a field, a `use` or any declaration (lang D-27).
- There is no truthiness (lang D-15). A condition is a `Bool`: a `Bool` value, a comparison, or those joined by `not`, `and` and `or`. A null test is a comparison: `{{if subheading != null}}` (lang D-73).

*Open:* which expressions narrow a nullable value, and whether narrowing reaches `else`, `elif` and `and`; `if` inside an attribute value.

### 3.2 `for`

- A loop runs over a list, or over the children of a slot (§4.2) (brief, lang D-62).
- An empty list is tested with `std.empty(list)`. There is no `for ... else` (lang D-73).

*Open:* whether a loop variable may share a name with a field.

### 3.3 `render`

- `render` outputs a component from code and sets its values in a field block (lang D-49).
- A prop that must be passed and is not is an error (lang D-51).
- A `render` cycle is an error: a template that renders itself, directly or through others (lang D-25).

*Open:* whether `render` may set a component's fields as well as its props; rendering a component that has a slot (lang Q-52).

## 4. Slots in a template

### 4.1 The short form

- `{{slot blocks}}` outputs every child of the slot, in order, with no wrapper (lang D-49, D-62).
- A parent passes values to its slot children in a field block: `{{slot blocks { product = product } }}` (lang D-49).
- A passed value flows down to every block inside the slot, and the nearest one wins (lang D-54, VEGA §7).

### 4.2 Looping over the children

A parent may loop over the children of a slot and output one child with `{{slot child}}` (lang D-62).

```
{{for panel, i in panels}}
  <section class="tab" id="{{$id}}-{{i}}">{{slot panel}}</section>
{{/for}}
```

Limits (lang D-62):

1. A slot allows only `for`, `std.empty` and `std.length`. Code cannot sort, cut or filter what an editor placed.
2. Every child is output exactly once. The template uses the short form once, or exactly one loop over the slot holds one `{{slot child}}` with no `if` between the `for` and it. Another loop over the same slot may read fields but not output. An `if` around the whole loop is allowed.
3. A parent reads a child's fields, never its props, and only a field that every component in the slot's union has with the same type: `{{panel.title}}`.
4. A template cannot ask which component a child is.

### 4.3 `$id`

- `$id` is the id of this placed component. The host supplies it. It is a `Text`, unique on the page and safe as an HTML id (lang D-65).
- A template reads only its own `$id`. There is no `child.id` (lang D-65).

*Open:* whether a parent builds a wrapper's id from its own id and the position, as the example above does (proposed in lang D-65); the id of a component output by `render`; how a URL asks the host for one component alone (lang D-62); slots that code fills (lang Q-52).

## 5. Expressions

| Form | Example | Entry |
| --- | --- | --- |
| field or prop | `heading`, `product.title` | lang D-59 |
| function call, values by position | `std.imageUrl(1200, 630)` | lang D-43 |
| pipe | `image \| std.imageUrl(800)` | lang D-26 |
| fallback for null | `text ?? t("product.add_to_cart")` | lang D-38 |
| comparison | `tone == "dark"`, `link != null`, `a > b`, `a <= b` | lang D-69 |
| `not` | `not variant.available` | lang D-69 |
| `and`, `or` | `a != null and a > b` | lang D-69 |
| arithmetic | `price * quantity`, `i % 2 == 0`, `-offset` | lang D-69 |
| translation | `t("hero.label")` | lang D-34 |

- A pipe passes the value on its left as the first value of the call on its right. A call with no other values needs no parentheses: `price | shopify.money` (lang D-33).
- A pipe mixed with another operator needs parentheses: `(a ?? b ?? c) | std.imageUrl(1200)`. `x | std.length > 0` is an error (lang D-33).
- A translation key is a string, so it cannot be mistaken for a field (lang D-34).
- Functions come from the core (`std`) and from first-party plugins (lang D-67). A template defines none.

- `and` or `or` joins comparisons without parentheses. Mixing `and` with `or` needs them. `not` applies to one value: `not (a == b)` (lang D-69).
- `*`, `/` and `%` bind tighter than `+` and `-`; arithmetic binds tighter than a comparison. Arithmetic mixed with `??` or a pipe needs parentheses: `(a ?? 0) + 1` (lang D-69).
- Arithmetic takes numbers only; `+` never joins text. `Int / Int` truncates toward zero. `a / b` and `a % b` may be null, because `b` may be zero: `(a / b) ?? 0`. A divisor that is a literal other than zero gives a plain value (lang D-69).

*Open:* local names in a template (lang Q-10).

## 6. `$` values

- `$` marks a value the host supplies (lang D-52, D-65).
- A page value is the default of a prop: `product: shopify.Product = $shopify.product` (lang D-52, VEGA §7).
- `$id` is read in the template (§4.3).

*Open:* whether a page value may be read directly in a template; query-string values such as a page number (lang Q-26).

## 7. Output and escaping

- Every value is escaped for its position: text, attribute or URL (lang D-37).
- Only a `std.RichText` value is output as HTML, and only between tags. A template cannot turn `Text` into HTML. There is no `raw` (lang D-37).
- Whoever produces a `RichText` cleans it: the host on save, or the library that loads it. The language cannot check that a library's `RichText` is clean (lang D-37).
- A `std.Url` is escaped for its position like any other value (lang D-41).
- `std.asset("theme.css")` takes a literal path. The check fails if the file does not exist (lang D-41).
- A literal `{{` in the output is written as a string: `{{"{{"}}` (lang D-39).

*Open:* values in `style`, CSS custom properties, JSON-LD and script expressions (lang Q-29); `<style>` and `<script>` in a template (lang Q-39); form targets (lang Q-31); per-visitor data such as a cart (lang Q-41).

## 8. Whitespace

There is no whitespace syntax (lang D-40).

1. A line that holds only a tag or a comment leaves nothing behind, not even its newline.
2. Whitespace inside an HTML start tag is normalised: `<option value="x" >` is output as `<option value="x">`.
3. All other whitespace is kept as written.

## 9. Check errors

Every row is an error before rendering.

| Error | Section |
| --- | --- |
| A value that can be null is output or used without a fallback or a null test | §3.1, §5 |
| A field that the type does not have | §5 |
| `if` around a field, a `use` or a declaration | §3.1 |
| A `render` cycle | §3.3 |
| A slot child output twice, not output, or output under an `if` inside its loop | §4.2 |
| A function other than `std.empty` or `std.length` applied to a slot | §4.2 |
| Reading a child's prop, or a field that not every component in the union has | §4.2 |
| A slot that does not pass a prop one of its children must be passed | §4.1 |
| A pipe mixed with another operator without parentheses | §5 |
| `name =` inside `( )` | §5 |
| A translation key missing from any locale table | §5 |
| `std.asset` with a path that is not a literal, or a file that does not exist | §7 |

## 10. Example

`Tabs.vega`, from `examples/`:

```
{{
  Tabs :: component {
    @{ label = "Tabs" }

    fields {
      panels: slot Panels { min = 1, max = 6 }
    }
  }

  template Tabs
}}
<div class="tabs" id="{{$id}}">
  <ul class="tab-bar">
    {{# a parent reads a child's fields, never its props }}
    {{for panel, i in panels}}
      <li><a href="#{{$id}}-{{i}}">{{panel.title}}</a></li>
    {{/for}}
  </ul>
  {{for panel, i in panels}}
    <section class="tab" id="{{$id}}-{{i}}">{{slot panel}}</section>
  {{/for}}
</div>
```
