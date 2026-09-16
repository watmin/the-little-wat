;; probes/rete/native-vs-oracle-tally.wat: WHICH tally facts do the two mouths keep?
;;
;; probes/rete/native-vs-oracle.wat found wat's production engine and its own declared SPEC
;; disagreeing on one query out of four:
;;
;;   native  shippable/invoice/sourced/tally: 2/1/1/1
;;   oracle  shippable/invoice/sourced/tally: 2/1/1/2
;;
;; Both report 5 derived facts in total, so the difference is not in WHAT was derived but in what
;; survives as a Tally. The rule is an accumulator over a derived fact:
;;
;;   :when [(?n <- (:wat::rete::acc::count) :from (:nv::Shippable))]  :then [(:nv::Tally :n ?n)]
;;
;; Two readings, with different consequences, and the counts alone cannot tell them apart:
;;
;;   INTERMEDIATE LEAK   the oracle ran the accumulator more than once as the fixpoint grew —
;;                       counting 1 Shippable, then 2 — and kept BOTH Tally facts. Values would
;;                       be 1 and 2. The engine would then be exposing a mid-computation state
;;                       that the production mouth hides.
;;   DUPLICATE RETENTION both mouths derive the same Tally twice and only native collapses it
;;                       (F-066's set semantics applied unevenly). Values would be 2 and 2.
;;
;; This prints the VALUES, which decides it. It also asks fire-once and fire-fixpoint, to locate
;; the divergence: if fire-fixpoint matches the oracle, the difference is in stratification
;; rather than in the accumulator.
;;
;; Run from the repository root: wat probes/rete/native-vs-oracle-tally.wat

(:wat::core::defrecord :nt::Order     [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :nt::Stock     [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :nt::Shippable [id <- :wat::core::i64 part <- :wat::core::String])
(:wat::core::defrecord :nt::Tally     [n <- :wat::core::i64])

(:wat::rete::defrule :nt::shippable
  :when [(:nt::Order (?id <- :id) (?part <- :part))
         (:nt::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:nt::Shippable :id ?id :part ?part)])

(:wat::rete::defrule :nt::tally
  :when [(?n <- (:wat::rete::acc::count) :from (:nt::Shippable))]
  :then [(:nt::Tally :n ?n)])

(:wat::rete::defquery :nt::q-Shippable :params [] :when [(?f <- :nt::Shippable)])
(:wat::rete::defquery :nt::q-Tally     :params [] :when [(?f <- :nt::Tally)])

(:wat::core::defn :nt::seeded [] -> :wat::rete::Session
  (:wat::rete::insert-all
    (:wat::rete::compile-all (:wat::rete::collect-rules :nt)
      (:wat::core::PersistentVector (:nt::q-Shippable) (:nt::q-Tally)))
    (:wat::core::PersistentVector :- [:wat::core::Record]
      (:nt::Order :id 1 :part "bolt")
      (:nt::Order :id 2 :part "nut")
      (:nt::Stock :part "bolt" :qty 10)
      (:nt::Stock :part "nut" :qty 5))))

;; the tally values a fired session holds, sorted, joined
(:wat::core::defn :nt::tallies [s <- :wat::rete::Session] -> :wat::core::String
  (:wat::core::let [rows (:wat::rete::query s (:nt::q-Tally))]
    (:wat::string::join "|"
      (:wat::core::sort
        (:wat::core::foldl
          (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::core::String]) r <- :wat::core::PersistentMap]
            -> (:wat::core::Vector :- [:wat::core::String])
            (:wat::core::conj acc
              (:wat::core::match (:wat::map::get r "?f")
                [:wat::core::Option.Some {:value f} (:wat::i64::to-string (:nt::Tally/n f))]
                [:wat::core::Option.None {} "?"])))
          (:wat::core::Vector :- [:wat::core::String])
          rows)))))

(:wat::core::defn :nt::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [native    (:wat::rete::fire-rules (:nt::seeded))
                    oracle    (:wat::rete::fire-rules$oracle (:nt::seeded))
                    once      (:wat::rete::fire-once (:nt::seeded))
                    fixpoint  (:wat::rete::fire-fixpoint (:nt::seeded))]
    (:wat::core::do
      (:nt::show "shippables (native)" (:wat::i64::to-string (:wat::core::length (:wat::rete::query native (:nt::q-Shippable)))))
      (:nt::show "tally values, fire-rules (native)" (:nt::tallies native))
      (:nt::show "tally values, fire-rules$oracle  " (:nt::tallies oracle))
      (:nt::show "tally values, fire-once          " (:nt::tallies once))
      (:nt::show "tally values, fire-fixpoint      " (:nt::tallies fixpoint)))))
