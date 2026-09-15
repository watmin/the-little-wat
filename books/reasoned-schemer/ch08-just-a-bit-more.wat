;; The Reasoned Schemer, chapter 8 (Just a Bit More): multiplication, comparison, division,
;; logarithm and exponent on little-endian bit lists, run forwards and backwards. Our own
;; code and examples. Every expected value here is the output of oracle/ch08.clj or
;; oracle/ch08b.clj, the same queries in a Clojure transliteration of the book's engine; the
;; arithmetic ones are checked in decimal in the comments too.
;;
;; Run: wat books/reasoned-schemer/ch08-just-a-bit-more.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch02-old-toys.wat")
(:wat::load-file! "lib/ch04-double-your-fun.wat")
(:wat::load-file! "lib/ch07-a-bit-too-much.wat")
(:wat::load-file! "lib/ch08-just-a-bit-more.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; multiplication
    (wat.test/assert-eq (rs/run 10 (x y r) (rs/*o x y r))
                        '((() _0 ()) ((_0 & _1) () ()) ((1) (_0 & _1) (_0 & _1)) ((_0 _1 & _2) (1) (_0 _1 & _2))
                          ((0 1) (_0 _1 & _2) (0 _0 _1 & _2)) ((0 0 1) (_0 _1 & _2) (0 0 _0 _1 & _2))
                          ((1 _0 & _1) (0 1) (0 1 _0 & _1)) ((0 0 0 1) (_0 _1 & _2) (0 0 0 _0 _1 & _2))
                          ((1 _0 & _1) (0 0 1) (0 0 1 _0 & _1)) ((0 1 _0 & _1) (0 1) (0 0 1 _0 & _1))))
    ;; 2 * 4 = 8; 3 * 3 = 9; 7 * 63 = 441; 13 * 11 = 143
    (wat.test/assert-eq (rs/run* p (rs/*o (rs/q '(0 1)) (rs/q '(0 0 1)) p)) '((0 0 0 1)))
    (wat.test/assert-eq (rs/run 1 (x y r) (rs/== (rs/list [x y r]) (rs/q '((1 1) (1 1) (1 0 0 1)))) (rs/*o x y r))
                        '(((1 1) (1 1) (1 0 0 1))))
    (wat.test/assert-eq (rs/run* p (rs/*o (rs/q '(1 1 1)) (rs/q '(1 1 1 1 1 1)) p)) '((1 0 0 1 1 1 0 1 1)))
    (wat.test/assert-eq (rs/run* q (rs/*o (rs/build-num 13) (rs/build-num 11) q)) '((1 1 1 1 0 0 0 1)))
    ;; backwards: 1 = 1 * 1 only; 3 is prime; the six factor pairs of 12
    (wat.test/assert-eq (rs/run* (n m) (rs/*o n m (rs/q '(1)))) '(((1) (1))))
    (wat.test/assert-eq (rs/run* (n m) (rs/>1o n) (rs/>1o m) (rs/*o n m (rs/q '(1 1)))) '())
    (wat.test/assert-eq (rs/run* (x y) (rs/*o x y (rs/build-num 12)))
                        '(((1) (0 0 1 1)) ((0 0 1 1) (1)) ((0 1) (0 1 1)) ((0 0 1) (1 1)) ((1 1) (0 0 1)) ((0 1 1) (0 1))))

    ;; lengths
    (wat.test/assert-eq (rs/run* (w x y) (rs/=lo (rs/list* [(rs/q '1) w x] y) (rs/q '(0 1 1 0 1))))
                        '((_0 _1 (_2 1))))
    (wat.test/assert-eq (rs/run* b (rs/=lo (rs/q '(1)) (rs/list [b]))) '(1))
    (wat.test/assert-eq (rs/run 5 (y z) (rs/=lo (rs/cons (rs/q '1) y) (rs/cons (rs/q '1) z)))
                        '((() ()) ((1) (1)) ((_0 1) (_1 1)) ((_0 _1 1) (_2 _3 1)) ((_0 _1 _2 1) (_3 _4 _5 1))))
    (wat.test/assert-eq (rs/run 8 (y z) (rs/<lo (rs/cons (rs/q '1) y) (rs/q* '(0 1 1 0 1) z)))
                        '((() _0) ((1) _0) ((_0 1) _1) ((_0 _1 1) _2) ((_0 _1 _2 1) (_3 & _4))
                          ((_0 _1 _2 _3 1) (_4 _5 & _6)) ((_0 _1 _2 _3 _4 1) (_5 _6 _7 & _8))
                          ((_0 _1 _2 _3 _4 _5 1) (_6 _7 _8 _9 & _10))))

    ;; comparison: 5 < 7, not 7 < 5; every n < 5; the first m > 5
    (wat.test/assert-eq (rs/run* q (rs/<o (rs/q '(1 0 1)) (rs/q '(1 1 1)))) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/<o (rs/q '(1 1 1)) (rs/q '(1 0 1)))) '())
    (wat.test/assert-eq (rs/run* n (rs/<o n (rs/q '(1 0 1)))) '(() (1) (_0 1) (0 0 1)))
    (wat.test/assert-eq (rs/run 6 m (rs/<o (rs/q '(1 0 1)) m)) '((_0 _1 _2 _3 & _4) (0 1 1) (1 1 1)))
    (wat.test/assert-eq (rs/run* q (rs/<=o (rs/q '(1 0 1)) (rs/q '(1 0 1)))) '(_0))

    ;; splito: 20 split at the length of r
    (wat.test/assert-eq (rs/run* (l h) (rs/splito (rs/q '(0 0 1 0 1)) (rs/nil) l h)) '((() (0 1 0 1))))
    (wat.test/assert-eq (rs/run* (l h) (rs/splito (rs/q '(0 0 1 0 1)) (rs/q '(1)) l h)) '((() (1 0 1))))
    (wat.test/assert-eq (rs/run* (l h) (rs/splito (rs/q '(0 0 1 0 1)) (rs/q '(0 1)) l h)) '(((0 0 1) (0 1))))
    (wat.test/assert-eq (rs/run* (r l h) (rs/splito (rs/q '(0 0 1 0 1)) r l h))
                        '((() () (0 1 0 1)) ((_0) () (1 0 1)) ((_0 _1) (0 0 1) (0 1)) ((_0 _1 _2) (0 0 1) (1))
                          ((_0 _1 _2 _3) (0 0 1 0 1) ()) ((_0 _1 _2 _3 _4 & _5) (0 0 1 0 1) ())))

    ;; division: no m divides 5 seven times; 14 = 3 * 4 + 2; 68 = 7 * 9 + 5
    (wat.test/assert-eq (rs/run* m (rs/fresh (r) (rs/divo (rs/q '(1 0 1)) m (rs/q '(1 1 1)) r))) '())
    (wat.test/assert-eq (rs/run* (q r) (rs/divo (rs/build-num 14) (rs/build-num 3) q r)) '(((0 0 1) (0 1))))
    (wat.test/assert-eq (rs/run* (q r) (rs/divo (rs/build-num 68) (rs/build-num 7) q r)) '(((1 0 0 1) (1 0 1))))
    (wat.test/assert-eq (rs/run 4 (n m q r) (rs/divo n m q r))
                        '((() (_0 & _1) () ()) ((1) (_0 _1 & _2) () (1)) ((_0 1) (_1 _2 _3 & _4) () (_0 1))
                          ((_0 _1 1) (_2 _3 _4 _5 & _6) () (_0 _1 1))))

    ;; logarithm: 14 = 2^3 + 6; 8 = 2^3 exactly; 68 = 3^3 + 41. The costlier queries (3^5, and
    ;; the nine ways to write 68 as b^q + r) run in probes/mk/logo-heavy.wat.
    (wat.test/assert-eq (rs/run* r (rs/logo (rs/q '(0 1 1 1)) (rs/q '(0 1)) (rs/q '(1 1)) r)) '((0 1 1)))
    (wat.test/assert-eq (rs/run* q (rs/logo (rs/build-num 8) (rs/build-num 2) q (rs/nil))) '((1 1)))
    (wat.test/assert-eq (rs/run* r (rs/logo (rs/build-num 68) (rs/build-num 3) (rs/build-num 3) r)) '((1 0 0 1 0 1)))

    (wat.kernel/println "reasoned-schemer ch08 just-a-bit-more: ok")))
