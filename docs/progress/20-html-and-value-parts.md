# 20 Html and Value parts

- Changed: `parse_template.odin` walks the template: text between blocks becomes `Html` parts, and a block holding one expression becomes a `Value` part.
- Changed: empty and comment-only blocks make no part; tag blocks are skipped until the tag changes land.
- Changed: `dump_tree` prints one line per part instead of `Template_Text`.
- Works: goldens `parts/values-and-html`, `parts/empty-and-comment-blocks`, `errors/two-expressions-in-block`, `errors/use-in-template`.
- Next: `if`, `elif`, `else` and `/if` tags.
