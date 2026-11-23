# 08 Spec files by folder

- Changed: `scan_spec_files` and `lex_spec_files` became one test, `spec_files`, in `spec_files_test.odin`; `lex_test.odin` is gone.
- Changed: the folder decides the expectation, with no list of files: `examples/` and `good/` must scan and lex cleanly; `bad/` must report at most one error.
- Works: exact error messages are pinned by golden cases in `tests/golden/lexer/errors/`, not by the spec-file test.
- Next: golden cases for `operators/`, `locale/` and `errors/`, including decimal, `*`, locale hyphen and unclosed block.
