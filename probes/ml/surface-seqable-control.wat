;; surface-seqable-control.wat (b): the case check.rs's Stone 118.3-B documents, a generic fn
;; over (:wat::core::Seqable :- [T]) given a Vector (a PARAMETRIC type that extend-types it).
;; Control for signature-functor.wat, whose structures are non-generic types.
;; Expected: 3
(:wat::core::defn :u::count-of :- [T] [s <- (:wat::core::Seqable :- [T])] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [acc <- :wat::core::i64 x <- T] -> :wat::core::i64 (:wat::core::+ acc 1))
                     0 (:wat::core::Seqable/seq s)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::count-of [7 8 9])))
