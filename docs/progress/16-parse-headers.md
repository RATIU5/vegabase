# 16 Parse headers

- Changed: `tree.odin` has the `File` tree: typed arrays with a dummy at index 0, `Range` children, `template_type` on `File`.
- Changed: `parse.odin` parses the first block on the caller's allocator: `use`, `template` and declaration headers; it stops at the first error.
- Changed: a reserved word or a name that is a language code names a locale; bodies and alias right sides are skipped by bracket matching for now.
- Changed: `dump_tree` prints the tree; `golden_parser` checks `tests/golden/parser/{decls,errors}`; the lexer goldens are unchanged.
- Next: fields, types and records replace the body skip.
