;; `hold` concats its argument -- which mutates IN PLACE if the value is still marked owned.
;; The caller shares `s` when passing it, which is what disables that. If a shadowing rebind
;; makes the second share get elided, the second `s` stays owned, `hold` mutates it, and the
;; caller's own later read of `s` sees the mutation.
(wat.core/defn user/hold [s :- wat.type/String] :- wat.type/String
  (wat.string/concat s "!"))

(wat.core/defn user/f [a :- wat.type/String] :- wat.type/String
  (wat.core/let [s (wat.string/concat a "1")]
    (wat.core/let [x (user/hold s)]
      (wat.core/let [s (wat.string/concat a "2")]
        (wat.core/let [y (user/hold s)]
          (wat.string/concat s (wat.string/concat x y)))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/f "z")))
