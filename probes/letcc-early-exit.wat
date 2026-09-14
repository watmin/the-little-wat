;; letcc-early-exit.wat: the escape half of Seasoned Schemer's letcc, via Result/try.
;; letcc's main use in the book is early exit: abandon all pending work and answer now.
;; Here: multiply a vector, and the moment a 0 is seen, answer 0 WITHOUT performing any
;; pending multiplication. The recursion is not a tail call, so work really is pending.
;;
;; Each frame prints its element AFTER its Result/try returns, i.e. only when it goes on to
;; multiply. Expected output:
;;   4 3 2 (unwinding [2 3 4]) and nothing for [2 3 0 5]: the Err from the 0 skips both
;;   pending frames, and the 5 is never visited. Then "letcc-early-exit: ok".

(:wat::core::defn :u::product-from
  [xs <- (:wat::core::Vector :- [:wat::core::i64])
   i  <- :wat::core::i64]
  -> (:wat::core::Result :- [:wat::core::i64 :wat::core::i64])
  (:wat::core::cond
    ((:wat::core::= i (:wat::core::length xs)) (:wat::core::Result.Ok {:value 1}))
    ((:wat::core::= (:wat::core::nth xs i) 0) (:wat::core::Result.Err {:error 0}))
    (:else
      (:wat::core::let [x    (:wat::core::nth xs i)
                        more (:wat::core::Result/try (:u::product-from xs (:wat::core::+ i 1)))]
        (:wat::core::do
          (:wat::kernel::println x)
          (:wat::core::Result.Ok {:value (:wat::core::* x more)}))))))

;; The "letcc point": an Err is the escaped answer, an Ok the normal one.
(:wat::core::defn :u::product
  [xs <- (:wat::core::Vector :- [:wat::core::i64])]
  -> :wat::core::i64
  (:wat::core::match (:u::product-from xs 0)
    [:wat::core::Result.Ok {:value v} v]
    [:wat::core::Result.Err {:error e} e]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:u::product [2 3 4]) 24)
    (:wat::test::assert-eq (:u::product [2 3 0 5]) 0)
    (:wat::kernel::println "letcc-early-exit: ok")))
