;; generic-kv-fn-kwctor.wat: F-009 discriminator. The same generic function as
;; generic-kv-fn.wat, but with the KEYWORD spelling of the constructor in the body.
;; Expected if the spelling is the cause: 0 then true
(wat.core/defn u/kv-fn :- [K V]
  [k :- K
   v :- V]
  :- (wat.type/HashMap :- [K V])
  (:wat::core::HashMap :- [K V]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [m (u/kv-fn :pear 7)]
    (wat.core/do
      (wat.kernel/println (wat.core/length m))
      (wat.kernel/println (wat.core/empty? m)))))
