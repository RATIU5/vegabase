# 03 Lexer

- Changed: added `Token_Kind`, `Token` and `lex` in `source/vega/lex.odin`, with `lex_spec_files` in `lex_test.odin`.
- Works: `lex` turns one block's code into tokens with absolute spans, ending in `End`. It maps the 21 reserved words (lang D-68) except after `.`, splits `Type` from `Name` by the first letter (D-47), and reads strings and whole numbers (D-70).
- Works: it stops at the first error: unexpected character, unknown escape in string, decimal numbers are not supported, string is not valid UTF-8, string is never closed.
- Works: every file in `examples/` and `grammar/good/` lexes; in `grammar/bad/` the arithmetic, decimal, unknown-escape and hyphen locale files fail here.
- Next: `dump_tokens` and the golden runner, with one golden case.
