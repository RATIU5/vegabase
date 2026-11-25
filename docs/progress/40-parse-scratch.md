# 40 Parse scratch

- Changed: `parse` keeps `tokens`, `entry_stack`, `type_stack`, `expr_stack` and `open_tags` on `context.temp_allocator` under a temp guard, so they are freed before it returns; every `File` array stays on `allocator`.
- Contract: the `File` lives on the allocator passed in (one arena per file), scratch is freed before `parse` returns, and `File.src` borrows the caller's string, which must outlive the `File`.
