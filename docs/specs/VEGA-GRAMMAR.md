---
status: draft
updated: 2026-11-18
---

# The `.vega` language: grammar

The syntax of the code inside `{{ }}`, as rules a tool can run. The rules are in `grammar/vega.lark`; this file explains them and lists what they had to assume. Declarations and templates are described in VEGA.md and VEGA-TEMPLATE.md. Index: README.md.

The grammar is a test of the spec, not the product's parser. It says which text is well-formed. It does not check types, names or any rule in the "Check errors" tables.

## 1. Running it

```
python3 -m pip install lark
python3 docs/specs/grammar/check.py
```

`check.py` parses every file in `examples/`, which must all pass, and every file in `grammar/bad/`, which must all fail. It exits 0 only when both hold. Today: fifteen examples pass, thirteen bad files fail, and no example can be read two ways.

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
| `STRING` | `"`, then any characters except `"` and a line break, then `"` |
| `INT` | digits |
| `HOST_VALUE` | `$`, then names joined by `.` |

Spaces and tabs are ignored. A line break separates entries inside `{ }` and `[ ]`, and is ignored inside `( )`.

## 5. What the grammar had to choose

The spec leaves each of these open. A grammar cannot, so `vega.lark` picks one answer. None is decided; each needs a ruling.

| # | Choice in the grammar | Open point |
| --- | --- | --- |
| 1 | Nineteen words are reserved: `of`, `use`, `template`, `component`, `content`, `fields`, `props`, `locale`, `slot`, `render`, `if`, `elif`, `else`, `for`, `in`, `not`, `true`, `false`, `null`. None can name a field, a prop, a loop item or a locale key. Any word is allowed after a `.`, so `site.locale` parses | VEGA §2 |
| 2 | Inside a `{ }` block, only the `of` entry takes a type. Every other entry takes a value. Without this, `label = "Hero"` reads as a value or as a string-literal type | lang D-50 |
| 3 | The operators are `not`, `==`, `!=`, `??` and the pipe. An expression uses one kind; any mix needs parentheses. There is no `and`, `or`, `<`, `>` or arithmetic | lang Q-35 |
| 4 | A field line and an expression cannot continue on the next line. Only a `{ }`, `[ ]` or `( )` may span lines | lang D-45 |
| 5 | A union may be written directly on a field: `tone: "light" \| "dark"` | lang Q-35 |
| 6 | A string has no escape, so it cannot hold `"`. A number is whole and has no sign | none yet |
| 7 | A locale name is a `NAME`, so `pt-BR` cannot be written | VEGA §9 |
| 8 | `{{}}` and a block that holds only a comment are valid and output nothing | lang D-39 |

Rules the grammar accepts but a check must reject:

- `component { }` may hold its admin block, `fields` and `props` in any order and more than once. "At most one of each" is a check rule.
- `fields` and `props` lines share one rule, so the grammar accepts `slot` and an admin block in `props`.

## 6. Not covered

- The HTML: tags, attributes, and whether a block sits in text, in a start tag or in an attribute value.
- `{{` inside `<script>` and `<style>` (lang Q-39).
- A comment that holds `}}` (lang D-39).
- Every type rule and every name rule.
