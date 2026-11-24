# 30 Keyword boundary in the grammar

- Changed: `vega.lark` matches each reserved word only as a whole word, so lark no longer splits `iffy` into `if fy` or `slotted` into `slot ted`.
- Changed: `good/name-starts-with-reserved-word.vega` uses names that start with a reserved word; VEGA-GRAMMAR.md states the rule.
- Works: the new file fails on the old grammar and passes on the new one; the Odin parser already accepted it.
