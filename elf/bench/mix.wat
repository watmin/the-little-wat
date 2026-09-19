;; Three parameters, read four times each, 30 million times. The shape register allocation is
;; supposed to be for.
(wat.core/defn user/mix [n :- wat.type/i64 a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.core/+ a b)
    (user/mix (wat.core/- n 1)
              (wat.core/+ (wat.core/- a b) n)
              (wat.core/- (wat.core/+ b a) 1))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/mix 200000000 1 2)))
