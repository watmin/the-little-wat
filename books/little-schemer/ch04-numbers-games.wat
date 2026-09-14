;; The Little Schemer, chapter 4 (Numbers Games): arithmetic from add1/sub1/zero?, tups
;; as (Vector :- [i64]), and lats that mix numbers and symbols as quoted S-expressions.
;; The definitions live in lib/ch04-numbers-games.wat; this program checks them.
;; Our own code and examples, not the book's text.
;;
;; Run: wat books/little-schemer/ch04-numbers-games.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch04-numbers-games.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; the three primitives
    (wat.test/assert-eq (ls/add1 4) 5)
    (wat.test/assert-eq (ls/sub1 5) 4)
    (wat.test/assert-eq (ls/zero? 0) true)
    (wat.test/assert-eq (ls/zero? 3) false)

    ;; arithmetic built from them
    (wat.test/assert-eq (ls/o+ 3 4) 7)
    (wat.test/assert-eq (ls/o- 9 4) 5)
    (wat.test/assert-eq (ls/o* 3 4) 12)
    (wat.test/assert-eq (ls/o> 5 3) true)
    (wat.test/assert-eq (ls/o> 3 3) false)
    (wat.test/assert-eq (ls/less? 3 5) true)
    (wat.test/assert-eq (ls/o= 4 4) true)
    (wat.test/assert-eq (ls/o= 4 5) false)
    (wat.test/assert-eq (ls/pow 2 5) 32)
    (wat.test/assert-eq (ls/quotient 17 5) 3)

    ;; tups
    (wat.test/assert-eq (ls/addtup [3 5 2]) 10)
    (wat.test/assert-eq (ls/addtup []) 0)
    (wat.test/assert-eq (ls/tup+ [1 2 3] [10 20 30]) [11 22 33])
    (wat.test/assert-eq (ls/tup+ [1 2] [10 20 30]) [11 22 30])

    ;; lats mixing numbers and symbols
    (wat.test/assert-eq (ls/length (wat.core/quote (pear plum fig))) 3)
    (wat.test/assert-eq (ls/pick 2 (wat.core/quote (pear plum fig))) (wat.core/quote plum))
    (wat.test/assert-eq (ls/rempick 2 (wat.core/quote (pear plum fig))) (wat.core/quote (pear fig)))
    (wat.test/assert-eq (ls/no-nums (wat.core/quote (5 pear 3 plum 7))) (wat.core/quote (pear plum)))
    (wat.test/assert-eq (ls/all-nums (wat.core/quote (5 pear 3 plum 7))) [5 3 7])
    (wat.test/assert-eq (ls/eqan? (wat.core/quote 4) (wat.core/quote 4)) true)
    (wat.test/assert-eq (ls/eqan? (wat.core/quote pear) (wat.core/quote pear)) true)
    (wat.test/assert-eq (ls/eqan? (wat.core/quote 4) (wat.core/quote pear)) false)
    (wat.test/assert-eq (ls/occur (wat.core/quote plum) (wat.core/quote (plum pear plum))) 2)
    (wat.test/assert-eq (ls/occur (wat.core/quote 3) (wat.core/quote (3 pear 3 3))) 3)
    (wat.test/assert-eq (ls/one? 1) true)

    (wat.kernel/println "little-schemer ch04 numbers-games: ok")))
