;; ch01-mutant.wat: The Little Typer ch 1 run against ch01-mutant.expected, a copy of the
;; oracle's answers with ONE line made wrong ((the Nat 3) -> (the Nat 33)), to prove the
;; chapter's comparisons really run. Run from the repository root. Expected: fails there.
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "../../books/little-typer/lib/pie.wat")
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:pie::check-chapter "books/little-typer/ch01-the-more-things-change.pie"
                       "probes/typer/ch01-mutant.expected"
                       "little-typer ch01 mutant"))
