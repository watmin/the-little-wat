;; surface-concrete-param.wat (a): signature-functor.wat's structures, passed to a NON-generic
;; fn expecting the surface at a concrete argument, (:ml::N :- [:wat::core::i64]).
;; Expected: 3
(:wat::core::defsurface :ml::N :- [T] :nature :wat::core::Struct
  :features [(conceal [self <- (:ml::N :- [T]) n <- :wat::core::i64] -> T)
             (succ [self <- (:ml::N :- [T]) x <- T] -> T)
             (pred [self <- (:ml::N :- [T]) x <- T] -> T)
             (is-zero [self <- (:ml::N :- [T]) x <- T] -> :wat::core::bool)
             (reveal [self <- (:ml::N :- [T]) x <- T] -> :wat::core::i64)])

(:wat::core::defstruct :ml::NumberAsInt [])
(:wat::core::extend-type :ml::NumberAsInt (:ml::N :- [:wat::core::i64])
  (conceal [self n] -> :wat::core::i64 n)
  (succ [self x] -> :wat::core::i64 (:wat::core::+ x 1))
  (pred [self x] -> :wat::core::i64 (:wat::core::- x 1))
  (is-zero [self x] -> :wat::core::bool (:wat::core::= x 0))
  (reveal [self x] -> :wat::core::i64 x))

(:wat::core::defenum :ml::Num :wat::enum::Pure :Zero [] :OneMoreThan [n <- :ml::Num])
(:wat::core::defstruct :ml::NumberAsNum [])
(:wat::core::extend-type :ml::NumberAsNum (:ml::N :- [:ml::Num])
  (conceal [self n] -> :ml::Num
    (:wat::core::if (:wat::core::= n 0) (:ml::Num.Zero {}) (:ml::Num.OneMoreThan {:n (:ml::N/conceal self (:wat::core::- n 1))})))
  (succ [self x] -> :ml::Num (:ml::Num.OneMoreThan {:n x}))
  (pred [self x] -> :ml::Num
    (:wat::core::match x [:ml::Num.Zero {} (:ml::Num.Zero {})] [:ml::Num.OneMoreThan {:n m} m]))
  (is-zero [self x] -> :wat::core::bool
    (:wat::core::match x [:ml::Num.Zero {} true] [:ml::Num.OneMoreThan {:n _m} false]))
  (reveal [self x] -> :wat::core::i64
    (:wat::core::match x [:ml::Num.Zero {} 0] [:ml::Num.OneMoreThan {:n m} (:wat::core::+ 1 (:ml::N/reveal self m))])))

(:wat::core::defn :ml::plus-int [m <- (:ml::N :- [:wat::core::i64]) a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:ml::N/is-zero m a) b (:ml::N/succ m (:ml::plus-int m (:ml::N/pred m a) b))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:ml::plus-int (:ml::NumberAsInt) 1 2)))
