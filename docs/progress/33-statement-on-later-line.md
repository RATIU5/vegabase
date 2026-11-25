# 33 Statement on a later line

- Changed: a later block that starts with a line break still reports `use`, `template` and `X ::` as outside the first block.
- Works: a golden parses `{{`, newline, `use std` and expects `.Statement_Outside_First_Block` on line 2.
