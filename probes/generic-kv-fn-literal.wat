;; generic-kv-fn-literal.wat: the likely workaround for F-009. The builder's generic
;; function, with the empty map LITERAL {} as its body, typed by the return annotation, in
;; place of a constructor applied to the type variables.
;; Expected: 0 then true
(wat.core/defn u/kv-fn :- [K V]
  [k :- K
   v :- V]
  :- (wat.type/HashMap :- [K V])
  {})

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [m (u/kv-fn :pear 7)]
    (wat.core/do
      (wat.kernel/println (wat.core/length m))
      (wat.kernel/println (wat.core/empty? m)))))
