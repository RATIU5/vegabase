---
status: draft
updated: 2026-11-20
---

# The `.vega` language: grammar

The syntax of the code inside `{{ }}`, as rules a tool can run. The rules are in `grammar/vega.lark`; this file explains them and says what they do not cover. Declarations and templates are described in VEGA.md and VEGA-TEMPLATE.md. Index: README.md.

The grammar is a test of the spec, not the product's parser. It says which text is well-formed. It does not check types, names or any rule in the "Check errors" tables.

## 1. Running it

```
mise run test:grammar
```

`mise run test` runs it first, so CI runs it on every pull request. mise pins `uv`, and the task pins Lark.

`check.py` parses every file in `examples/` and `grammar/good/`, which must all pass, and every file in `grammar/bad/`, which must all fail. It exits 0 only when both hold.

## 2. Two layers

A `.vega` file is HTML with code blocks in it, so there are two layers.

**File layer**, done by a scanner in `check.py`:

- A block starts at `{{` and ends at the first `}}` that is outside a string, outside a comment, and not inside an open `{ }`.
- A comment starts at `#` and runs to the end of the line or to `}}`.
- A block at the very start of the file is the first block. Every other block is a later block.
- `if` and `for` must be closed by `/if` and `/for` in order. `elif` and `else` sit inside an open `if`, and nothing follows `else` but `/if`.

**Code layer**, the rules in `vega.lark`. It has two entry points:

| Entry point | Parses | Holds |
| --- | --- | --- |
| `first_block` | the first block | `use`, `template`, and declarations, one per line |
| `inline` | every later block | one tag, or one value, or nothing |

## 3. Reading the notation

| Form | Meaning |
| --- | --- |
| `a: b c` | rule `a` is `b` followed by `c` |
| `b?` | optional |
| `b*`, `b+` | zero or more, one or more |
| `b \| c` | either |
| `"if"` | that exact text |
| `NAME`, `TYPE` | a token, defined by a pattern at the end of the file |
| `_NL` | a line break |

## 4. Tokens

| Token | Pattern |
| --- | --- |
| `TYPE` | a capital letter, then letters and digits |
| `NAME` | a lowercase letter, then letters, digits and `_`; not a reserved word |
| `MEMBER` | the same as `NAME`, but any word; used after a `.` |
| `STRING` | `"`, then characters on one line, with `\"` and `\\` as the only escapes, then `"` (lang D-70) |
| `LOCALE_NAME` | a language tag: two or three lowercase letters, then parts of two to eight letters or digits, each after a `_` (lang D-36) |
| `INT` | digits, with an optional leading `-` (lang D-70) |
| `HOST_VALUE` | `$`, then names joined by `.` |

Reserved words (lang D-68): `of`, `use`, `template`, `component`, `content`, `fields`, `props`, `locale`, `slot`, `render`, `if`, `elif`, `else`, `for`, `in`, `not`, `and`, `or`, `true`, `false`, `null`.

Spaces and tabs are ignored. A line break separates entries inside `{ }` and `[ ]`, and is ignored inside `( )`. Nothing else may span lines (lang D-45).

## 5. Looser than the spec

The grammar accepts two things that a check must reject:

- `component { }` may hold its admin block, `fields` and `props` in any order and more than once. "At most one of each" is a check rule.
- `fields` and `props` lines share one rule, so the grammar accepts `slot` and an admin block in `props`.

## 6. Not covered

- The HTML: tags, attributes, and whether a block sits in text, in a start tag or in an attribute value.
- `{{` inside `<script>` and `<style>` (lang Q-39).
- A comment that holds `}}` (lang D-39).
- `<` and `>` inside a block that sits in an HTML start tag, such as `<p {{if a > b}}class="x"{{/if}}>`. The scanner here is not an HTML tokenizer, so it cannot show whether a real one copes.
- Every type rule and every name rule.
