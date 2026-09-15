;; The Little Typer, chapter 4 (Easy as Pie).
;; Runs ch04-easy-as-pie.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch04-easy-as-pie.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch04-easy-as-pie-refusals.pie
;; (oracle/typer/ch04-easy-as-pie-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch04-easy-as-pie.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch04-easy-as-pie.pie"
                         "oracle/typer/ch04-easy-as-pie.expected"
                         "little-typer ch04 easy-as-pie")
    (:pie::check-refusals "books/little-typer/ch04-easy-as-pie-refusals.pie"
                          "oracle/typer/ch04-easy-as-pie-refusals.expected"
                          "little-typer ch04 easy-as-pie")))
