# F-194 as rules — the experiment

`f194-as-the-compiler-does-it.wat` models the TWO derivations of an enum value's type exactly as
`elf/compile.wat` performs them (`:c::enum-ty` by tier for a declared type; `:c::type-of-form`'s
variant arm by the heap flag alone for a constructor), plus one constraint the compiler does not
have: at a call, an argument's type must equal the parameter's declared type.
`f194-typed-by-tier.wat` changes ONLY the constructor rule to spell by tier, and adds an agreement
witness so a silent run cannot pass for a clean one.

    printf '["docs/excursus/2026/09/002-no-guesses/rete/crash.wat"]\n' \
      | ../wat-rs/target/release/wat --grep docs/excursus/2026/09/002-no-guesses/rete/<file>.wat

| ruleset | result on `crash.wat` (the program that segfaults natively) |
|---|---|
| as the compiler does it | `boundary-type-conflict` at **13:20**, `(user/slen o)`: arg `henum:user/S`, param `penum:user/S` |
| typed by tier | no conflict; `boundary-type-AGREES` at **13:20**, both `penum:user/S` |

Two things learned about wat's rete while writing it: arithmetic is TOTAL — `(i64::- a b
:undefined v)` must say what it answers when the result is undefined; and wat-grep spells a
string literal's name without its quotes, so a rule must join `NodeKind.StringLit` to tell `"i64"`
from a symbol `i64`.
