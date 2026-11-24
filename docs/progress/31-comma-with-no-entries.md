# 31 Comma with no entries

- Changed: `vega.lark` allows a trailing separator in `fields`, `props`, records and lists only after an entry, so `{,}` and `[,]` no longer parse.
- Changed: `bad/comma-with-no-entries.vega` holds `[,]`.
- Works: the grammar and the Odin parser both reject it; every example and good file still parses.
