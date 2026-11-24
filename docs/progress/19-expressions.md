# 19 Expressions

- Changed: `parse_exprs.odin` parses expressions per `vega.lark`: pipes, `and`/`or` chains that cannot mix, `not`, one comparison, `??`, arithmetic with precedence, unary `-`, paths, calls, literals, lists, records and component values.
- Changed: `File.expr_items` holds call arguments and list items, so `Expr.items` is a contiguous `Range`; records point into `entries`.
- Changed: `enter` and `leave` route records, parentheses, lists and call arguments through the nesting limit; unary `-` is a loop; `skip_expr` and `MISMATCHED_BRACKET` are gone.
- Works: goldens in `parser/exprs/` and eight new error cases; every example and good file parses; 15 of 28 bad files now fail, and the rest are template-block cases.
- Next: template parts and tag nesting, then the stricter spec-files rule.
