;; cat32000.wat's accumulator with ONE difference: a second live object grows beside it.
;;
;; `str_cat_own` takes the in-place path only when two things hold -- the share count is 1, AND
;; the string is still the TOP of the heap (`cmpq %r15, %r9`), because a bump allocator can only
;; extend the last thing it handed out. cat32000.wat satisfies the second by accident: nothing
;; else allocates between appends. `:c::emit` does not, and this is why -- every append to
;; `:c::Out/code` has the hex strings, records and vectors of a whole form allocated after it.
;;
;; Two accumulators alternating is the smallest thing with that shape: each one's growth pushes
;; the other off the top of the heap, so neither ever takes the in-place path.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(wat.core/defn user/grow [n :- wat.type/i64 acc :- wat.type/String v :- :user::Row] :- wat.type/i64
  (wat.core/if (wat.core/= n 0)
    (wat.core/+ (wat.string/length acc) (wat.core/length v))
    (user/grow (wat.core/- n 1)
               (wat.string/concat acc "0123456789abcdef")
               (wat.core/conj v n))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/grow 32000 "" (wat.core/Vector :- [wat.type/i64]))))
