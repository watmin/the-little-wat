# AMEND — excursus 003 stone 1: rete is for rules

An amendment to the brief, mid-strike, from the builder: *"don't abuse rete ..... it should be
reserved for rules"* and *"rete's defn is far more restrictive than regular defn"*. **Not a
rejection. Keep the strike going; change where the gate's logic lives.**

## The change

The function-type work in `tools/rules/check.wat` is currently a parser written as
`:wat::rete::core::defn`s -- `:ck::at`, `:ck::semi`, `:ck::colon`, a ten-way `if` for `:ck::digit`,
`:ck::times10` from additions, `:ck::digits`, `:ck::comp-end`, `:ck::comp`, `:ck::fn-count`,
`:ck::fn-walk` -- so a `defrule`'s `where` can call it. Move it out of rete:

- **Parse and decide in plain `:wat::core::defn`**, in the loading path that already reads the
  export (`:ck::add-line` and the 23 plain defns beside it). Plain wat has `:wat::string::split`,
  `:wat::string::to-i64` answering an `Option`, `match`, and recursion -- none of rete's totality
  restrictions.
- **Insert the RESULT as a fact** -- e.g. whether an argument's function type fits its parameter's,
  or the function type's parts -- and let the `defrule`s only match and join, as they do for every
  other type.
- **`:wat::rete::core::defn` stays for what a rule truly needs inside its network**, and after this
  change the function-type rule should need none.

## Unchanged

Everything else in the brief and the expectations. Rows 5 and 6 (function types compared, `partial`
must-be-zero, the mutant trips the gate) are how this part is weighed. The SCORE says where the
logic now lives, and names any `:wat::rete::core::defn` that remains, with why a rule needs it.
