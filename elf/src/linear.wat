;; In-place `conj`, and the two proofs it needs.
;;
;; A reference count of 1 is NOT enough to mutate in place. In `(do (conj acc 1) (nth acc 0))`
;; the slot holding `acc` is the only reference -- count 1 -- and mutating would still be wrong,
;; because `conj` is pure and `acc` is read afterwards. Rust escapes this because `v.push(x)`
;; takes `&mut v`, which makes the old value unreachable by construction. A pure `conj` does not.
;;
;; So the compiler needs both halves, and this file exercises each one failing on its own:
;;
;;   * `user/build` -- `acc` is read at most once on every path, and nothing else holds the
;;     vector, so both proofs hold and the runtime extends in place. 2000 elements in constant
;;     memory instead of 4 MB of copies.
;;   * `user/bump`  -- `v` is read once, so the COMPILER says in place is allowed; but the caller
;;     still holds the vector, the share count is 2, and the RUNTIME copies. If the increment
;;     were missing, `base` would come back with four elements instead of three.
;;   * `user/twice` -- `v` is read twice on one path, so the compiler never offers the fast path
;;     at all, whatever the count says.
;;
;; Run both ways; they must agree. The interpreter is the oracle for all of it.

(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))

(wat.core/defn user/build [n :- wat.type/i64 acc :- :user::Row] :- :user::Row
  (wat.core/if (wat.core/= n 0) acc
    (user/build (wat.core/- n 1) (wat.core/conj acc n))))

(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/nth (wat.core/conj v 99) 3))

(wat.core/defn user/twice [v :- :user::Row] :- wat.type/i64
  (wat.core/+ (wat.core/nth (wat.core/conj v 99) 3) (wat.core/length v)))

(wat.core/defn user/sum [v :- :user::Row i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/sum v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [base (wat.core/Vector :- [wat.type/i64] 10 20 30)]
    (wat.kernel/println (user/bump base))          ;; 99 -- the appended element
    (wat.kernel/println (wat.core/length base))    ;; 3, NOT 4: the count said shared
    (wat.kernel/println (user/twice base))         ;; 99 + 3
    (wat.kernel/println (wat.core/length base))    ;; still 3
    (wat.kernel/println (wat.core/nth base 2)))    ;; and unchanged

  ;; the shape that gets both proofs: 2000 conjs threaded through a tail call
  (wat.core/let [r (user/build 2000 (wat.core/Vector :- [wat.type/i64]))]
    (wat.kernel/println (wat.core/length r))
    (wat.kernel/println (wat.core/nth r 0))
    (wat.kernel/println (wat.core/nth r 1999))
    (wat.kernel/println (user/sum r 0 0))))
