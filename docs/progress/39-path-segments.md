# 39 Path segments

- Added: `File.segments`; a `.Path` expr's `items` range holds one span per name (dots omitted), and `name` stays zero.
- Works: the tree dump writes a `Name` child per segment under a multi-name path; goldens with dotted paths gained those lines; `path-with-spaces` covers `a . b . c`.
