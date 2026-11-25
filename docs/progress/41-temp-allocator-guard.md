# 41 Temp allocator guard

- Changed: `parse` asserts that `allocator` is not `context.temp_allocator`, since its temp guard would free the returned `File`.
- Contract: pass an arena or heap allocator, never the temp allocator.
