;; **Representation must be UNOBSERVABLE.** The wall, written before the thing it walls in.
;;
;; F-124: `conj` on a Vector clones the whole backing store, in the interpreter and here alike,
;; so building one by repeated `conj` is O(n^2). wat's answer is `PVec` -- the promoting vector:
;; an array while it is small or bulk-built, an RRB tree once persistent `conj` has pushed it
;; past a threshold, promoting one way and never back. Its own doc carries the rule this file
;; exists to enforce:
;;
;;     Two vectors with the same elements in the same order are the same value, whichever arm
;;     holds them.
;;
;; That rule is the whole risk of the change. A vector that reveals its arm -- through `length`,
;; `nth`, `conj`, an element type, or a trip through a function -- is a different value
;; depending on how it was built, and every equality, every index, every fold downstream of it
;; is quietly wrong. So: build the same sequence BOTH ways and compare it observation by
;; observation, at the sizes where an arm would change underneath it.
;;
;; The sizes are chosen against the structure, not by taste: 0 and 1 (empty and singleton),
;; 7 / 8 / 9 (either side of a promotion threshold), 31 / 32 / 33 (either side of a 32-way node),
;; 64 (two full nodes), 1000 / 1025 (either side of a second level). If the arm ever leaks, it
;; leaks at one of those.
;;
;; Run both ways; they must agree. The interpreter is the oracle, and it is the right one here
;; even though it is the slow implementation -- what it gets right is the VALUE.

(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :user::Names (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::defrecord :user::Pair [a <- :wat::core::i64  b <- :wat::core::i64])

;; 0..n-1, one persistent conj at a time -- the arm that promotes
(wat.core/defn user/upto [n :- wat.type/i64 i :- wat.type/i64 acc :- :user::Row] :- :user::Row
  (wat.core/if (wat.core/>= i n) acc
    (user/upto n (wat.core/+ i 1) (wat.core/conj acc i))))

(wat.core/defn user/sum [v :- :user::Row i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/sum v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)))))

;; every index, both vectors, or 0 at the first disagreement
(wat.core/defn user/same? [a :- :user::Row b :- :user::Row i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/not= (wat.core/length a) (wat.core/length b)) 0)
    ((wat.core/>= i (wat.core/length a)) 1)
    ((wat.core/not= (wat.core/nth a i) (wat.core/nth b i)) 0)
    (:else (user/same? a b (wat.core/+ i 1)))))

;; length, sum, first and last -- four observations that would each betray a wrong arm
(wat.core/defn user/probe [n :- wat.type/i64] :- wat.type/i64
  (wat.core/let [v (user/upto n 0 (wat.core/Vector :- [wat.type/i64]))]
    (wat.core/if (wat.core/= n 0) (wat.core/length v)
      (wat.core/+ (wat.core/* 1000000 (wat.core/length v))
        (wat.core/+ (wat.core/* 1000 (user/sum v 0 0))
          (wat.core/+ (wat.core/* 10 (wat.core/nth v 0))
                      (wat.core/nth v (wat.core/- (wat.core/length v) 1))))))))

;; a vector handed to a callee that conj's it: the caller's own must not move
(wat.core/defn user/grow-inside [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 99)))

(wat.core/defn user/main [] :- wat.type/nil
  ;; --- the sizes an arm would change at
  (wat.kernel/println (user/probe 0))
  (wat.kernel/println (user/probe 1))
  (wat.kernel/println (user/probe 7))
  (wat.kernel/println (user/probe 8))
  (wat.kernel/println (user/probe 9))
  (wat.kernel/println (user/probe 31))
  (wat.kernel/println (user/probe 32))
  (wat.kernel/println (user/probe 33))
  (wat.kernel/println (user/probe 64))
  (wat.kernel/println (user/probe 1000))
  (wat.kernel/println (user/probe 1025))

  ;; --- the wall itself: bulk-built and conj-built, compared observation by observation
  ;; four elements: both arms are the array, and they must agree
  (wat.core/let [bulk4 (wat.core/Vector :- [wat.type/i64] 0 1 2 3)
                 grown4 (user/upto 4 0 (wat.core/Vector :- [wat.type/i64]))]
    (wat.kernel/println (user/same? bulk4 grown4 0))
    (wat.kernel/println (user/same? (wat.core/conj bulk4 4) (wat.core/conj grown4 4) 0)))

  ;; nine elements: bulk stays an array at any length, conj has promoted -- the arms DIFFER
  ;; underneath and the value must not
  (wat.core/let [bulk9 (wat.core/Vector :- [wat.type/i64] 0 1 2 3 4 5 6 7 8)
                 grown9 (user/upto 9 0 (wat.core/Vector :- [wat.type/i64]))]
    (wat.kernel/println (user/same? bulk9 grown9 0))
    (wat.kernel/println (user/same? grown9 bulk9 0))
    (wat.kernel/println (wat.core/length bulk9))
    (wat.kernel/println (wat.core/length grown9))
    (wat.kernel/println (user/sum bulk9 0 0))
    (wat.kernel/println (user/sum grown9 0 0))
    ;; conj onto each again: an array growing and a tree growing must still agree
    (wat.kernel/println (user/same? (wat.core/conj bulk9 9) (wat.core/conj grown9 9) 0))
    ;; and through a function, which is where the share count makes conj copy (F-124)
    (wat.kernel/println (user/grow-inside bulk9))
    (wat.kernel/println (user/grow-inside grown9))
    (wat.kernel/println (wat.core/length bulk9))
    (wat.kernel/println (wat.core/length grown9)))

  ;; --- pointer elements: the payload is an address either side of a promotion
  (wat.core/let [names (wat.core/Vector :- [wat.type/String] "ada" "grace" "barbara")
                 more (wat.core/conj (wat.core/conj (wat.core/conj
                        (wat.core/conj (wat.core/conj (wat.core/conj
                          (wat.core/conj names "alan") "edsger") "tony") "barbara") "grace") "ada") "niklaus")]
    (wat.kernel/println (wat.core/length names))
    (wat.kernel/println (wat.core/nth names 0))
    (wat.kernel/println (wat.core/length more))
    (wat.kernel/println (wat.core/nth more 0))
    (wat.kernel/println (wat.core/nth more 3))
    (wat.kernel/println (wat.core/nth more 9)))

  ;; --- a record is built at a known size and never conj'd, so it stays the array arm forever
  (wat.core/let [p (:user::Pair :a 3 :b 4)]
    (wat.kernel/println (:user::Pair/a p))
    (wat.kernel/println (wat.core/length p))
    (wat.kernel/println (:user::Pair/b (wat.core/assoc p :b 12)))))
