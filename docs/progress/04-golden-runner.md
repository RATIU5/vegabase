# 04 Golden runner

- Changed: added `dump_tokens` (`source/vega/dump.odin`) and the `golden_lexer` test (`golden_test.odin`); `.gitignore` allows `tests/`.
- Works: `golden_lexer` walks `tests/golden/lexer/**`, dumps each `.vega` and compares it with its `.tokens`; `-define:VEGA_UPDATE_GOLDEN=true` rewrites them.
- Works: format is `Kind@start..end line:col "text"`, tokens indented under `Block@…`, then `Error@…` lines.
- Works: two cases, `words/type-and-name` and `errors/unknown-escape`.
- Next: golden cases for `words/` and `literals/`.
