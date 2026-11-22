# 05 Golden cases: words and literals

- Changed: `dump_tokens` uses one `errors` array; `first_difference` shadows its parameters; the runner compares whole files first and reports a difference only in trailing lines.
- Changed: ten golden cases: `words/` reserved, member-after-dot, end-tags, number-then-word, underscore-names; `literals/` strings, multibyte-string, numbers, host-values, comments.
- Works: each case's `.tokens` was checked by hand against its input bytes.
- Next: golden cases for `operators/`, `locale/` and `errors/`.
