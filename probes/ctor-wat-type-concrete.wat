;; ctor-wat-type-concrete.wat: F-009 discriminator. No generics. A concrete
;; (wat.type/HashMap :- [...]) constructor in value position. Does the runtime failure
;; depend on generics, or only on the wat.type/ spelling of a constructor?
;; Expected if it works: 0
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [m (wat.type/HashMap :- [wat.type/keyword wat.type/i64])]
    (wat.kernel/println (wat.core/length m))))
