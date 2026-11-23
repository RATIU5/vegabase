# 11 Arithmetic

- Changed: D-69 adds `+ - * / %`; `-` is negation, so `INT` is unsigned; `Int / Int` truncates; `a / b` and `a % b` may be null unless the divisor is a literal other than zero.
- Changed: `vega.lark` has `sum`, `product` and `unary`; `bad/arithmetic` moved to `good/`; new bad cases for arithmetic mixed with `??` or a pipe, `**` and a missing right side.
- Changed: the lexer emits `Plus`, `Minus`, `Star`, `Slash`, `Percent`; `/` is `End_If` or `End_For` only before the whole word `if` or `for`.
- Works: goldens `operators/arithmetic`, `minus`, `slash` replace the three error cases that are now valid.
- Next: the `Decimal` type and literal (D-70, D-71).
