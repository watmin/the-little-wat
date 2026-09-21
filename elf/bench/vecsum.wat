;; **Vectors against C, both paths in one program** -- the board has measured strings and
;; records and never measured these (F-164). `conj` builds, `nth` reads.
;;
;; C-127 gave `conj` an in-place path when the accumulator is a last use, and C-145 made the
;; vector PROMOTE from flat to tree so `conj` is O(log n) instead of O(n) -- which closed a
;; 1,580x cliff. Neither has ever been held against a C array, so "vectors are fast now" is a
;; statement about our own history and not about the opponent.
;;
;; The build is the accumulator idiom, the same shape `elf/bench/grow2000000.wat` uses. The sum
;; reads every element back by index, which is where the promoted tree costs more than an
;; array: a flat vector indexes like C, a tree walks levels.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))

(wat.core/defn user/grow [n :- wat.type/i64 i :- wat.type/i64 acc :- :user::Row] :- :user::Row
  (wat.core/if (wat.core/= i n) acc
    (user/grow n (wat.core/+ i 1) (wat.core/conj acc i))))

(wat.core/defn user/sum [v :- :user::Row i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i (wat.core/length v)) acc
    (user/sum v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println
    (user/sum (user/grow 2000000 0 (wat.core/Vector :- [wat.type/i64])) 0 0)))
