;; probes/koans/literal-rows.wat: do filled-in Clojure koans run in wat's Clojure spelling, with
;; only the namespace added (clojure.core/x -> wat.core/x)? Each row prints its value, as EDN.

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (wat.edn/write (wat.core/= 2 (wat.core/+ 1 1))))
    (wat.kernel/println (wat.edn/write (wat.core/= (wat.core/+ 3 4) 7 (wat.core/+ 2 5))))
    (wat.kernel/println (wat.edn/write (wat.core/= 3 (wat.core/count {:x 1 :y 2 :z 3}))))
    (wat.kernel/println (wat.edn/write (wat.core/= [1 2 3] (wat.core/conj [1 2] 3))))
    (wat.kernel/println "literal rows: ok")))
