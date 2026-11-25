# 17 Fields, types and records

- Changed: `parse.odin` parses component and content bodies (admin, fields, props), aliases with admin, and locale records; a repeated group is an error.
- Changed: `parse_types.odin` parses named, plugin, literal and union types, limits and records; nested children go through scratch stacks, so every `Range` is contiguous.
- Changed: expressions are skipped by `skip_expr`, which stores a placeholder `Expr` with the skipped span; change 18 replaces it.
- Works: every file in `examples/` and `good/` parses; new goldens in `parser/fields/` and six new error cases; `errors/unclosed-bracket` removed because the scanner already balances braces.
- Next: expressions.
