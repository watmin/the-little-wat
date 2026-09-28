;; R20 fixture (excursus 008 stone 3a round 9): a self-tail-recursive walker whose FIRST
;; parameter `v` is read-only (passed through unchanged on every recursive call, and read via
;; `nth`) -- like `drop-arm2.wat`'s `ctx`, but here a SECOND, nested `if` sits beside the
;; self-tail call, and one of ITS two arms does not mention `v` at all (`(if (= i k) 0 (nth v
;; i))`). The caller keeps using `v` after the walk returns, so its one reference must survive
;; the whole recursion, dropped exactly once, at the base case.
;;
;; Before the fix, `:c::arm-dead?` also fired for the nested if's `0` arm (occ 0 there, occ >0
;; in the sibling `(nth v i)` arm, and `v`'s last textual mention held by that nested if) and
;; dropped `v` a second time on the one iteration where `i` matched `k` -- one drop too many,
;; well before the base case's own (correct) drop is ever reached.

(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))

(wat.core/defn user/walk [v :- :user::Row k :- wat.type/i64 i :- wat.type/i64 acc :- wat.type/i64]
    :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/walk v k (wat.core/+ i 1)
      (wat.core/+ acc (wat.core/if (wat.core/= i k) 0 (wat.core/nth v i))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/Vector :- [wat.type/i64] 10 20 30 40)]
    (wat.kernel/println (user/walk v 2 0 0))
    (wat.kernel/println (wat.core/nth v 0))))
