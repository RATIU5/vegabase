# 01 Scanner

- Changed: added `source/vega/` with `Span`, `Error` (`tree.odin`) and `scan` (`scan.odin`), a port of `blocks()` in `docs/specs/grammar/check.py`.
- Changed: `mise run lint` and `mise run test` now also check and test `source/vega`.
- Works: `scan` splits a file into `{{ }}` blocks; the gaps are HTML text. It reports "{{ is never closed", "string is never closed" and "} with no {", and stops at the first error.
- Works: it finds `{{` with SIMD `index_byte`, and a comment's search for `}}` stops at its line end.
- Works: every file in `examples/` and `grammar/good/` scans; in `grammar/bad/` only `unclosed-block.vega` fails at this layer.
- Next: the lexer, which turns one block into tokens with spans.
