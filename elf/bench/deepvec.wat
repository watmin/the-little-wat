;; A vector deep enough to need a third level, checking itself.
;;
;; A 32-way node holds 32; two levels hold 1,024; 40,000 needs three. This is the size where a
;; tree walk has to be a LOOP rather than a couple of unrolled loads, so it is the size where
;; getting the depth arithmetic wrong stops being invisible.
;;
;; It carries its own oracle -- `nth i` is `i` by construction and the sum is the closed form --
;; because the interpreter clones per conj (F-124) and 40,000 of those is 1.6 billion element
;; copies. A test that needs a slow oracle does not get run; this one needs none.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))

;; **through a function, deliberately.** conj'd at the call site, `acc` is a parameter read once
;; and C-127's in-place path takes it -- which is linear already and never promotes anything.
;; The shared path is the one F-124 is about, and this is how you reach it.
(wat.core/defn user/add [acc :- :user::Row x :- wat.type/i64] :- :user::Row
  (wat.core/conj acc x))

(wat.core/defn user/upto [n :- wat.type/i64 i :- wat.type/i64 acc :- :user::Row] :- :user::Row
  (wat.core/if (wat.core/>= i n) acc
    (user/upto n (wat.core/+ i 1) (user/add acc i))))

(wat.core/defn user/sum [v :- :user::Row i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/sum v (wat.core/+ i 1) (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n 40000
                 v (user/upto n 0 (wat.core/Vector :- [wat.type/i64]))]
    (wat.test/assert-eq (wat.core/length v) n)
    ;; every boundary a 32-way trie has between 0 and 40000
    (wat.test/assert-eq (wat.core/nth v 0) 0)
    (wat.test/assert-eq (wat.core/nth v 31) 31)
    (wat.test/assert-eq (wat.core/nth v 32) 32)
    (wat.test/assert-eq (wat.core/nth v 1023) 1023)
    (wat.test/assert-eq (wat.core/nth v 1024) 1024)
    (wat.test/assert-eq (wat.core/nth v 32767) 32767)
    (wat.test/assert-eq (wat.core/nth v 32768) 32768)
    (wat.test/assert-eq (wat.core/nth v (wat.core/- n 1)) (wat.core/- n 1))
    ;; and every element, read in order, against the closed form
    (wat.test/assert-eq (user/sum v 0 0) (wat.core/quot (wat.core/* n (wat.core/- n 1)) 2))
    (wat.kernel/println "deepvec: ok")))
