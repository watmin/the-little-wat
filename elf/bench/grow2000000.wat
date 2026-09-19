;; A tail-recursive accumulator -- the shape wat's own docs teach for building up state, and the
;; one the statement release cannot touch because every intermediate is the next call's argument.
;; With last-use plus a share count it extends in place instead: O(n) time and memory.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(wat.core/defn user/grow [n :- wat.type/i64 acc :- :user::Row] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.core/length acc)
    (user/grow (wat.core/- n 1) (wat.core/conj acc n))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/grow 2000000 (wat.core/Vector :- [wat.type/i64]))))
