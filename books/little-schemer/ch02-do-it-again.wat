;; The Little Schemer, chapter 2 (Do It, Do It Again, and Again, and Again): lat? and
;; member?, the first recursive functions. The definitions live in
;; lib/ch02-do-it-again.wat; this program checks them. Our own code and examples.
;;
;; Run: wat books/little-schemer/ch02-do-it-again.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch02-do-it-again.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; lat?: a list of atoms. The empty list qualifies (no element fails).
    (wat.test/assert-eq (ls/lat? (wat.core/quote (pear plum fig))) true)
    (wat.test/assert-eq (ls/lat? (wat.core/quote (pear (plum) fig))) false)
    (wat.test/assert-eq (ls/lat? (wat.core/quote ((pear plum)))) false)
    (wat.test/assert-eq (ls/lat? (ls/empty-list)) true)

    ;; member?: found at the front, in the middle, at the end; absent; empty list.
    (wat.test/assert-eq (ls/member? (wat.core/quote pear) (wat.core/quote (pear plum fig))) true)
    (wat.test/assert-eq (ls/member? (wat.core/quote plum) (wat.core/quote (pear plum fig))) true)
    (wat.test/assert-eq (ls/member? (wat.core/quote fig) (wat.core/quote (pear plum fig))) true)
    (wat.test/assert-eq (ls/member? (wat.core/quote kiwi) (wat.core/quote (pear plum fig))) false)
    (wat.test/assert-eq (ls/member? (wat.core/quote pear) (ls/empty-list)) false)

    (wat.kernel/println "little-schemer ch02 do-it-again: ok")))
