# 43 CRLF golden

- Changed: `.gitattributes` marks `tests/golden/**` as `-text`, so git stores golden inputs byte for byte; `crlf.vega` had lost its `\r` on commit and failed in CI.
- Changed: `.gitignore` allows `.gitattributes`.
