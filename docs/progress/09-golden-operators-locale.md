# 09 Golden cases: operators and locale

- Changed: `operators/` all, no-spaces (`a==b`, `a<-1`, `a!=-2`, `a::b`), admin (`@{ }` and `@ { }`).
- Changed: `locale/` tags (`en`, `pt_BR`, `zh_Hant` are `Name`s), hyphen (`pt-BR` fails at `-`).
- Works: each case's `.tokens` was generated with `VEGA_UPDATE_GOLDEN`, then checked by hand against its input bytes.
- Next: golden cases for `errors/`: decimal, `*`, unclosed block, and the other lexer and scanner errors.
