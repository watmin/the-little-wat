;; The Little Typer, chapter 13 (Even Haf a Baker's Dozen).
;; Runs ch13-even-haf-a-bakers-dozen.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch13-even-haf-a-bakers-dozen.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch13-even-haf-a-bakers-dozen-refusals.pie
;; (oracle/typer/ch13-even-haf-a-bakers-dozen-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch13-even-haf-a-bakers-dozen.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch13-even-haf-a-bakers-dozen.pie"
                         "oracle/typer/ch13-even-haf-a-bakers-dozen.expected"
                         "little-typer ch13 even-haf-a-bakers-dozen")
    (:pie::check-refusals "books/little-typer/ch13-even-haf-a-bakers-dozen-refusals.pie"
                          "oracle/typer/ch13-even-haf-a-bakers-dozen-refusals.expected"
                          "little-typer ch13 even-haf-a-bakers-dozen")))
