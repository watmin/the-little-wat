;; `concat`'s in-place rule asks the wrong question of a non-symbol operand.
;;
;; C-140 gave `str_cat_own` a runtime guard: extend the left operand in place only when its
;; share count is exactly 1. The compiler decides whether to CALL it, and for the first operand
;; the rule reads "a non-variable operand is a temporary and always qualifies". That sentence is
;; false, and C-140 said so twice without fixing it.
;;
;; A field read is not a temporary. It is a BORROWED pointer into a container that is still
;; alive. And its share count really is 1, because a fresh value stored into a container is
;; stored by MOVE -- `:c::share` increments only symbols, which is what makes the reader's
;; `(conj rows n)` chain cheap (C-140). So the runtime guard sees 1, believes it, and appends
;; to a string the record is still pointing at.
;;
;; Run both ways; they must agree. The interpreter is the oracle: it has real reference counts.

(:wat::core::defrecord :user::S  [s <- :wat::core::String  n <- :wat::core::i64])
(:wat::core::defrecord :user::D  [in <- :user::S           k <- :wat::core::i64])

;; the field is filled from an EXPRESSION, so nothing increments its count: the record is its
;; sole owner and the count stays 1
(wat.core/defn user/mk [a :- wat.type/String b :- wat.type/String] :- :user::S
  (:user::S :s (wat.string/concat a b) :n 0))

;; ... and here the borrowed pointer is the left operand of a concat
(wat.core/defn user/grow [x :- :user::S] :- wat.type/String
  (wat.string/concat (:user::S/s x) "XY"))

;; one level deeper: a function that ANSWERS a borrowed pointer
(wat.core/defn user/peek [x :- :user::S] :- wat.type/String
  (:user::S/s x))

(wat.core/defn user/grow2 [x :- :user::S] :- wat.type/String
  (wat.string/concat (user/peek x) "ZW"))

;; and through two records
(wat.core/defn user/grow3 [d :- :user::D] :- wat.type/String
  (wat.string/concat (:user::S/s (:user::D/in d)) "QQ"))

;; the shapes that MUST stay fast: a genuine temporary, and a linear symbol
(wat.core/defn user/fold [i :- wat.type/i64 acc :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/<= i 0) acc
    (user/fold (wat.core/- i 1) (wat.string/concat acc "."))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [x (user/mk "ab" "cd")
                 g (user/grow x)]
    (wat.kernel/println g)                                    ;; abcdXY
    (wat.kernel/println (:user::S/s x))                       ;; abcd
    (wat.kernel/println (wat.string/length (:user::S/s x))))  ;; 4

  (wat.core/let [y (user/mk "ef" "gh")
                 g (user/grow2 y)]
    (wat.kernel/println g)                                    ;; efghZW
    (wat.kernel/println (:user::S/s y))                       ;; efgh
    (wat.kernel/println (wat.string/length (:user::S/s y))))  ;; 4

  (wat.core/let [d (:user::D :in (user/mk "ij" "kl") :k 1)
                 g (user/grow3 d)]
    (wat.kernel/println g)                                    ;; ijklQQ
    (wat.kernel/println (:user::S/s (:user::D/in d)))         ;; ijkl
    (wat.kernel/println (wat.string/length (:user::S/s (:user::D/in d)))))  ;; 4

  ;; a borrowed pointer read TWICE from the same container, the second time after the concat
  (wat.core/let [z (user/mk "mn" "op")
                 a (:user::S/s z)
                 b (wat.string/concat a "!!")]
    (wat.kernel/println b)                                    ;; mnop!!
    (wat.kernel/println (:user::S/s z)))                      ;; mnop

  (wat.kernel/println (wat.string/length (user/fold 2000 ""))))
