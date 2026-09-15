;; functor-dictionary.wat: the fallback encoding of ML's signature/structure/functor, a
;; dictionary: signature N is a generic struct of functions over the abstract type T, each
;; structure is a value of it, and functor PON's plus is one generic fn over any dictionary.
;; (The surface encoding cannot give a generic fn over (:ml::N :- [T]) a non-generic structure,
;; F-029.) Expected: 3 then 3
(:wat::core::defstruct :ml::NOps :- [T]
  [conceal <- [:wat::core::i64 :-> T]
   succ    <- [T :-> T]
   pred    <- [T :-> T]
   is-zero <- [T :-> :wat::core::bool]
   reveal  <- [T :-> :wat::core::i64]])

(:wat::core::defenum :ml::Num :wat::enum::Pure :Zero [] :OneMoreThan [n <- :ml::Num])
(:wat::core::defn :ml::num-conceal [n <- :wat::core::i64] -> :ml::Num
  (:wat::core::if (:wat::core::= n 0) (:ml::Num.Zero {}) (:ml::Num.OneMoreThan {:n (:ml::num-conceal (:wat::core::- n 1))})))
(:wat::core::defn :ml::num-succ [x <- :ml::Num] -> :ml::Num (:ml::Num.OneMoreThan {:n x}))
(:wat::core::defn :ml::num-pred [x <- :ml::Num] -> :ml::Num
  (:wat::core::match x [:ml::Num.Zero {} (:ml::Num.Zero {})] [:ml::Num.OneMoreThan {:n m} m]))
(:wat::core::defn :ml::num-is-zero [x <- :ml::Num] -> :wat::core::bool
  (:wat::core::match x [:ml::Num.Zero {} true] [:ml::Num.OneMoreThan {:n _m} false]))
(:wat::core::defn :ml::num-reveal [x <- :ml::Num] -> :wat::core::i64
  (:wat::core::match x [:ml::Num.Zero {} 0] [:ml::Num.OneMoreThan {:n m} (:wat::core::+ 1 (:ml::num-reveal m))]))

(:wat::core::defn :ml::int-id [x <- :wat::core::i64] -> :wat::core::i64 x)
(:wat::core::defn :ml::int-succ [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))
(:wat::core::defn :ml::int-pred [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::- x 1))
(:wat::core::defn :ml::int-is-zero [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::= x 0))

;; structure IntStruct = NumberAsInt(); structure NumStruct = NumberAsNum()
(:wat::core::defn :ml::int-struct [] -> (:ml::NOps :- [:wat::core::i64])
  (:ml::NOps :conceal :ml::int-id :succ :ml::int-succ :pred :ml::int-pred :is-zero :ml::int-is-zero :reveal :ml::int-id))
(:wat::core::defn :ml::num-struct [] -> (:ml::NOps :- [:ml::Num])
  (:ml::NOps :conceal :ml::num-conceal :succ :ml::num-succ :pred :ml::num-pred :is-zero :ml::num-is-zero :reveal :ml::num-reveal))

;; functor PON: one plus for any structure
(:wat::core::defn :ml::plus :- [T] [a-n <- (:ml::NOps :- [T]) a <- T b <- T] -> T
  (:wat::core::if ((:ml::NOps/is-zero a-n) a)
    b
    ((:ml::NOps/succ a-n) (:ml::plus a-n ((:ml::NOps/pred a-n) a) b))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [i (:ml::int-struct)
                    n (:ml::num-struct)]
    (:wat::core::do
      (:wat::kernel::println ((:ml::NOps/reveal i) (:ml::plus i ((:ml::NOps/conceal i) 1) ((:ml::NOps/conceal i) 2))))
      (:wat::kernel::println ((:ml::NOps/reveal n) (:ml::plus n ((:ml::NOps/conceal n) 1) ((:ml::NOps/conceal n) 2)))))))
