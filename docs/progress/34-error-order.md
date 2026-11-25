# 34 Error order

- Changed: `parse` scans one block at a time, so a scan error in a later block no longer hides an earlier parse error.
- Works: a golden with a bad first block and an unclosed second block expects the first block's error on line 1.
