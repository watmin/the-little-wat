;; probes/rete/accumulator-empty-pass.wat: which accumulators leak a first-pass result?
;;
;; probes/rete/accumulator-count-leak.wat found wat's production engine and its own declared SPEC
;; disagreeing on an accumulator over a DERIVED fact:
;;
;;   count native       : 2      <- correct: two Shippables were derived
;;   count SPEC         : 0|2    <- a stale n=0 survives beside the right answer
;;   count fire-fixpoint: 0|2    <- and the public fixpoint verb keeps both
;;
;; The accumulator runs on the first pass, before anything has been derived, and produces a
;; Tally of 0; the next pass produces 2; and because the closure is a SET OF FACTS (F-066) the
;; two distinct values both survive. Native suppresses the stale one, the SPEC does not.
;;
;; accum-pass.wat:16 says the folds are not uniform: "bare folds (count/sum/distinct/all/
;; group-by) assoc their result into the token's bindings; Option folds (min/max/mean) match
;; inline (None -> drop)". If so, an empty first pass yields a value for count and sum — 0 and
;; 0 — but NOTHING for min/max/mean, which would leak no stale row at all. That is a sharp,
;; checkable prediction and it decides how wide the defect is.
;;
;; NOTE ON SPELLING, learned the hard way: an accumulator's operand is a ?-VARIABLE bound in the
;; :from condition, not a field keyword. `(:wat::rete::acc::sum ?v) :from (:R (?v <- :value))`,
;; never `(acc::sum :value)`. Getting that wrong raises "acc: var unbound" from
;; wat/rete/acc.wat:83 — deep in wat's own source, and easy to mistake for a defect in wat. It
;; was mine.
;;
;; Run from the repository root: wat probes/rete/accumulator-empty-pass.wat

(:wat::core::defrecord :ae::Order     [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :ae::Stock     [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :ae::Shippable [id <- :wat::core::i64 qty <- :wat::core::i64])

(:wat::core::defrecord :ae::CountT [n <- :wat::core::i64])
(:wat::core::defrecord :ae::SumT   [n <- :wat::core::i64])
(:wat::core::defrecord :ae::MaxT   [n <- :wat::core::i64])
(:wat::core::defrecord :ae::MinT   [n <- :wat::core::i64])

(:wat::rete::defrule :ae::shippable
  :when [(:ae::Order (?id <- :id) (?part <- :part))
         (:ae::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:ae::Shippable :id ?id :qty ?qty)])

;; bare folds: always produce a value, even over nothing
(:wat::rete::defrule :ae::count-rule
  :when [(?n <- (:wat::rete::acc::count) :from (:ae::Shippable))]
  :then [(:ae::CountT :n ?n)])

(:wat::rete::defrule :ae::sum-rule
  :when [(?n <- (:wat::rete::acc::sum ?q) :from (:ae::Shippable (?q <- :qty)))]
  :then [(:ae::SumT :n ?n)])

;; Option folds: accum-pass.wat says None is DROPPED, so an empty pass should leak nothing
(:wat::rete::defrule :ae::max-rule
  :when [(?n <- (:wat::rete::acc::max ?q) :from (:ae::Shippable (?q <- :qty)))]
  :then [(:ae::MaxT :n ?n)])

(:wat::rete::defrule :ae::min-rule
  :when [(?n <- (:wat::rete::acc::min ?q) :from (:ae::Shippable (?q <- :qty)))]
  :then [(:ae::MinT :n ?n)])

(:wat::rete::defquery :ae::q-Count :params [] :when [(?f <- :ae::CountT)])
(:wat::rete::defquery :ae::q-Sum   :params [] :when [(?f <- :ae::SumT)])
(:wat::rete::defquery :ae::q-Max   :params [] :when [(?f <- :ae::MaxT)])
(:wat::rete::defquery :ae::q-Min   :params [] :when [(?f <- :ae::MinT)])

(:wat::core::defn :ae::seeded [] -> :wat::rete::Session
  (:wat::rete::insert-all
    (:wat::rete::compile-all (:wat::rete::collect-rules :ae)
      (:wat::core::PersistentVector (:ae::q-Count) (:ae::q-Sum) (:ae::q-Max) (:ae::q-Min)))
    (:wat::core::PersistentVector :- [:wat::core::Record]
      (:ae::Order :id 1 :part "bolt")
      (:ae::Order :id 2 :part "nut")
      (:ae::Stock :part "bolt" :qty 10)
      (:ae::Stock :part "nut" :qty 5))))

(:wat::core::defn :ae::vals [rows <- (:wat::core::PersistentVector :- [:wat::core::PersistentMap])
                             f <- [:wat::core::Record :-> :wat::core::i64]] -> :wat::core::String
  (:wat::string::join "|"
    (:wat::core::sort
      (:wat::core::foldl
        (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::core::String]) r <- :wat::core::PersistentMap]
          -> (:wat::core::Vector :- [:wat::core::String])
          (:wat::core::conj acc
            (:wat::core::match (:wat::map::get r "?f")
              [:wat::core::Option.Some {:value rec} (:wat::i64::to-string (f rec))]
              [:wat::core::Option.None {} "?"])))
        (:wat::core::Vector :- [:wat::core::String])
        rows))))

(:wat::core::defn :ae::count-n [r <- :wat::core::Record] -> :wat::core::i64 (:ae::CountT/n r))
(:wat::core::defn :ae::sum-n   [r <- :wat::core::Record] -> :wat::core::i64 (:ae::SumT/n r))
(:wat::core::defn :ae::max-n   [r <- :wat::core::Record] -> :wat::core::i64 (:ae::MaxT/n r))
(:wat::core::defn :ae::min-n   [r <- :wat::core::Record] -> :wat::core::i64 (:ae::MinT/n r))

(:wat::core::defn :ae::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [native (:wat::rete::fire-rules (:ae::seeded))
                    spec   (:wat::rete::fire-rules$oracle (:ae::seeded))]
    (:wat::core::do
      (:wat::kernel::println "-- bare folds: a value even over nothing (expect a stale 0 from the SPEC) --")
      (:ae::show "count  native" (:ae::vals (:wat::rete::query native (:ae::q-Count)) :ae::count-n))
      (:ae::show "count  SPEC  " (:ae::vals (:wat::rete::query spec   (:ae::q-Count)) :ae::count-n))
      (:ae::show "sum    native" (:ae::vals (:wat::rete::query native (:ae::q-Sum)) :ae::sum-n))
      (:ae::show "sum    SPEC  " (:ae::vals (:wat::rete::query spec   (:ae::q-Sum)) :ae::sum-n))
      (:wat::kernel::println "-- Option folds: None is dropped, so an empty pass should leak nothing --")
      (:ae::show "max    native" (:ae::vals (:wat::rete::query native (:ae::q-Max)) :ae::max-n))
      (:ae::show "max    SPEC  " (:ae::vals (:wat::rete::query spec   (:ae::q-Max)) :ae::max-n))
      (:ae::show "min    native" (:ae::vals (:wat::rete::query native (:ae::q-Min)) :ae::min-n))
      (:ae::show "min    SPEC  " (:ae::vals (:wat::rete::query spec   (:ae::q-Min)) :ae::min-n)))))
