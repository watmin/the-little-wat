;; okasaki/ch11-implicit-queue.wat — Chapter 11, implicit recursive slowdown: everything at once.
;;
;;     Digit<A> = Zero | One of A | Two of A * A
;;     Queue<A> = Shallow of Digit<A> | Deep of Digit<A> * Susp<Queue<Pair<A>>> * Digit<A>
;;
;; Three of the book's techniques stacked in one datatype:
;;   ch 9  NUMERICAL REPRESENTATION -- the digits are a redundant binary counter and `snoc` is
;;                                    increment; the middle carries the carry
;;   ch 10 POLYMORPHIC RECURSION    -- the middle is a queue of PAIRS, a different instantiation
;;   ch 4  LAZINESS                 -- and it sits behind a suspension, so a carry propagates
;;                                    incrementally rather than cascading through every level
;;
;; The carrier is an IMPURE enum: it holds a suspension (so not Pure -- containment rule) and must
;; share its payload (so not a record -- F-098). That is the fifth structure in this port to need
;; that exact shape.
;;
;; SKELETON FOR P-027: the suspension is the LRU stand-in, so the timing is the hack's. What this
;; chapter demonstrates is that the SHAPE type-checks and runs -- polymorphic recursion through a
;; suspension, which is the most demanding type in the book.
;;
;; Run: wat okasaki/ch11-implicit-queue.wat

(:wat::load-file! "lib/implicit.wat")

(:wat::core::defn :c11::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

(:wat::core::defenum :c11::A :wat::enum::Impure
  :A [q <- (:ok::IQ :- [:wat::core::i64])  bad <- :wat::core::i64])

(:wat::core::defn :c11::build [n <- :wat::core::i64] -> (:ok::IQ :- [:wat::core::i64])
  (:wat::core::foldl
    (:wat::core::fn [q <- (:ok::IQ :- [:wat::core::i64]) i <- :wat::core::i64]
      -> (:ok::IQ :- [:wat::core::i64]) (:ok::iq-snoc q i))
    (:ok::iq-empty) (:wat::core::range 0 n)))

(:wat::core::defn :c11::fifo [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match
    (:wat::core::foldl
      (:wat::core::fn [a <- :c11::A.A i <- :wat::core::i64] -> :c11::A.A
        (:wat::core::match a
          [:c11::A.A {:q q :bad b}
            (:c11::A.A {:q (:ok::iq-tail q)
                        :bad (:wat::core::if (:wat::core::= (:ok::iq-head q -1) i) b (:wat::core::+ b 1))})]))
      (:c11::A.A {:q (:c11::build n) :bad 0})
      (:wat::core::range 0 n))
    [:c11::A.A {:q q :bad b} b]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n 300]
    (:wat::core::do
      (:c11::say "the type is accepted        "
        "PASS -- Queue<A> holds Susp<Queue<Pair<A>>>: polymorphic recursion THROUGH a suspension")
      (:c11::say "FIFO over 300 elements      "
        (:wat::core::if (:wat::core::= (:c11::fifo n) 0) "PASS" "FAIL"))
      (:c11::say "empty after draining all    "
        (:wat::core::if (:ok::iq-null?
                          (:wat::core::foldl
                            (:wat::core::fn [q <- (:ok::IQ :- [:wat::core::i64]) i <- :wat::core::i64]
                              -> (:ok::IQ :- [:wat::core::i64]) (:ok::iq-tail q))
                            (:c11::build n) (:wat::core::range 0 n)))
          "PASS" "FAIL")))))
