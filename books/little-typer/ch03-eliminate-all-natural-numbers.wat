;; The Little Typer, chapter 3 (Eliminate All Natural Numbers!): runs
;; ch03-eliminate-all-natural-numbers.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch03-eliminate-all-natural-numbers.expected, from
;; tools/pie-oracle.sh). The .pie file is the chapter; both implementations read it.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch03-eliminate-all-natural-numbers.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:pie::check-chapter "books/little-typer/ch03-eliminate-all-natural-numbers.pie"
                       "oracle/typer/ch03-eliminate-all-natural-numbers.expected"
                       "little-typer ch03 eliminate-all-natural-numbers"))
