# 18 Nesting limit

- Changed: `parse_record` counts nesting depth on the parser; past `MAX_NESTING` (64) it reports "nesting is too deep" on the `{` that goes too far.
- Works: goldens `errors/nesting-at-limit` (64 levels parse) and `errors/nesting-too-deep` (65 fail); test `nesting_too_deep` parses 100000 levels without a stack overflow.
- Next: expressions, sharing the same depth counter.
