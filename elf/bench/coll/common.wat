;; The size is a file, not a literal, so no opponent can fold the loop (F-184).
(wat.core/defn user/digits [s :- wat.type/String i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.string/length s)) acc
    (wat.core/let [b (wat.string/byte-at s i)]
      (wat.core/if (wat.core/or (wat.core/< b 48) (wat.core/> b 57)) acc
        (user/digits s (wat.core/+ i 1)
          (wat.core/+ (wat.core/* acc 10) (wat.core/- b 48)))))))

(wat.core/defn user/n-of [] :- wat.type/i64
  (user/digits (wat.io/read-file "elf/bench/coll/n.txt") 0 0))

(wat.core/defn user/min-ix [v :- (wat.core/Vector :- [wat.type/i64]) i :- wat.type/i64 best :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) best
    (wat.core/if (wat.core/< (wat.core/nth v i) (wat.core/nth v best))
      (user/min-ix v (wat.core/+ i 1) i)
      (user/min-ix v (wat.core/+ i 1) best))))

(wat.core/defn user/drop-at [v :- (wat.core/Vector :- [wat.type/i64]) i :- wat.type/i64 j :- wat.type/i64
                             acc :- (wat.core/Vector :- [wat.type/i64])] :- (wat.core/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/>= j (wat.core/length v)) acc
    (wat.core/if (wat.core/= j i)
      (user/drop-at v i (wat.core/+ j 1) acc)
      (user/drop-at v i (wat.core/+ j 1) (wat.core/conj acc (wat.core/nth v j))))))

(wat.core/defrecord :user::Step [v :- (wat.core/Vector :- [wat.type/i64])
                                 out :- (wat.core/Vector :- [wat.type/i64])])

;; `sel` split in two so each self-call is the whole body. One tail call that
;; both drops and conjs was lowered to `cmp rax, 0`, which never exits.
(wat.core/defn user/one [v :- (wat.core/Vector :- [wat.type/i64])
                         out :- (wat.core/Vector :- [wat.type/i64])] :- :user::Step
  (wat.core/let [b (user/min-ix v 1 0)]
    (:user::Step :v (user/drop-at v b 0 (wat.core/Vector :- [wat.type/i64]))
                 :out (wat.core/conj out (wat.core/nth v b)))))

(wat.core/defn user/sel-go [st :- :user::Step] :- (wat.core/Vector :- [wat.type/i64])
  (user/sel (:user::Step/v st) (:user::Step/out st)))

(wat.core/defn user/sel [v :- (wat.core/Vector :- [wat.type/i64])
                         out :- (wat.core/Vector :- [wat.type/i64])] :- (wat.core/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/= (wat.core/length v) 0) out
    (user/sel-go (user/one v out))))

(wat.core/defn user/rank [sorted :- (wat.core/Vector :- [wat.type/i64]) p :- wat.type/i64 den :- wat.type/i64] :- wat.type/i64
  (wat.core/nth sorted
    (wat.core/- (wat.core/quot (wat.core/+ (wat.core/* p (wat.core/length sorted)) (wat.core/- den 1)) den) 1)))

(wat.core/defn user/tails [raw :- (wat.core/Vector :- [wat.type/i64])] :- wat.type/nil
  (wat.core/let [s (user/sel raw (wat.core/Vector :- [wat.type/i64]))]
    (wat.kernel/println
      (wat.string/concat "TAIL "
        (wat.string/concat (wat.i64/to-string (user/rank s 50 100))
          (wat.string/concat " "
            (wat.string/concat (wat.i64/to-string (user/rank s 99 100))
              (wat.string/concat " "
                (wat.string/concat (wat.i64/to-string (user/rank s 999 1000))
                  (wat.string/concat " " (wat.i64/to-string (wat.core/nth s (wat.core/- (wat.core/length s) 1)))))))))))))
