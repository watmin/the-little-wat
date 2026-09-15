;; The Little Typer, chapter 7 (It All Depends on the Motive).
;; Runs ch07-it-all-depends-on-the-motive.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch07-it-all-depends-on-the-motive.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch07-it-all-depends-on-the-motive-refusals.pie
;; (oracle/typer/ch07-it-all-depends-on-the-motive-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch07-it-all-depends-on-the-motive.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch07-it-all-depends-on-the-motive.pie"
                         "oracle/typer/ch07-it-all-depends-on-the-motive.expected"
                         "little-typer ch07 it-all-depends-on-the-motive")
    (:pie::check-refusals "books/little-typer/ch07-it-all-depends-on-the-motive-refusals.pie"
                          "oracle/typer/ch07-it-all-depends-on-the-motive-refusals.expected"
                          "little-typer ch07 it-all-depends-on-the-motive")))
