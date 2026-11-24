# 28 Statement outside the first block

- Changed: a later block that starts with `use` or `template`, or whose second token is `::`, reports "use, template and declarations belong in the first block".
- Works: goldens `errors/use-in-template` and `decls/first-block-after-text` show the new message; new `errors/declaration-in-template` and `errors/template-in-template`.
- Next: review the branch, then a draft PR.
