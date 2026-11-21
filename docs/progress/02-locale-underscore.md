# 02 Locale names use `_`

- Changed: lang D-36, VEGA §9 and VEGA-GRAMMAR §4 write a locale name with `_` between its parts: `en`, `pt_BR`, `zh_Hant`. The host maps a tag's `-` to `_`.
- Changed: `vega.lark` `LOCALE_NAME` uses `_`; `good/locale-language-tags.vega` uses the new form.
- Changed: `locale-name-with-underscore.vega` moved from `bad/` to `good/`; new `bad/locale-name-with-hyphen.vega` and `bad/locale-name-too-long.vega`.
- Works: a locale name is a plain name, so the lexer needs no locale token and no `-` in names.
- Next: the lexer (`lex`) with the spec-file test.
