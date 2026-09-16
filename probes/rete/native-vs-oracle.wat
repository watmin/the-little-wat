;; probes/rete/native-vs-oracle.wat: does wat's rete agree with its own SPEC?
;;
;; Every fire and insert verb in the rete ships TWO implementations:
;;
;;   :wat::rete::fire-rules        -> fire-rules$native   (the Rust kernel, what a program runs)
;;   :wat::rete::fire-rules$oracle                        (pure wat, "the SPEC / differential
;;                                                         oracle", fire.wat:356)
;;
;; and the same for fire-once, insert, insert-all and fire-rules-explain. wat-rs calls the wat
;; one the spec in its own source, which means the two are meant to agree — so putting one
;; session through both mouths is a check wat can run on itself, needing no other language.
;;
;; Agreement is the expected and unremarkable answer. Disagreement between a production
;; implementation and its own declared reference would be the most serious thing this repository
;; could find, which is exactly why it is worth ten minutes.
;;
;; The rule set is the one from rete/r01-chaining.wat: a guarded join, a derived fact feeding
;; another rule, a negation over that derived fact, an existence, and an accumulator — so the
;; comparison covers every condition form at once, not just a simple match.
;;
;; Run from the repository root: wat probes/rete/native-vs-oracle.wat

(:wat::core::defrecord :nv::Order    [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :nv::Stock    [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :nv::Hold     [id <- :wat::core::i64])
(:wat::core::defrecord :nv::Supplier [part <- :wat::core::String name <- :wat::core::String])

(:wat::core::defrecord :nv::Shippable [id <- :wat::core::i64 part <- :wat::core::String])
(:wat::core::defrecord :nv::Invoice   [id <- :wat::core::i64])
(:wat::core::defrecord :nv::Sourced   [part <- :wat::core::String])
(:wat::core::defrecord :nv::Tally     [n <- :wat::core::i64])

(:wat::rete::defrule :nv::shippable
  :when [(:nv::Order (?id <- :id) (?part <- :part))
         (:nv::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:nv::Shippable :id ?id :part ?part)])

(:wat::rete::defrule :nv::invoice
  :when [(:nv::Shippable (?id <- :id))
         (:wat::rete::not (:nv::Hold (?id <- :id)))]
  :then [(:nv::Invoice :id ?id)])

(:wat::rete::defrule :nv::sourced
  :when [(:nv::Stock (?part <- :part))
         (:wat::rete::exists (:nv::Supplier (?part <- :part)))]
  :then [(:nv::Sourced :part ?part)])

(:wat::rete::defrule :nv::tally
  :when [(?n <- (:wat::rete::acc::count) :from (:nv::Shippable))]
  :then [(:nv::Tally :n ?n)])

(:wat::rete::defquery :nv::q-Shippable :params [] :when [(?f <- :nv::Shippable)])
(:wat::rete::defquery :nv::q-Invoice   :params [] :when [(?f <- :nv::Invoice)])
(:wat::rete::defquery :nv::q-Sourced   :params [] :when [(?f <- :nv::Sourced)])
(:wat::rete::defquery :nv::q-Tally     :params [] :when [(?f <- :nv::Tally)])

(:wat::core::defn :nv::seeded [] -> :wat::rete::Session
  (:wat::rete::insert-all
    (:wat::rete::compile-all (:wat::rete::collect-rules :nv)
      (:wat::core::PersistentVector
        (:nv::q-Shippable) (:nv::q-Invoice) (:nv::q-Sourced) (:nv::q-Tally)))
    (:wat::core::PersistentVector :- [:wat::core::Record]
      (:nv::Order :id 1 :part "bolt")
      (:nv::Order :id 2 :part "nut")
      (:nv::Order :id 3 :part "washer")
      (:nv::Stock :part "bolt" :qty 10)
      (:nv::Stock :part "nut" :qty 5)
      (:nv::Stock :part "washer" :qty 0)
      (:nv::Hold :id 2)
      (:nv::Supplier :part "bolt" :name "acme")
      (:nv::Supplier :part "bolt" :name "globex"))))

;; the four query counts of a fired session, as one string
(:wat::core::defn :nv::shape [s <- :wat::rete::Session] -> :wat::core::String
  (:wat::string::concat
    (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:nv::q-Shippable)))) "/"
    (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:nv::q-Invoice)))) "/"
    (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:nv::q-Sourced)))) "/"
    (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:nv::q-Tally))))))

(:wat::core::defn :nv::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [native (:nv::shape (:wat::rete::fire-rules (:nv::seeded)))
                    oracle (:nv::shape (:wat::rete::fire-rules$oracle (:nv::seeded)))
                    derived-native (:wat::core::length
                                     (:wat::rete::collect-derived
                                       (:wat::rete::Session/production-memory
                                         (:wat::rete::fire-rules (:nv::seeded)))))
                    derived-oracle (:wat::core::length
                                     (:wat::rete::collect-derived
                                       (:wat::rete::Session/production-memory
                                         (:wat::rete::fire-rules$oracle (:nv::seeded)))))]
    (:wat::core::do
      (:nv::show "native  shippable/invoice/sourced/tally" native)
      (:nv::show "oracle  shippable/invoice/sourced/tally" oracle)
      (:nv::show "native  derived facts" (:wat::i64::to-string derived-native))
      (:nv::show "oracle  derived facts" (:wat::i64::to-string derived-oracle))
      (:nv::show "queries agree" (:wat::core::if (:wat::core::= native oracle) "true" "FALSE"))
      (:nv::show "derived counts agree"
                 (:wat::core::if (:wat::core::= derived-native derived-oracle) "true" "FALSE")))))
