# 25 Spec files through the parser

- Changed: `spec_files` runs `parse` on one arena, freed after each file: every example and good file must parse with no error, and every bad file must fail with exactly one.
- Works: all 15 examples, 12 good and 28 bad files pass; a good file copied into `bad/` makes the test fail.
- Next: run `parse` on every prefix of every spec file, as the lexer test does.
