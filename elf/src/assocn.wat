;; A positional update on a Vector, written in wat, working TODAY in both worlds.
;;
;; F-104 records that neither vector type has one: `(assoc v 1 99)` is refused, `vector::assoc`
;; does not exist, and the obvious hand-rolled route -- `take i ++ [x] ++ drop (i+1)` -- does not
;; close, because `take`/`drop` answer a Stream and there is no way back from one (F-088). That
;; finding is right about that route and reads as though no route exists. One does: fold the
;; vector, substituting at the index. It needs `nth`, `conj` and `length` and nothing else, so it
;; runs interpreted and compiles, which is the whole bar.
;;
;; It is **O(n)**, so it buys expressiveness and not speed -- wat's queued `assoc`-by-index
;; (COLLECTION-CAPABILITIES BUILD item 3, resolved 2026-06-20) is the one that buys speed, and a
;; structure-sharing vector makes it a path copy rather than a rebuild.
;;
;; Run both ways; they must agree.

(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))

(wat.core/defn user/assoc-n [v :- :user::Row k :- wat.type/i64 x :- wat.type/i64
                             i :- wat.type/i64 acc :- :user::Row] :- :user::Row
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/assoc-n v k x (wat.core/+ i 1)
      (wat.core/conj acc (wat.core/if (wat.core/= i k) x (wat.core/nth v i))))))

(wat.core/defn user/at [v :- :user::Row k :- wat.type/i64 x :- wat.type/i64] :- :user::Row
  (user/assoc-n v k x 0 (wat.core/Vector :- [wat.type/i64])))

(wat.core/defn user/sum [v :- :user::Row i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/sum v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/Vector :- [wat.type/i64] 10 20 30 40)]
    ;; the interior, the first and the last
    (wat.kernel/println (wat.core/nth (user/at v 2 99) 2))
    (wat.kernel/println (wat.core/nth (user/at v 0 99) 0))
    (wat.kernel/println (wat.core/nth (user/at v 3 99) 3))
    ;; the length never moves, and the neighbours never move
    (wat.kernel/println (wat.core/length (user/at v 2 99)))
    (wat.kernel/println (wat.core/nth (user/at v 2 99) 1))
    (wat.kernel/println (wat.core/nth (user/at v 2 99) 3))
    ;; an index past the end substitutes nothing -- a rebuild, not a bounds error
    (wat.kernel/println (user/sum (user/at v 9 99) 0 0))
    ;; and the original is untouched: this is a persistent update
    (wat.kernel/println (user/sum v 0 0))
    (wat.kernel/println (wat.core/nth v 2))))
