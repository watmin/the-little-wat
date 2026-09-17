;; okasaki/lib/implicit.wat — Chapter 11's ImplicitQueue: everything in the book, at once.
;;
;;     Digit<A> = Zero | One of A | Two of A * A
;;     Queue<A> = Shallow of Digit<A> | Deep of Digit<A> * Susp<Queue<Pair<A>>> * Digit<A>
;;
;; Three techniques stacked:
;;   ch 9  NUMERICAL REPRESENTATION  -- the digits are a redundant binary counter, and snoc is
;;                                     increment; the middle carries the "carry"
;;   ch 10 POLYMORPHIC RECURSION     -- the middle is a queue of PAIRS, a different instantiation
;;   ch 4  LAZINESS                  -- and it sits behind a suspension, so the carry propagates
;;                                     incrementally instead of cascading
;;
;; The carrier must therefore be an IMPURE enum (it holds a suspension, so not Pure -- containment
;; rule) which also shares its payload (so not a record -- F-098). Fifth occurrence of that rule.
;;
;; SKELETON FOR P-027: the suspension is the LRU stand-in.

(:wat::load-file! "susp.wat")

(:wat::core::defenum :ok::Pair :- [A] :wat::enum::Pure
  :P [a <- :A  b <- :A])

(:wat::core::defenum :ok::IDigit :- [A] :wat::enum::Pure
  :DZero []
  :DOne [x <- :A]
  :DTwo [x <- :A  y <- :A])

(:wat::core::defenum :ok::IQ :- [A] :wat::enum::Impure
  :Shallow [d <- (:ok::IDigit :- [A])]
  :Deep [f <- (:ok::IDigit :- [A])
         m <- (:ok::Susp :- [(:ok::IQ :- [(:ok::Pair :- [A])])])
         r <- (:ok::IDigit :- [A])])

(:wat::core::defn :ok::iq-empty :- [A] [] -> (:ok::IQ :- [A])
  (:ok::IQ.Shallow :- [A] {:d (:ok::IDigit.DZero :- [A] {})}))

(:wat::core::defn :ok::iq-null? :- [A] [q <- (:ok::IQ :- [A])] -> :wat::core::bool
  (:wat::core::match q
    [:ok::IQ.Shallow {:d d}
      (:wat::core::match d
        [:ok::IDigit.DZero {} true]
        [:ok::IDigit.DOne {:x x} false]
        [:ok::IDigit.DTwo {:x x :y y} false])]
    [:ok::IQ.Deep {:f f :m m :r r} false]))

(:wat::core::defn :ok::iq-snoc :- [A] [q <- (:ok::IQ :- [A]) y <- :A] -> (:ok::IQ :- [A])
  (:wat::core::match q
    [:ok::IQ.Shallow {:d d}
      (:wat::core::match d
        [:ok::IDigit.DZero {} (:ok::IQ.Shallow :- [A] {:d (:ok::IDigit.DOne :- [A] {:x y})})]
        [:ok::IDigit.DOne {:x x}
          (:ok::IQ.Deep :- [A]
            {:f (:ok::IDigit.DTwo :- [A] {:x x :y y})
             :m (:ok::delay (:wat::core::fn [] -> (:ok::IQ :- [(:ok::Pair :- [A])]) (:ok::iq-empty)))
             :r (:ok::IDigit.DZero :- [A] {})})]
        [:ok::IDigit.DTwo {:x x :y y2} q])]
    [:ok::IQ.Deep {:f f :m m :r r}
      (:wat::core::match r
        [:ok::IDigit.DZero {} (:ok::IQ.Deep :- [A] {:f f :m m :r (:ok::IDigit.DOne :- [A] {:x y})})]
        ;; the carry: two in the rear become one pair pushed into the middle, suspended
        [:ok::IDigit.DOne {:x x}
          (:ok::IQ.Deep :- [A]
            {:f f
             :m (:ok::delay (:wat::core::fn [] -> (:ok::IQ :- [(:ok::Pair :- [A])])
                  (:ok::iq-snoc (:ok::force m) (:ok::Pair.P :- [A] {:a x :b y}))))
             :r (:ok::IDigit.DZero :- [A] {})})]
        [:ok::IDigit.DTwo {:x x :y y2} q])]))

(:wat::core::defn :ok::iq-head :- [A] [q <- (:ok::IQ :- [A]) dflt <- :A] -> :A
  (:wat::core::match q
    [:ok::IQ.Shallow {:d d}
      (:wat::core::match d
        [:ok::IDigit.DZero {} dflt]
        [:ok::IDigit.DOne {:x x} x]
        [:ok::IDigit.DTwo {:x x :y y} x])]
    [:ok::IQ.Deep {:f f :m m :r r}
      (:wat::core::match f
        [:ok::IDigit.DZero {} dflt]
        [:ok::IDigit.DOne {:x x} x]
        [:ok::IDigit.DTwo {:x x :y y} x])]))

(:wat::core::defn :ok::iq-tail :- [A] [q <- (:ok::IQ :- [A])] -> (:ok::IQ :- [A])
  (:wat::core::match q
    [:ok::IQ.Shallow {:d d}
      (:wat::core::match d
        [:ok::IDigit.DZero {} q]
        [:ok::IDigit.DOne {:x x} (:ok::iq-empty)]
        [:ok::IDigit.DTwo {:x x :y y} (:ok::IQ.Shallow :- [A] {:d (:ok::IDigit.DOne :- [A] {:x y})})])]
    [:ok::IQ.Deep {:f f :m m :r r}
      (:wat::core::match f
        [:ok::IDigit.DTwo {:x x :y y}
          (:ok::IQ.Deep :- [A] {:f (:ok::IDigit.DOne :- [A] {:x y}) :m m :r r})]
        [:ok::IDigit.DOne {:x x}
          ;; front exhausted: borrow a pair from the middle, which is where the slowdown lives
          (:wat::core::let [mid (:ok::force m)]
            (:wat::core::if (:ok::iq-null? mid)
              (:ok::IQ.Shallow :- [A] {:d r})
              (:wat::core::match (:ok::iq-head mid (:ok::Pair.P :- [A] {:a x :b x}))
                [:ok::Pair.P {:a p :b s}
                  (:ok::IQ.Deep :- [A]
                    {:f (:ok::IDigit.DTwo :- [A] {:x p :y s})
                     :m (:ok::delay (:wat::core::fn [] -> (:ok::IQ :- [(:ok::Pair :- [A])])
                          (:ok::iq-tail (:ok::force m))))
                     :r r})])))]
        [:ok::IDigit.DZero {} (:ok::IQ.Shallow :- [A] {:d r})])]))
