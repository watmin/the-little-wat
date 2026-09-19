(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/if (wat.core/< 1 2) 100 200))
  (wat.kernel/println (wat.core/if (wat.core/> 1 2) 100 200))
  (wat.core/let [a 6 b 7]
    (wat.kernel/println (wat.core/* a b))
    (wat.core/let [c (wat.core/+ a b)]
      (wat.kernel/println c)
      (wat.kernel/println (wat.core/if (wat.core/= c 13) (wat.core/* c 2) 0)))))
