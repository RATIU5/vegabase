# 29 Dump allocator

- Changed: `dump_tokens` and `dump_tree` free the line-start table with the allocator that made it, not `context.allocator`.
- Works: the lexer and parser golden dumps now run on the per-file arena from `check_golden_dir`, so a free with the wrong allocator shows as a bad free in the test log.
