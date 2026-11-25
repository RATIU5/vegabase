# 38 Qualified name

- Added: `Qualified_Name` (prefix and name spans) for `Type`, call and component-value `Expr.name`, and render `Part.name`; `.Path` keeps its whole span in `name.name`.
- Works: the tree dump writes every qualified name as `Name`, plus a `Prefix` node when set; four goldens with prefixed calls, a component value and a render changed that way.
