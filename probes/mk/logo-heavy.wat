;; logo-heavy.wat: the two ch 8 queries too slow for the chapter program. Expected values are
;; oracle/ch08b.clj's; on the JVM they take 794 ms (3^5) and 572 ms (the nine ways to write
;; 68 as b^q + r). Time with: timeout -s KILL 600 wat probes/mk/logo-heavy.wat
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch02-old-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch04-double-your-fun.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch07-a-bit-too-much.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch08-just-a-bit-more.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; 3^5 = 243
    (wat.test/assert-eq (rs/run* t (rs/expo (rs/q '(1 1)) (rs/q '(1 0 1)) t)) '((1 1 0 0 1 1 1 1)))
    (wat.kernel/println "expo 3^5: ok")
    (wat.test/assert-eq (rs/run 9 (b q r) (rs/logo (rs/q '(0 0 1 0 0 0 1)) b q r) (rs/>1o q))
                        '((() (_0 _1 & _2) (0 0 1 0 0 0 1)) ((1) (_0 _1 & _2) (1 1 0 0 0 0 1))
                          ((0 1) (0 1 1) (0 0 1)) ((1 1) (1 1) (1 0 0 1 0 1)) ((0 0 1) (1 1) (0 0 1))
                          ((0 0 0 1) (0 1) (0 0 1)) ((1 0 1) (0 1) (1 1 0 1 0 1)) ((0 1 1) (0 1) (0 0 0 0 0 1))
                          ((1 1 1) (0 1) (1 1 0 0 1))))
    (wat.kernel/println "logo 68, nine ways: ok")))
