;; z-combinator.wat: the applicative-order Y combinator (Z), typed through a
;; self-referential struct. A Knot holds a function that takes a Knot, the standard typed
;; route (Haskell: newtype Mu a = In (Mu a -> a)). If wat accepts the recursive struct type,
;; recursion needs no names at all: fact below never refers to itself.
;;
;; Keyword spelling on purpose, so a failure is about the concept, not the syntax.
;; Expected: exit 0, prints 120.

(:wat::core::defstruct :u::Knot
  [unroll <- [:u::Knot :-> [:wat::core::i64 :-> :wat::core::i64]]])

;; z f = g(knot g), where g k = f (λv. ((k.unroll k) v))
(:wat::core::defn :u::z
  [f <- [[:wat::core::i64 :-> :wat::core::i64] :-> [:wat::core::i64 :-> :wat::core::i64]]]
  -> [:wat::core::i64 :-> :wat::core::i64]
  (:wat::core::let
    [g (:wat::core::fn [k <- :u::Knot] -> [:wat::core::i64 :-> :wat::core::i64]
         (f (:wat::core::fn [v <- :wat::core::i64] -> :wat::core::i64
              (:wat::core::let [u (:u::Knot/unroll k)
                                h (u k)]
                (h v)))))
     knot (:u::Knot :unroll g)]
    (g knot)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [fact (:u::z (:wat::core::fn [self <- [:wat::core::i64 :-> :wat::core::i64]]
                   -> [:wat::core::i64 :-> :wat::core::i64]
                   (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
                     (:wat::core::if (:wat::core::= n 0)
                       1
                       (:wat::core::* n (self (:wat::core::- n 1)))))))]
    (:wat::kernel::println (fact 5))))
