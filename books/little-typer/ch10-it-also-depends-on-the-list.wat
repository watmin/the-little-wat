;; The Little Typer, chapter 10 (It Also Depends on the List).
;; Runs ch10-it-also-depends-on-the-list.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch10-it-also-depends-on-the-list.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch10-it-also-depends-on-the-list-refusals.pie
;; (oracle/typer/ch10-it-also-depends-on-the-list-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch10-it-also-depends-on-the-list.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch10-it-also-depends-on-the-list.pie"
                         "oracle/typer/ch10-it-also-depends-on-the-list.expected"
                         "little-typer ch10 it-also-depends-on-the-list")
    (:pie::check-refusals "books/little-typer/ch10-it-also-depends-on-the-list-refusals.pie"
                          "oracle/typer/ch10-it-also-depends-on-the-list-refusals.expected"
                          "little-typer ch10 it-also-depends-on-the-list")))
