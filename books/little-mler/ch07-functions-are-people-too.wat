;; The Little MLer, chapter 7 (Functions Are People, Too): identity, true_maker, hot_maker,
;; and chains: endless sequences held as a number and the function that makes the rest.
;; Our own code and examples.
;;
;; Run: wat books/little-mler/ch07-functions-are-people-too.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch07-functions-are-people-too.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; functions of any type
    (wat.test/assert-eq (ml/identity 5) 5)
    (wat.test/assert-eq (ml/identity "rye") "rye")
    (wat.test/assert-eq (ml/true-maker 5) true)
    (wat.test/assert-eq (ml/true-maker "anything") true)
    ;; a function that returns a function
    (wat.test/assert-eq (wat.core/= ((ml/hot-maker 5) true) (:ml::BoolOrInt.Hot {:v true})) true)
    (wat.test/assert-eq (wat.core/= ((ml/hot-maker "x") false) (:ml::BoolOrInt.Hot {:v true})) false)

    ;; chains: the items are made only when asked for
    (wat.test/assert-eq (ml/chain-item 1 (ml/ints 0)) 1)
    (wat.test/assert-eq (ml/chain-item 5 (ml/ints 0)) 5)
    (wat.test/assert-eq (ml/chain-item 3 (ml/skips 1)) 7)
    ;; 5, 7, 10, 14, 15, 20
    (wat.test/assert-eq (ml/chain-item 1 (ml/some-ints 0)) 5)
    (wat.test/assert-eq (ml/chain-item 6 (ml/some-ints 0)) 20)
    ;; 2, 3, 5, 7, 11, 13, ..., 37
    (wat.test/assert-eq (ml/is-prime 13) true)
    (wat.test/assert-eq (ml/is-prime 15) false)
    (wat.test/assert-eq (ml/chain-item 1 (ml/primes 1)) 2)
    (wat.test/assert-eq (ml/chain-item 6 (ml/primes 1)) 13)
    (wat.test/assert-eq (ml/chain-item 12 (ml/primes 1)) 37)
    ;; fibs(0)(1): 1, 2, 3, 5, 8, 13
    (wat.test/assert-eq (ml/chain-item 1 ((ml/fibs 0) 1)) 1)
    (wat.test/assert-eq (ml/chain-item 6 ((ml/fibs 0) 1)) 13)

    (wat.kernel/println "little-mler ch07 functions-are-people-too: ok")))
