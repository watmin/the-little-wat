;; Arithmetic on an address. A String is a pointer; adding to one is not arithmetic, and the
;; type pass has always known enough to say so (F-128).
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s "abc"]
    (wat.kernel/println (wat.core/+ 1 s))))
