;; Compound right operands -- the shape `:c::direct` cannot collapse and the stack used to carry.
(wat.core/defn user/poly [n :- wat.type/i64 a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.core/+ a b)
    (user/poly (wat.core/- n 1)
      (wat.core/+ (wat.core/* b (wat.core/- n 1)) (wat.core/* a 3))
      (wat.core/- (wat.core/+ a (wat.core/* n 2)) (wat.core/* b 5)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/poly 100000000 1 2)))
