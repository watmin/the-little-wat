;; The Little Typer, chapter 16 (If It's All the Same to You).
;; Runs ch16-if-its-all-the-same-to-you.pie through wat-Pie (lib/pie.wat) and compares every
;; result with Racket's Pie (oracle/typer/ch16-if-its-all-the-same-to-you.expected, from tools/pie-oracle.sh); then
;; holds wat-Pie to refuse every case Racket's Pie refuses in ch16-if-its-all-the-same-to-you-refusals.pie
;; (oracle/typer/ch16-if-its-all-the-same-to-you-refusals.expected, from tools/pie-oracle-refusals.sh). Both
;; implementations read the same .pie files.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-typer/ch16-if-its-all-the-same-to-you.wat

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/pie.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:pie::check-chapter "books/little-typer/ch16-if-its-all-the-same-to-you.pie"
                         "oracle/typer/ch16-if-its-all-the-same-to-you.expected"
                         "little-typer ch16 if-its-all-the-same-to-you")
    (:pie::check-refusals "books/little-typer/ch16-if-its-all-the-same-to-you-refusals.pie"
                          "oracle/typer/ch16-if-its-all-the-same-to-you-refusals.expected"
                          "little-typer ch16 if-its-all-the-same-to-you")))
