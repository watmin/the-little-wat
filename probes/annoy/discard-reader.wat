;; The EDN/Clojure #_ discard: the next form is skipped entirely, even if it is nonsense.
;; Expected: 1
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println #_(this is not a valid form at all) 1))
