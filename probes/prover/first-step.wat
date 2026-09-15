;; first-step.wat: the generated J-Bob (books/little-prover/lib/j-bob.wat) and transcript
;; (transcript-ch01.wat, whose entries are values computed once) loaded together, running the book's first example. guile's J-Bob answers
;; (quote ham) (oracle/prover.expected.tsv). Expected: "(quote ham)"
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "../../books/little-prover/lib/j-bob-lang.wat")
(:wat::load-file! "../../books/little-prover/lib/j-bob.wat")
(:wat::load-file! "../../books/little-prover/lib/transcript-ch01.wat")
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::ast->source :jb::chapter1_example1)))
