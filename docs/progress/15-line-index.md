# 15 Line index

- Changed: `lines.odin` adds `line_starts` (one exact allocation) and `line_col` (binary search, 1-based line and byte column).
- Changed: `dump.odin` uses them; the forward-only `Position` and `locate` are gone.
- Works: `lines_test.odin` covers an empty source, end of file, `\n`, `\r\n` and blank lines; lexer goldens pass unchanged.
- Next: the `File` tree types, `parse` for the first block, and the parser golden runner.
