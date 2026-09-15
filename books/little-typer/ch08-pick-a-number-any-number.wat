;; The Little Typer, chapter 8 (Pick a Number, Any Number).
;; Runs ch08-pick-a-number-any-number.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch08-pick-a-number-any-number.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch08-pick-a-number-any-number-refusals.pie
;; (oracle/typer/ch08-pick-a-number-any-number-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch08-pick-a-number-any-number.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch08-pick-a-number-any-number.pie"
                         "oracle/typer/ch08-pick-a-number-any-number.expected"
                         "little-typer ch08 pick-a-number-any-number")
    (:pie::check-refusals "books/little-typer/ch08-pick-a-number-any-number-refusals.pie"
                          "oracle/typer/ch08-pick-a-number-any-number-refusals.expected"
                          "little-typer ch08 pick-a-number-any-number")))
