# 23 Slot and render tags

- Changed: `{{slot name}}`, `{{slot name { … }}}` and `{{render Type { … }}}` become `Slot` and `Render` parts; a render needs its record.
- Changed: the temporary skip for unparsed tags is gone; `parse_type_name` reads `Type` or `plugin.Type`.
- Works: goldens `parts/slot-and-render`, `errors/render-without-record`, `errors/slot-without-name`; every example and good file parses.
- Next: the tag nesting check and `closes`.
