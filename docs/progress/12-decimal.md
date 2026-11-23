# 12 Decimal

- Changed: D-71 makes `Decimal` a built-in type: exact base-10, `Int` limits, output in shortest exact form; D-70 adds the `1.5` literal; `Int` with `Decimal` gives `Decimal`.
- Changed: `vega.lark` has `DECIMAL`; `bad/decimal-number` moved to `good/`; new bad cases for `.5`, `1.`, `1e3` and `1.2.3`.
- Changed: the lexer's `lex_number` emits `Int` or `Decimal` and reports no errors; `1.`, `1e3` and `1.2.3` are left for the parser.
- Works: golden `literals/decimals` replaces `errors/decimal`.
- Next: run scan and lex on every prefix of every spec file: no crash, at most one error.
