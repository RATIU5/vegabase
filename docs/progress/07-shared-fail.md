# 07 Shared fail

- Changed: `fail_scan` and `fail_lex` became one `fail` in `tree.odin`.
- Changed: messages used more than once are constants: `STRING_NEVER_CLOSED` (tree.odin), `BLOCK_NEVER_CLOSED` (scan.odin), `UNEXPECTED_CHARACTER` (lex.odin).
- Works: output is byte-identical; every test and golden passes unchanged.
- Next: one table-driven spec-file test for the scanner and lexer.
