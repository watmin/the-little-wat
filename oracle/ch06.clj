;; oracle/ch06.clj: the queries of books/reasoned-schemer/ch06-the-fun-never-ends.wat, in the
;; oracle. Its output is the wat chapter's expected values. very-recursiveo is counted, and
;; timed at the book's million here for comparison (the wat chapter runs fewer).
;; Run: clojure -M oracle/ch06.clj
(load-file "oracle/mk.clj")
(in-ns 'mk)
(load-file "oracle/rels.clj")

(println "== ch06")
(show "alwayso-1" (run 1 q (alwayso)))
(show "alwayso-5" (run 5 q (alwayso)))
(show "onion-5" (run 5 q (== 'onion q) (alwayso)))
(show "garlic-onion-1" (run 1 q (conde ((== 'garlic q) (alwayso)) ((== 'onion q))) (== 'onion q)))
(show "garlic-onion-5" (run 5 q (conde ((== 'garlic q) (alwayso)) ((== 'onion q) (alwayso))) (== 'onion q)))
(show "nevero-carrot" (run 1 q (conde ((nevero)) ((== 'carrot q)))))
(show "spicy-hot" (run 5 q (conde ((== 'spicy q) (nevero)) ((== 'hot q)) ((== 'apple q) (alwayso)) ((== 'cider q)))))
(show "tea-nevero" (run 2 q (conde ((== 'tea q) (nevero)) ((== 'cup q)) ((== 'tea q)))))
(doseq [n [1000 10000 1000000]]
  (let [t0 (System/nanoTime)
        c (count (run n q (very-recursiveo)))]
    (println (str "very-recursiveo-" n) c (str "(" (quot (- (System/nanoTime) t0) 1000000) " ms)"))))
