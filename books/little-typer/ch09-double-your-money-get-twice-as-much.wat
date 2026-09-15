;; The Little Typer, chapter 9 (Double Your Money, Get Twice as Much).
;; Runs ch09-double-your-money-get-twice-as-much.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch09-double-your-money-get-twice-as-much.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch09-double-your-money-get-twice-as-much-refusals.pie
;; (oracle/typer/ch09-double-your-money-get-twice-as-much-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch09-double-your-money-get-twice-as-much.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch09-double-your-money-get-twice-as-much.pie"
                         "oracle/typer/ch09-double-your-money-get-twice-as-much.expected"
                         "little-typer ch09 double-your-money-get-twice-as-much")
    (:pie::check-refusals "books/little-typer/ch09-double-your-money-get-twice-as-much-refusals.pie"
                          "oracle/typer/ch09-double-your-money-get-twice-as-much-refusals.expected"
                          "little-typer ch09 double-your-money-get-twice-as-much")))
