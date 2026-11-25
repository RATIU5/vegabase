# 24 Tag nesting

- Changed: `nest_part` keeps a stack of open `if` and `for` tags, as `check.py` does: closers must match, `elif` and `else` need an open `if` with no `else` yet, and an unclosed tag is an error on the innermost one.
- Changed: `closes` links each branch to the next (`if` → `elif` → `else` → `/if`, `for` → `/for`) and each end back to its opener.
- Works: goldens `parts/nested-if-in-for` and six nesting error cases; all 15 examples and 12 good files parse, and all 28 bad files fail with exactly one error.
- Next: make the spec-files test hold `parse` to that rule.
