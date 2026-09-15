;; The Little Typer, chapter 14 (There's Safety in Numbers).
;; Runs ch14-theres-safety-in-numbers.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch14-theres-safety-in-numbers.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch14-theres-safety-in-numbers-refusals.pie
;; (oracle/typer/ch14-theres-safety-in-numbers-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch14-theres-safety-in-numbers.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch14-theres-safety-in-numbers.pie"
                         "oracle/typer/ch14-theres-safety-in-numbers.expected"
                         "little-typer ch14 theres-safety-in-numbers")
    (:pie::check-refusals "books/little-typer/ch14-theres-safety-in-numbers-refusals.pie"
                          "oracle/typer/ch14-theres-safety-in-numbers-refusals.expected"
                          "little-typer ch14 theres-safety-in-numbers")))
