;; okasaki/ch10-bootstrapped-queue.wat — Chapter 10, data-structural bootstrapping.
;;
;; The queue's middle is itself A QUEUE OF LISTS:
;;     Queue<A> = E | Q of int * List<A> * Queue<List<A>> * int * List<A>
;; so the recursive occurrence sits at a DIFFERENT type instance. That is polymorphic recursion --
;; a datatype many type systems refuse outright, and most of the rest require explicit annotation
;; for because it cannot be inferred.
;;
;; It is not only the datatype. The functions over it are MUTUALLY recursive AND polymorphic:
;; `bsq-checkf` calls `bsq-head`/`bsq-tail` at `GList<A>` while `bsq-tail` calls `bsq-checkq` at
;; `A`, so each level of the recursion is a different instantiation.
;;
;; wat takes all of it. No laziness in this chapter, so no P-027 stand-in and no Impure carriers --
;; every type is a Pure enum.
;;
;; Run: wat okasaki/ch10-bootstrapped-queue.wat

(:wat::load-file! "lib/bootstrap.wat")

(:wat::core::defn :c10::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

(:wat::core::defenum :c10::A :wat::enum::Pure
  :A [q <- (:ok::BSQ :- [:wat::core::i64])  bad <- :wat::core::i64])

(:wat::core::defn :c10::fifo [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match
    (:wat::core::foldl
      (:wat::core::fn [a <- :c10::A.A i <- :wat::core::i64] -> :c10::A.A
        (:wat::core::match a
          [:c10::A.A {:q q :bad b}
            (:c10::A.A {:q (:ok::bsq-tail q)
                        :bad (:wat::core::if (:wat::core::= (:ok::bsq-head q -1) i) b (:wat::core::+ b 1))})]))
      (:c10::A.A {:q (:wat::core::foldl
                       (:wat::core::fn [q <- (:ok::BSQ :- [:wat::core::i64]) i <- :wat::core::i64]
                         -> (:ok::BSQ :- [:wat::core::i64]) (:ok::bsq-snoc q i))
                       (:ok::bsq-empty) (:wat::core::range 0 n))
                  :bad 0})
      (:wat::core::range 0 n))
    [:c10::A.A {:q q :bad b} b]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n 300]
    (:wat::core::do
      (:c10::say "polymorphic recursion accepted"
        "PASS -- Queue<A> contains Queue<List<A>>, and the functions over it are mutually recursive at differing instantiations")
      (:c10::say "FIFO over 300 elements        "
        (:wat::core::if (:wat::core::= (:c10::fifo n) 0) "PASS" "FAIL"))
      (:c10::say "empty after draining all      "
        (:wat::core::if (:ok::bsq-null?
                          (:wat::core::foldl
                            (:wat::core::fn [q <- (:ok::BSQ :- [:wat::core::i64]) i <- :wat::core::i64]
                              -> (:ok::BSQ :- [:wat::core::i64]) (:ok::bsq-tail q))
                            (:wat::core::foldl
                              (:wat::core::fn [q <- (:ok::BSQ :- [:wat::core::i64]) i <- :wat::core::i64]
                                -> (:ok::BSQ :- [:wat::core::i64]) (:ok::bsq-snoc q i))
                              (:ok::bsq-empty) (:wat::core::range 0 n))
                            (:wat::core::range 0 n)))
          "PASS" "FAIL")))))
