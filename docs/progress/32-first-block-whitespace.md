# 32 First-block whitespace

- Changed: a block is the first block only when spaces, tabs, `\r` and `\n` alone come before it; `check.py` and `parse` both use that set.
- Changed: VEGA-GRAMMAR.md states the rule.
- Works: a test parses a block after ` \t\r\n` as the first block and rejects `use` after `\v`.
