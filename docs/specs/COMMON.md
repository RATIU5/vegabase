---
status: draft
updated: 2026-11-08
---

# Shared language rules (`.vegs` and `.vegt`)

Rules both languages share. Schema-only rules are in VEGS.md and VEGS-DATA.md; template-only rules are in VEGT.md. Index and term map: README.md.

**Design rules**

- Structure is words; decoration is directives. `@` directives only decorate or constrain. They never set a field's role or a tag's kind.
- Values are pure literals. Expressions appear only where a spec allows them (§4).
- File names and folders carry no meaning in either language. Identity comes from the namespace.
- Undefined is an error. An unknown name, directive or function is never silently ignored.
- Extend by adding names, never by changing syntax or meanings (§7).

---

## 1. Files and namespaces

The host scans the theme and every enabled extension for `*.vegs` and `*.vegt` files. The loader assigns each file a **namespace**. This is a host rule, not a language rule.

| Namespace         | Files                                    | Who implements its functions and directives |
| ----------------- | ---------------------------------------- | ------------------------------------------- |
| `theme`           | the tenant's theme                       | nobody: a theme declares no functions or directives (VEGS §4.4) |
| `std`             | first-party declarations shipped by the core | the core                                |
| an extension name | files of a vendor lib (`shopify`) or plugin | that extension (VEGS §4.4)               |

- A **bare name** resolves to the file's own namespace, then to the core names (core types, core directives, built-in functions).
- A name from any other namespace is **qualified** (`ns.Name`, `ns.fn`) and needs a `use` line in that file (§2).
- Names are unique per namespace across all its files. A duplicate is an error that names both file paths.
- Every declaration is visible to every file. There is no export keyword; `@internal` limits use to the own namespace (VEGS §6.4).
- `theme` and `std` are reserved. An extension cannot use them. Redeclaring a core name is an error.
- **Identity.** Every type has one identity, `ns.Name` (`theme.Hero`, `shopify.Hero`). The same name in two namespaces is two types. Stored content records the identity, and the admin app shows it (namespace badge plus source path) wherever a component is listed.

## 2. Imports: `use`

Written `use shopify` in `.vegs` and `{use shopify}` in `.vegt`.

- `use` imports a **namespace**, never individual names. Names stay qualified at each use site.
- `use` comes first in the file, before any declaration, tag or output.
- `use` is non-transitive: it affects only its own file.
- `use shopify as shop` renames the namespace inside that file only. The alias must not collide with another namespace or with a name declared or in scope in that file.
- A `use` is required for every qualified reference in the file: types, functions, directives, `@global` fields, `t(...)` keys.
- The file's own namespace and the core names need no `use`. `use theme` is an error.
- Unknown namespace: error. Duplicate `use`: error. Unused `use`: warning.

## 3. Lexical

| Item           | Rule                                                      |
| -------------- | --------------------------------------------------------- |
| Strings        | `"..."`, escapes `\" \\ \n \t \uXXXX`                     |
| Int            | `42`, `-7` (64-bit)                                       |
| Decimal        | `19.99d`, `0d`. Must end in `d`                           |
| Float          | **Not supported.** `1.5` is a lex error                   |
| Bool / null    | `true` `false` `null`                                     |
| `Upper` ident  | `[A-Z][A-Za-z0-9]*`: type names                           |
| `lower` ident  | `[a-z_][A-Za-z0-9_]*`: fields, params, variables, functions, directives, namespaces, locale tables |
| Qualified name | `ns.Name` or `ns.name`                                    |

Comments, separators and keywords differ per language: VEGS §2, VEGT §2.

## 4. Expressions

One grammar. Each context allows a subset of it.

```
expr      = orexpr ;
orexpr    = andexpr { "or" andexpr } ;
andexpr   = notexpr { "and" notexpr } ;
notexpr   = [ "not" ] cmp ;
cmp       = coalesce [ ( "==" | "!=" | "<" | "<=" | ">" | ">=" ) coalesce
                     | "in" ( listlit | coalesce ) ] ;
coalesce  = pipe { "??" pipe } ;
pipe      = postfix { "|" qident [ "(" [ narg { "," narg } ] ")" ] } ;
postfix   = primary { "." IDENT } ;
primary   = literal | IDENT | call | "(" expr ")" ;
call      = qident "(" [ narg { "," narg } ] ")" ;
narg      = IDENT "=" expr ;
listlit   = "[" [ literal { "," literal } ] "]" ;
literal   = STRING | INT | DECIMAL | "true" | "false" | "null" ;
qident    = [ IDENT "." ] IDENT ;
```

**Precedence**, tightest first: access and call, pipe, `??`, comparison and `in`, `not`, `and`, `or`. `not a == b` means `not (a == b)`.

| Context             | Names in scope                                   | Allowed                                                                 |
| ------------------- | ------------------------------------------------ | ----------------------------------------------------------------------- |
| `@show` (VEGS §7.3) | sibling props of the same record                 | literals, names, comparisons, `in` with a list literal, `and` `or` `not`, calls to a `fn` |
| `@validate(check = ...)` (VEGS §7.4) | `value` (the field's own value) and sibling props | exactly one call to a `fn` or `loader`, whose arguments are names or literals |
| Template (VEGT §6)  | loop variables, subject fields, `@global` fields | the whole grammar                                                       |

Rules for every context:

- **Calls** take named arguments only (`f(a = 1)`). A parameter with a default may be omitted. A positional, unknown, duplicate or missing required argument is an error. Only a function with a return value can be called.
- `==` and `!=` compare two values of the same type; either side may be `null` when the other is nullable.
- `<` `<=` `>` `>=` apply only to two `Int`s or two `Decimal`s. Ordering on `Text` or any other type is an error.
- `x in [list]` is true when `x` equals an item; item types must match `x`. In templates, `x in list` also takes a list value, and `"a" in text` tests for a substring (both `Text`). A list literal is valid only on the right of `in`.
- `x ?? y` (templates only): the left side must be `T?`; the result is `T` when `y` is `T`, else `T?`. `y` is evaluated only when `x` is `null`.
- `expr | f(...)` (templates only) is exactly `f(<first param> = expr, ...)`. Piping into a function with no parameters, or naming its first parameter again, is an error.
- A qualified name whose first part is a namespace in scope is a qualified reference; otherwise `a.b` is field access. A field or variable named like a namespace in scope is an error.
- No arithmetic, no assignment, no `?.`. Computing belongs in functions.
- An unknown name or field, or a type mismatch, is a `check` error.

## 5. Directives

```
@name
@name(value)
@name(key = value, key = value)
```

- Every directive is **declared** with the `directive` declaration (VEGS §4.5): core directives by the core, others by an extension. The declaration fixes the targets and parameter types. Placement rules per language: VEGS §7.1, VEGT §9.
- A directive with exactly one parameter may take it positionally (`@max(80)`). Otherwise arguments are named. A directive with no parameters takes no parentheses (`@internal`).
- A bare `@name` resolves to the file's own namespace, then to the core directives. Other namespaces are qualified (`@shopify.swatch`) and need `use`.
- An unknown directive, a directive on a target it does not list, or a bad argument is an error. None of these checks runs extension code.
- Schema directive arguments are literals, `t(...)`, or a function name, except where a directive declares an expression (`@show`, `@validate(check = ...)`). Template directive arguments are expressions in the tag's scope.

## 6. `check`

`check` is the type checker in the language toolchain (D-012). Developers run it locally; the deploy pipeline runs the same packages on deploy, and the admin app runs the content rules on save.

| Level   | Meaning                                                                                                    |
| ------- | ---------------------------------------------------------------------------------------------------------- |
| Error   | The theme or extension does not deploy                                                                     |
| Warning | Reported; deploy continues                                                                                 |
| Content | A stored value breaks a rule (an empty required field, an invalid value). The admin app keeps it as a draft and will not activate it (Q-034) |

Flags: `check --expand` prints each slot's resolved component set with identity and source file. `check --data` reports stored-data drift (VEGS-DATA §9).

Rule lists: VEGS §10, VEGS-DATA §10, VEGT §10.

## 7. Extension policy

- New directives, core types, built-in functions, declaration kinds and directive parameters are added without breaking existing files.
- New syntax (tags, keywords, operators) is added only when a real file cannot be written without it.
- Existing meanings never change. A shipped feature is removed only under its own D- entry (D-014).
