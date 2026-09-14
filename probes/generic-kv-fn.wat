;; generic-kv-fn.wat: the builder's example of a generic ("data parametric") function in the
;; Clojure/EDN spelling, verbatim, then called at concrete types. It returns an empty typed
;; hash-map. Expected: 0 then true
(wat.core/defn u/kv-fn :- [K V]
  [k :- K
   v :- V]
  :- (wat.type/HashMap :- [K V])
  (wat.type/HashMap :- [K V]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [m (u/kv-fn :pear 7)]
    (wat.core/do
      (wat.kernel/println (wat.core/length m))
      (wat.kernel/println (wat.core/empty? m)))))
