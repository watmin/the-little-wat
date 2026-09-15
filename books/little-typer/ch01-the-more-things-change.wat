;; The Little Typer, chapter 1 (The More Things Change, the More They Stay the Same): runs
;; ch01-the-more-things-change.pie through wat-Pie (lib/pie.wat) and compares every result
;; with Racket's Pie (oracle/typer/ch01-the-more-things-change.expected, from
;; tools/pie-oracle.sh). The .pie file is the chapter; both implementations read it.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch01-the-more-things-change.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:pie::check-chapter "books/little-typer/ch01-the-more-things-change.pie"
                       "oracle/typer/ch01-the-more-things-change.expected"
                       "little-typer ch01 the-more-things-change"))
