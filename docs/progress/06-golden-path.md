# 06 Golden path

- Changed: `golden_test.odin` finds `tests/golden/lexer` from `#directory`, and reports a walk error once, after the loop.
- Works: `odin test source/vega` passes from the repo root, from `source/vega` and from any other directory.
- Next: one shared `fail` proc for the scanner and lexer.
