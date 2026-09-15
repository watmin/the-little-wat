;; The Reasoned Schemer, chapter 7 (A Bit Too Much): bits, adders, and addition and
;; subtraction on little-endian bit lists, run forwards and backwards. Our own code and
;; examples. Every expected value here is the output of oracle/ch07.clj, the same queries in
;; a Clojure transliteration of the book's engine.
;;
;; Run: wat books/reasoned-schemer/ch07-a-bit-too-much.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch02-old-toys.wat")
(:wat::load-file! "lib/ch07-a-bit-too-much.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; bits
    (wat.test/assert-eq (rs/run* (x y) (rs/bit-xoro x y (rs/q '0))) '((0 0) (1 1)))
    (wat.test/assert-eq (rs/run* (x y) (rs/bit-xoro x y (rs/q '1))) '((0 1) (1 0)))
    (wat.test/assert-eq (rs/run* (x y r) (rs/bit-xoro x y r)) '((0 0 0) (0 1 1) (1 0 1) (1 1 0)))
    (wat.test/assert-eq (rs/run* (x y) (rs/bit-ando x y (rs/q '1))) '((1 1)))

    ;; adders
    (wat.test/assert-eq (rs/run* r (rs/half-addero (rs/q '1) (rs/q '1) r (rs/q '1))) '(0))
    (wat.test/assert-eq (rs/run* (x y r c) (rs/half-addero x y r c))
                        '((0 0 0 0) (0 1 1 0) (1 0 1 0) (1 1 0 1)))
    (wat.test/assert-eq (rs/run* (r c) (rs/full-addero (rs/q '0) (rs/q '1) (rs/q '1) r c)) '((0 1)))
    (wat.test/assert-eq (rs/run* (r c) (rs/full-addero (rs/q '1) (rs/q '1) (rs/q '1) r c)) '((1 1)))
    (wat.test/assert-eq (rs/run* (b x y r c) (rs/full-addero b x y r c))
                        '((0 0 0 0 0) (1 0 0 1 0) (0 0 1 1 0) (1 0 1 0 1)
                          (0 1 0 1 0) (1 1 0 0 1) (0 1 1 0 1) (1 1 1 1 1)))

    ;; numbers
    (wat.test/assert-eq (rs/run* q (rs/== q (rs/build-num 0))) '(()))
    (wat.test/assert-eq (rs/run* q (rs/== q (rs/build-num 19))) '((1 1 0 0 1)))
    (wat.test/assert-eq (rs/run* q (rs/== q (rs/build-num 36))) '((0 0 1 0 0 1)))
    (wat.test/assert-eq (rs/run* q (rs/poso (rs/q '(0 1 1)))) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/poso (rs/q '(1)))) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/poso (rs/nil))) '())
    (wat.test/assert-eq (rs/run* r (rs/poso r)) '((_0 & _1)))
    (wat.test/assert-eq (rs/run* q (rs/>1o (rs/q '(0 1 1)))) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/>1o (rs/q '(1)))) '())
    (wat.test/assert-eq (rs/run* r (rs/>1o r)) '((_0 _1 & _2)))

    ;; addition: 1 + 6 + 3, then every pair that sums to 5
    (wat.test/assert-eq (rs/run* s (rs/gen-addero (rs/q '1) (rs/q '(0 1 1)) (rs/q '(1 1)) s)) '((0 1 0 1)))
    (wat.test/assert-eq (rs/run* (x y) (rs/addero (rs/q '0) x y (rs/q '(1 0 1))))
                        '(((1 0 1) ()) (() (1 0 1)) ((1) (0 0 1)) ((0 0 1) (1)) ((0 1) (1 1)) ((1 1) (0 1))))
    (wat.test/assert-eq (rs/run* (x y) (rs/+o x y (rs/q '(1 0 1))))
                        '(((1 0 1) ()) (() (1 0 1)) ((1) (0 0 1)) ((0 0 1) (1)) ((0 1) (1 1)) ((1 1) (0 1))))
    ;; nine answers to x + y = r, with nothing known: open tails stand for whole families
    (wat.test/assert-eq (rs/run 9 (x y r) (rs/+o x y r))
                        '((_0 () _0) (() (_0 & _1) (_0 & _1)) ((1) (1) (0 1)) ((1) (0 _0 & _1) (1 _0 & _1))
                          ((1) (1 1) (0 0 1)) ((0 _0 & _1) (1) (1 _0 & _1)) ((1) (1 0 _0 & _1) (0 1 _0 & _1))
                          ((1) (1 1 1) (0 0 0 1)) ((1 1) (1) (0 0 1))))
    (wat.test/assert-eq (rs/run* q (rs/+o (rs/build-num 29) (rs/build-num 13) q)) '((0 1 0 1 0 1)))

    ;; subtraction is addition run backwards
    (wat.test/assert-eq (rs/run* q (rs/-o (rs/q '(0 0 0 1)) (rs/q '(1 0 1)) q)) '((1 1)))
    (wat.test/assert-eq (rs/run* q (rs/-o (rs/q '(0 1 1)) (rs/q '(0 1 1)) q)) '(()))
    (wat.test/assert-eq (rs/run* q (rs/-o (rs/q '(0 1 1)) (rs/q '(0 0 0 1)) q)) '())

    ;; lengtho
    (wat.test/assert-eq (rs/run 1 n (rs/lengtho (rs/q '(jicama rhubarb guava)) n)) '((1 1)))
    (wat.test/assert-eq (rs/run* ls (rs/lengtho ls (rs/q '(1 0 1)))) '((_0 _1 _2 _3 _4)))
    (wat.test/assert-eq (rs/run* q (rs/lengtho (rs/q '(1 0 1)) (rs/q '3))) '())
    (wat.test/assert-eq (rs/run 3 q (rs/lengtho q q)) '(() (1) (0 1)))

    (wat.kernel/println "reasoned-schemer ch07 a-bit-too-much: ok")))
