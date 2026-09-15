;; oracle/ch08b.clj: ch 8 part two (logo, expo), in the oracle, timed. Its output is the
;; expected values for whichever of these queries the wat chapter can afford.
;; Run: clojure -M oracle/ch08b.clj
(load-file "oracle/mk.clj")
(in-ns 'mk)
(load-file "oracle/rels.clj")

(defmacro timed [label form]
  `(let [t0# (System/nanoTime) v# ~form]
     (println ~label (pr-str v#) (str "(" (quot (- (System/nanoTime) t0#) 1000000) " ms)"))))

(println "== ch08 part two")
(timed "logo-14-base2" (run* r (logo (quo '(0 1 1 1)) (quo '(0 1)) (quo '(1 1)) r)))
(timed "logo-8-base2" (run* q (logo (build-num 8) (build-num 2) q ())))
(timed "logo-68-base3" (run* r (logo (build-num 68) (build-num 3) (build-num 3) r)))
(timed "expo-3^5" (run* t (expo (quo '(1 1)) (quo '(1 0 1)) t)))
(timed "logo-68-9" (run 9 (b q r) (logo (quo '(0 0 1 0 0 0 1)) b q r) (>1o q)))
