;; The Little Typer, chapter 2 (Doin' What Comes Naturally).
;; Runs ch02-doin-what-comes-naturally.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch02-doin-what-comes-naturally.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch02-doin-what-comes-naturally-refusals.pie
;; (oracle/typer/ch02-doin-what-comes-naturally-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch02-doin-what-comes-naturally.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch02-doin-what-comes-naturally.pie"
                         "oracle/typer/ch02-doin-what-comes-naturally.expected"
                         "little-typer ch02 doin-what-comes-naturally")
    (:pie::check-refusals "books/little-typer/ch02-doin-what-comes-naturally-refusals.pie"
                          "oracle/typer/ch02-doin-what-comes-naturally-refusals.expected"
                          "little-typer ch02 doin-what-comes-naturally")))
