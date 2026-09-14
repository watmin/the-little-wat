;; Clojure's 'x reader shorthand. Every chapter spells (wat.core/quote x) instead.
;; Expected in Clojure: true true
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (wat.core/= 'pear (wat.core/quote pear)))
    (wat.kernel/println (wat.core/= '(pear plum) (wat.core/quote (pear plum))))))
