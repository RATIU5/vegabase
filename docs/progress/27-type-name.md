# 27 One type-name reader

- Changed: `parse_type_name` lives in `parse_types.odin` and returns the plugin prefix and the type name; `parse_type_atom` and `{{render}}` both use it.
- Works: no golden changed; the error messages fire on the same tokens.
- Next: optional, a clearer error for a first-block statement such as `{{ use std }}` after text.
