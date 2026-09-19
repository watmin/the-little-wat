;; Storing a value that is dead afterwards is a MOVE, not a share -- and the two ways that is
;; wrong.
;;
;; `:c::push-args` increments the share count of every pointer-typed symbol passed to a user
;; function, because the callee's frame is a second reference and the caller may read it again
;; after the call returns. The count is increment-only (C-126), so from the first call onward
;; `conj` sees a count above 1 and copies. That is the 745 MB C-140 measured in the reader: the
;; arena is handed to `rd/add` as a bare parameter, once per node.
;;
;; The increment is only NEEDED when the caller can still observe the object afterwards. This
;; file is the boundary:
;;
;;   * `user/thread` is the reader's shape -- a vector carried in a record, read out, handed to
;;     a helper that conj's it, and never looked at again. Every reference is dead the moment it
;;     is passed. This one must get FAST without changing its answer.
;;   * `user/leak` reads the container AFTER the call. The local `a` is dead, but `b` still
;;     points at the same vector, so a move that mutates in place is visible. **A name bound
;;     from a field read aliases without being read.**
;;   * `user/alias` binds `w` to something that ANSWERS its own argument. `w` is dead after the
;;     call, but `v` is the same object. **A return value can alias an argument.**
;;
;; Run both ways; they must agree. The interpreter is the oracle, and it is right by
;; construction here: it has real reference counts and drops them.

(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defrecord :user::Box [v <- :user::Row  n <- :wat::core::i64])
(:wat::core::defrecord :user::St  [rows <- :user::Row  pos <- :wat::core::i64])

(wat.core/defn user/grow1 [v :- :user::Row] :- :user::Row
  (wat.core/conj v 7))

(wat.core/defn user/same [v :- :user::Row] :- :user::Row v)

;; the container outlives the local: 4 and 3, never 4 and 4
(wat.core/defn user/leak [b :- :user::Box] :- wat.type/i64
  (wat.core/let [a (:user::Box/v b)
                 g (user/grow1 a)]
    (wat.core/+ (wat.core/length g)
                (wat.core/* 100 (wat.core/length (:user::Box/v b))))))

;; the answer aliases the argument: 4 and 3, never 4 and 4
(wat.core/defn user/alias [v :- :user::Row] :- wat.type/i64
  (wat.core/let [w (user/same v)
                 g (user/grow1 w)]
    (wat.core/+ (wat.core/length g) (wat.core/* 100 (wat.core/length v)))))

;; and the shape the reader actually has
(wat.core/defn user/add [rows :- :user::Row n :- wat.type/i64 pos :- wat.type/i64] :- :user::St
  (:user::St :rows (wat.core/conj rows n) :pos (wat.core/+ pos 1)))

(wat.core/defn user/thread [n :- wat.type/i64 st :- :user::St] :- :user::St
  (wat.core/if (wat.core/= n 0) st
    (wat.core/let [r (:user::St/rows st)]
      (user/thread (wat.core/- n 1) (user/add r n (:user::St/pos st))))))

(wat.core/defn user/sum [v :- :user::Row i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/sum v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [base (wat.core/Vector :- [wat.type/i64] 10 20 30)]
    (wat.kernel/println (user/leak (:user::Box :v base :n 0)))   ;; 304, not 404
    (wat.kernel/println (wat.core/length base))                  ;; still 3
    (wat.kernel/println (user/alias base))                       ;; 304, not 404
    (wat.kernel/println (wat.core/length base)))                 ;; still 3

  (wat.core/let [r (user/thread 20000 (:user::St :rows (wat.core/Vector :- [wat.type/i64]) :pos 0))]
    (wat.kernel/println (wat.core/length (:user::St/rows r)))
    (wat.kernel/println (:user::St/pos r))
    (wat.kernel/println (wat.core/nth (:user::St/rows r) 0))
    (wat.kernel/println (wat.core/nth (:user::St/rows r) 19999))
    (wat.kernel/println (user/sum (:user::St/rows r) 0 0))))
