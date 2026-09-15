;; The Little Typer, chapter 2 (Doin' What Comes Naturally): runs
;; ch02-doin-what-comes-naturally.pie through wat-Pie (lib/pie.wat) and compares every result
;; with Racket's Pie (oracle/typer/ch02-doin-what-comes-naturally.expected, from
;; tools/pie-oracle.sh). The .pie file is the chapter; both implementations read it.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch02-doin-what-comes-naturally.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:pie::check-chapter "books/little-typer/ch02-doin-what-comes-naturally.pie"
                       "oracle/typer/ch02-doin-what-comes-naturally.expected"
                       "little-typer ch02 doin-what-comes-naturally"))
