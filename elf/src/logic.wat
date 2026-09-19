;; cond, and, or, not, and integer division -- 46 of the 297 occurrences elf/census.wat counts
;; between this compiler and compiling itself, and not one new instruction between them beyond a
;; `sete`. All four are `if` wearing a different hat.
;;
;; `and` and `or` answer the FIRST falsy / first truthy operand rather than a bool, which is
;; wat's rule; the tests below pin that down, because a compiler that answered `true`/`false`
;; would pass a laxer test and still be wrong.
;;
;; Run both ways; they must agree.

(wat.core/defn user/classify [n :- wat.type/i64] :- wat.type/String
  (wat.core/cond
    ((wat.core/< n 0)                                    "negative")
    ((wat.core/and (wat.core/= (wat.core/rem n 2) 0)
                   (wat.core/> n 100))                   "big and even")
    ((wat.core/or (wat.core/= n 7) (wat.core/= n 13))    "lucky-ish")
    ((wat.core/not (wat.core/> n 10))                    "small")
    (:else                                               "ordinary")))

(wat.core/defn user/gcd [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= b 0) a (user/gcd b (wat.core/rem a b))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/classify -5))
  (wat.kernel/println (user/classify 102))
  (wat.kernel/println (user/classify 13))
  (wat.kernel/println (user/classify 3))
  (wat.kernel/println (user/classify 55))

  ;; `/` truncates toward zero, which is what idiv does
  (wat.kernel/println (:wat::core::/ 7 2))
  (wat.kernel/println (:wat::core::/ -7 2))
  (wat.kernel/println (:wat::core::/ 1000000 7))

  ;; the short circuit answers an operand, not a bool
  (wat.kernel/println (wat.core/and true false))
  (wat.kernel/println (wat.core/or false true))
  (wat.kernel/println (wat.core/and (wat.core/> 2 1) (wat.core/> 3 2) (wat.core/> 4 3)))
  (wat.kernel/println (wat.core/or (wat.core/> 1 2) (wat.core/> 2 3) (wat.core/> 3 4)))
  (wat.kernel/println (wat.core/not (wat.core/not true)))

  ;; a cond in tail position, still eliminating its tail call
  (wat.kernel/println (user/gcd 1071 462)))
