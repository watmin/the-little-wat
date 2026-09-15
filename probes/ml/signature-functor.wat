;; signature-functor.wat: The Little MLer ch 10's modules, encoded with surfaces.
;; - signature N  -> a surface over its abstract type T (the signature's `number`);
;; - structures NumberAsInt / NumberAsNum -> empty structs that extend-type N at i64 / num;
;; - functor PON's plus -> a generic fn over (:ml::N :- [T]).
;; Expected: 3 then 3 (1 + 2, revealed, through each structure)
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

;; functor PON (structure a_N : N) : P = struct fun plus(n, m) = ... end
(:wat::core::defn :ml::plus :- [T] [m <- (:ml::N :- [T]) a <- T b <- T] -> T
  (:wat::core::if (:ml::N/is-zero m a)
    b
    (:ml::N/succ m (:ml::plus m (:ml::N/pred m a) b))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [ia (:ml::NumberAsInt)
                    na (:ml::NumberAsNum)]
    (:wat::core::do
      (:wat::kernel::println (:ml::N/reveal ia (:ml::plus ia (:ml::N/conceal ia 1) (:ml::N/conceal ia 2))))
      (:wat::kernel::println (:ml::N/reveal na (:ml::plus na (:ml::N/conceal na 1) (:ml::N/conceal na 2)))))))
