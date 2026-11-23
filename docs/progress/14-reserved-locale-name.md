# 14 Reserved word as a locale name

- Changed: D-68 lets a reserved word name a locale table, because a language tag is not a name: `or :: locale { }` is Odia.
- Changed: `good/locale-name-reserved-word.vega` declares `or` and `in` locales; `vega.lark` already accepted them.
- Works: the lexer emits `Or` and `In` there; the parser will take a reserved-word token in the locale-name slot.
- Next: the parser, starting with a line index per file and the `File` tree with one arena per file.
