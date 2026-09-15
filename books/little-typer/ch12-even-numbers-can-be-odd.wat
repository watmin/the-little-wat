;; The Little Typer, chapter 12 (Even Numbers Can Be Odd).
;; Runs ch12-even-numbers-can-be-odd.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch12-even-numbers-can-be-odd.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch12-even-numbers-can-be-odd-refusals.pie
;; (oracle/typer/ch12-even-numbers-can-be-odd-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch12-even-numbers-can-be-odd.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch12-even-numbers-can-be-odd.pie"
                         "oracle/typer/ch12-even-numbers-can-be-odd.expected"
                         "little-typer ch12 even-numbers-can-be-odd")
    (:pie::check-refusals "books/little-typer/ch12-even-numbers-can-be-odd-refusals.pie"
                          "oracle/typer/ch12-even-numbers-can-be-odd-refusals.expected"
                          "little-typer ch12 even-numbers-can-be-odd")))
