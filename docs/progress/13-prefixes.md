# 13 Prefixes

- Changed: `spec_file_prefixes` runs scan and lex on every prefix of every spec file, including prefixes that cut a UTF-8 sequence in half.
- Changed: `scan_and_lex` takes a name and a source string instead of a loaded file.
- Works: no prefix crashes or reports more than one error; the suite still runs in about 35 ms.
- Next: D-68 lets a reserved word name a locale table (`or :: locale`, Odia).
