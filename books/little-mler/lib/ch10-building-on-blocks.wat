;; The Little MLer, chapter 10 (Building on Blocks): signatures, structures and functors.
;; Our own code.
;;
;; The encoding:
;; - signature N is a surface over its abstract type T (the signature's `number`), and a
;;   structure is a struct that implements it with extend-type at its representation;
;; - a functor is a generic fn over dictionaries (generic structs of functions). A generic fn
;;   cannot take the surface itself, (:ml::N :- [T]), given a structure (F-029), so each
;;   structure is turned into a dictionary, and functor PON maps an N dictionary to a P
;;   dictionary (C-023).
;; ML's opaque sealing (:>) is approached by a newtype: NumberAsSealed's number is a newtype
;; over int, which arithmetic refuses (probes/ml/newtype-plus.wat) and only the structure
;; unwraps, through the newtype's field accessor /0. Never print one: that panics (F-030).

;; signature N = sig type number; val conceal : int -> number; val succ : number -> number;
;;   val pred : number -> number; val is_zero : number -> bool; val reveal : number -> int end
(:wat::core::defsurface :ml::N :- [T] :nature :wat::core::Struct
  :features [(conceal [self <- (:ml::N :- [T]) n <- :wat::core::i64] -> T)
             (succ [self <- (:ml::N :- [T]) x <- T] -> T)
             (pred [self <- (:ml::N :- [T]) x <- T] -> T)
             (is-zero [self <- (:ml::N :- [T]) x <- T] -> :wat::core::bool)
             (reveal [self <- (:ml::N :- [T]) x <- T] -> :wat::core::i64)])

;; structure NumberAsInt :> N, with number = int
(:wat::core::defstruct :ml::NumberAsInt [])
(:wat::core::extend-type :ml::NumberAsInt (:ml::N :- [:wat::core::i64])
  (conceal [self n] -> :wat::core::i64 n)
  (succ [self x] -> :wat::core::i64 (:wat::core::+ x 1))
  (pred [self x] -> :wat::core::i64 (:wat::core::- x 1))
  (is-zero [self x] -> :wat::core::bool (:wat::core::= x 0))
  (reveal [self x] -> :wat::core::i64 x))

;; structure NumberAsNum :> N, with number = num (pred of Zero is Zero here; the book's
;; raises Too_small)
(:wat::core::defenum :ml::Num :wat::enum::Pure :Zero [] :OneMoreThan [n <- :ml::Num])
(:wat::core::defstruct :ml::NumberAsNum [])
(:wat::core::extend-type :ml::NumberAsNum (:ml::N :- [:ml::Num])
  (conceal [self n] -> :ml::Num
    (:wat::core::if (:wat::core::= n 0)
      (:ml::Num.Zero {})
      (:ml::Num.OneMoreThan {:n (:ml::N/conceal self (:wat::core::- n 1))})))
  (succ [self x] -> :ml::Num (:ml::Num.OneMoreThan {:n x}))
  (pred [self x] -> :ml::Num
    (:wat::core::match x [:ml::Num.Zero {} (:ml::Num.Zero {})] [:ml::Num.OneMoreThan {:n m} m]))
  (is-zero [self x] -> :wat::core::bool
    (:wat::core::match x [:ml::Num.Zero {} true] [:ml::Num.OneMoreThan {:n _m} false]))
  (reveal [self x] -> :wat::core::i64
    (:wat::core::match x [:ml::Num.Zero {} 0] [:ml::Num.OneMoreThan {:n m} (:wat::core::+ 1 (:ml::N/reveal self m))])))

;; structure NumberAsSealed :> N, with number a newtype over int
(:wat::core::newtype :ml::Sealed :wat::core::i64)
(:wat::core::defstruct :ml::NumberAsSealed [])
(:wat::core::extend-type :ml::NumberAsSealed (:ml::N :- [:ml::Sealed])
  (conceal [self n] -> :ml::Sealed (:ml::Sealed n))
  (succ [self x] -> :ml::Sealed (:ml::Sealed (:wat::core::+ (:ml::Sealed/0 x) 1)))
  (pred [self x] -> :ml::Sealed (:ml::Sealed (:wat::core::- (:ml::Sealed/0 x) 1)))
  (is-zero [self x] -> :wat::core::bool (:wat::core::= (:ml::Sealed/0 x) 0))
  (reveal [self x] -> :wat::core::i64 (:ml::Sealed/0 x)))

;; N and P as dictionaries.
(:wat::core::defstruct :ml::NOps :- [T]
  [conceal <- [:wat::core::i64 :-> T]
   succ    <- [T :-> T]
   pred    <- [T :-> T]
   is-zero <- [T :-> :wat::core::bool]
   reveal  <- [T :-> :wat::core::i64]])

(:wat::core::defstruct :ml::POps :- [T]
  [plus <- [T T :-> T]])

;; Each structure as an N dictionary: closures over the structure, calling its features.
(:wat::core::defn :ml::int-ops [s <- :ml::NumberAsInt] -> (:ml::NOps :- [:wat::core::i64])
  (:ml::NOps :conceal (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64 (:ml::N/conceal s n))
             :succ    (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:ml::N/succ s x))
             :pred    (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:ml::N/pred s x))
             :is-zero (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::bool (:ml::N/is-zero s x))
             :reveal  (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:ml::N/reveal s x))))

(:wat::core::defn :ml::num-ops [s <- :ml::NumberAsNum] -> (:ml::NOps :- [:ml::Num])
  (:ml::NOps :conceal (:wat::core::fn [n <- :wat::core::i64] -> :ml::Num (:ml::N/conceal s n))
             :succ    (:wat::core::fn [x <- :ml::Num] -> :ml::Num (:ml::N/succ s x))
             :pred    (:wat::core::fn [x <- :ml::Num] -> :ml::Num (:ml::N/pred s x))
             :is-zero (:wat::core::fn [x <- :ml::Num] -> :wat::core::bool (:ml::N/is-zero s x))
             :reveal  (:wat::core::fn [x <- :ml::Num] -> :wat::core::i64 (:ml::N/reveal s x))))

(:wat::core::defn :ml::sealed-ops [s <- :ml::NumberAsSealed] -> (:ml::NOps :- [:ml::Sealed])
  (:ml::NOps :conceal (:wat::core::fn [n <- :wat::core::i64] -> :ml::Sealed (:ml::N/conceal s n))
             :succ    (:wat::core::fn [x <- :ml::Sealed] -> :ml::Sealed (:ml::N/succ s x))
             :pred    (:wat::core::fn [x <- :ml::Sealed] -> :ml::Sealed (:ml::N/pred s x))
             :is-zero (:wat::core::fn [x <- :ml::Sealed] -> :wat::core::bool (:ml::N/is-zero s x))
             :reveal  (:wat::core::fn [x <- :ml::Sealed] -> :wat::core::i64 (:ml::N/reveal s x))))

;; functor PON (structure a_N : N) : P = struct fun plus(n, m) =
;;   if a_N.is_zero(n) then m else a_N.succ(plus(a_N.pred(n), m)) end
(:wat::core::defn :ml::pon-plus :- [T] [a-n <- (:ml::NOps :- [T]) a <- T b <- T] -> T
  (:wat::core::if ((:ml::NOps/is-zero a-n) a)
    b
    ((:ml::NOps/succ a-n) (:ml::pon-plus a-n ((:ml::NOps/pred a-n) a) b))))

(:wat::core::defn :ml::pon :- [T] [a-n <- (:ml::NOps :- [T])] -> (:ml::POps :- [T])
  (:ml::POps :plus (:wat::core::fn [a <- T b <- T] -> T (:ml::pon-plus a-n a b))))
