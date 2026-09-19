;; Loop-carried allocation, which the statement release cannot touch: every intermediate vector
;; is the NEXT call's argument, so all 4000 of them are live at once. Memory is O(n^2).
(:wat::core::typealias :user::Strs (:wat::core::Vector :- [:wat::core::i64]))
(wat.core/defn user/grow [n :- wat.type/i64 acc :- :user::Strs] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.core/length acc)
    (user/grow (wat.core/- n 1) (wat.core/conj acc n))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/grow 4000 (wat.core/Vector :- [wat.type/i64]))))
