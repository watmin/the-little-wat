;; The Little Typer, chapter 3 (Eliminate All Natural Numbers!).
;; Runs ch03-eliminate-all-natural-numbers.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch03-eliminate-all-natural-numbers.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch03-eliminate-all-natural-numbers-refusals.pie
;; (oracle/typer/ch03-eliminate-all-natural-numbers-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch03-eliminate-all-natural-numbers.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch03-eliminate-all-natural-numbers.pie"
                         "oracle/typer/ch03-eliminate-all-natural-numbers.expected"
                         "little-typer ch03 eliminate-all-natural-numbers")
    (:pie::check-refusals "books/little-typer/ch03-eliminate-all-natural-numbers-refusals.pie"
                          "oracle/typer/ch03-eliminate-all-natural-numbers-refusals.expected"
                          "little-typer ch03 eliminate-all-natural-numbers")))
