;; The Little Typer, chapter 1 (The More Things Change, the More They Stay the Same).
;; Runs ch01-the-more-things-change.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch01-the-more-things-change.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch01-the-more-things-change-refusals.pie
;; (oracle/typer/ch01-the-more-things-change-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch01-the-more-things-change.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch01-the-more-things-change.pie"
                         "oracle/typer/ch01-the-more-things-change.expected"
                         "little-typer ch01 the-more-things-change")
    (:pie::check-refusals "books/little-typer/ch01-the-more-things-change-refusals.pie"
                          "oracle/typer/ch01-the-more-things-change-refusals.expected"
                          "little-typer ch01 the-more-things-change")))
