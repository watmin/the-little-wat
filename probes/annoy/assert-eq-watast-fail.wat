;; A FAILING assert-eq on two quoted lists, on purpose. Does the failure show the two
;; S-expressions, or something unreadable? Expected: exit 2 with readable actual/expected.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.test/assert-eq (wat.core/quote (pear (plum 1))) (wat.core/quote (pear (fig 1)))))
