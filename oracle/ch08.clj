;; oracle/ch08.clj: the queries of books/reasoned-schemer/ch08-just-a-bit-more.wat, in the
;; oracle. Its output is the wat chapter's expected values. Timed, to see which queries are
;; cheap enough for the wat chapter.
;; Run: clojure -M oracle/ch08.clj
(load-file "oracle/mk.clj")
(in-ns 'mk)
(load-file "oracle/rels.clj")

(defmacro timed [label form]
  `(let [t0# (System/nanoTime) v# ~form]
     (println ~label (pr-str v#) (str "(" (quot (- (System/nanoTime) t0#) 1000000) " ms)"))))

(println "== ch08 part one")
(timed "*o-10" (run 10 (x y r) (*o x y r)))
(timed "*o-2x4" (run* p (*o (quo '(0 1)) (quo '(0 0 1)) p)))
(timed "*o-3x3" (run 1 (x y r) (== (lst x y r) (quo '((1 1) (1 1) (1 0 0 1)))) (*o x y r)))
(timed "*o-one" (run* (n m) (*o n m (quo '(1)))))
(timed "*o-3-prime" (run* (n m) (>1o n) (>1o m) (*o n m (quo '(1 1)))))
(timed "*o-7x63" (run* p (*o (quo '(1 1 1)) (quo '(1 1 1 1 1 1)) p)))
(timed "*o-13x11" (run* q (*o (build-num 13) (build-num 11) q)))
(timed "*o-factors-12" (run* (x y) (*o x y (build-num 12))))
(timed "=lo-w" (run* (w x y) (=lo (lst* [1 w x] y) (quo '(0 1 1 0 1)))))
(timed "=lo-b" (run* b (=lo (quo '(1)) (lst b))))
(timed "=lo-5" (run 5 (y z) (=lo (kons 1 y) (kons 1 z))))
(timed "<lo-8" (run 8 (y z) (<lo (kons 1 y) (lst* [0 1 1 0 1] z))))
(timed "<o-5<7" (run* q (<o (quo '(1 0 1)) (quo '(1 1 1)))))
(timed "<o-7<5" (run* q (<o (quo '(1 1 1)) (quo '(1 0 1)))))
(timed "<o-n<5" (run* n (<o n (quo '(1 0 1)))))
(timed "<o-5<m" (run 6 m (<o (quo '(1 0 1)) m)))
(timed "<=o-5<=5" (run* q (<=o (quo '(1 0 1)) (quo '(1 0 1)))))
(timed "splito-r0" (run* (l h) (splito (quo '(0 0 1 0 1)) () l h)))
(timed "splito-r1" (run* (l h) (splito (quo '(0 0 1 0 1)) (quo '(1)) l h)))
(timed "splito-r2" (run* (l h) (splito (quo '(0 0 1 0 1)) (quo '(0 1)) l h)))
(timed "splito-all" (run* (r l h) (splito (quo '(0 0 1 0 1)) r l h)))
(timed "/o-none" (run* m (fresh (r) (divo (quo '(1 0 1)) m (quo '(1 1 1)) r))))
(timed "/o-14/3" (run* (q r) (divo (build-num 14) (build-num 3) q r)))
(timed "/o-68/7" (run* (q r) (divo (build-num 68) (build-num 7) q r)))
(timed "/o-4" (run 4 (n m q r) (divo n m q r)))
