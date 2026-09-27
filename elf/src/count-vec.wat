;; A copied vector of strings must not let an owned update of one element rewrite the other.
;; The fresh string is moved into the first vector (count 1). The second conj copies that
;; slot and counts it. Extending the name is not linear — both uses are named — so this
;; checks the values the interpreter also prints, not the count itself.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s (wat.string/concat "hel" "lo")
                 v (wat.core/conj (wat.core/Vector :- [wat.type/String]) s)
                 w (wat.core/conj v "x")]
    (wat.kernel/println (wat.core/nth v 0))
    (wat.kernel/println (wat.core/nth w 0))
    (wat.kernel/println (wat.core/nth w 1))
    (wat.kernel/println (wat.core/length w))))
