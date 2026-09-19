;; grow20000.wat, with ONE difference: the accumulator goes through a user function on the way
;; to `conj` instead of being conj'd at the call site.
;;
;; That is the reader's shape -- `rd/add` takes the arena as a parameter and conj's a node onto
;; it -- and it is the one the share count cannot survive. `:c::push-args` increments the count
;; of every pointer-typed SYMBOL passed to a user function, because the callee's frame is a
;; second reference to it and the caller may read it again after the call returns. The count is
;; increment-only (C-126), so it never comes back down: from the first call onward `conj` sees a
;; count above 1, gives up on extending in place, and copies the whole vector. n copies of an
;; n-element vector is O(n^2), and reading elf/compile.wat that way costs 745 MB.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(wat.core/defn user/add [v :- :user::Row n :- wat.type/i64] :- :user::Row
  (wat.core/conj v n))
(wat.core/defn user/grow [n :- wat.type/i64 acc :- :user::Row] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.core/length acc)
    (user/grow (wat.core/- n 1) (user/add acc n))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/grow 20000 (wat.core/Vector :- [wat.type/i64]))))
