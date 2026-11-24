# 22 For tags

- Changed: `{{for item in expr}}`, `{{for item, i in expr}}` and `{{/for}}` become `For` and `End_For` parts; no nesting check yet.
- Changed: `parse_tag` picks the part with one switch, a case per tag.
- Works: goldens `parts/for-with-index`, `errors/for-missing-in`, `errors/for-missing-name`.
- Next: `slot` and `render` tags.
