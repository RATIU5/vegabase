# 10 Golden cases: errors

- Changed: `errors/` decimal, star, trailing-minus, equal-bang, underscore-start, invalid-utf8, invalid-utf8-in-string, lone-cr, bare-dollar, bare-bang, end-tag-prefix (`/iffy`).
- Changed: scanner errors after good blocks: unclosed-block, stray-close-after-blocks; `literals/crlf` shows `\r\n` as one `Newline`.
- Works: each case's `.tokens` was generated with `VEGA_UPDATE_GOLDEN`, then checked by hand against its input bytes.
- Next: run scan and lex on every prefix of every spec file: no crash, at most one error.
