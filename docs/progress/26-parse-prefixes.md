# 26 Parse every prefix

- Changed: `spec_file_prefixes` runs `parse` on every prefix of every spec file; `scan_and_lex` is gone.
- Works: no prefix crashes, and each gives either no error and ok, or exactly one error; the test takes about 50 ms.
- Next: `parse_type_atom` reuses `parse_type_name`.
