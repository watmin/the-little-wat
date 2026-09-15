;; The Little Typer, chapter 5 (Lists, Lists, and More Lists).
;; Runs ch05-lists-lists-and-more-lists.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch05-lists-lists-and-more-lists.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch05-lists-lists-and-more-lists-refusals.pie
;; (oracle/typer/ch05-lists-lists-and-more-lists-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch05-lists-lists-and-more-lists.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch05-lists-lists-and-more-lists.pie"
                         "oracle/typer/ch05-lists-lists-and-more-lists.expected"
                         "little-typer ch05 lists-lists-and-more-lists")
    (:pie::check-refusals "books/little-typer/ch05-lists-lists-and-more-lists-refusals.pie"
                          "oracle/typer/ch05-lists-lists-and-more-lists-refusals.expected"
                          "little-typer ch05 lists-lists-and-more-lists")))
