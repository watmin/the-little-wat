;; probes/rete/derived-multiplicity-tally.wat: what does wat's accumulator COUNT when two
;; supports derive the same fact?
;;
;; probes/rete/derived-multiplicity.wat settled the shape: wat keeps ONE identical derived fact
;; where clara keeps two, and both engines fire the rule twice (distinct payloads give 2 in
;; both). So wat's closure is a set of facts and clara's working memory is a bag of derivations.
;;
;; One number is missing. clara's (acc/count) over the identical derived facts answers 2 — it
;; counts derivations. wat produced one Tally ROW, but the probe never printed the tally's VALUE,
;; so whether wat counts 1 (consistent with its set semantics) or 2 is unmeasured. Asserting the
;; difference without that number would be guessing at the interesting half.
;;
;; Run from the repository root: wat probes/rete/derived-multiplicity-tally.wat

(:wat::core::defrecord :dt::Order [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :dt::Stock [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :dt::Same  [id <- :wat::core::i64 part <- :wat::core::String])
(:wat::core::defrecord :dt::Tally [n <- :wat::core::i64])

(:wat::rete::defrule :dt::same
  :when [(:dt::Order (?id <- :id) (?part <- :part))
         (:dt::Stock (?part <- :part) (?qty <- :qty))]
  :then [(:dt::Same :id ?id :part ?part)])

(:wat::rete::defrule :dt::tally
  :when [(?n <- (:wat::rete::acc::count) :from (:dt::Same))]
  :then [(:dt::Tally :n ?n)])

(:wat::rete::defquery :dt::q-Same  :params [] :when [(?f <- :dt::Same)])
(:wat::rete::defquery :dt::q-Tally :params [] :when [(?f <- :dt::Tally)])

(:wat::core::defn :dt::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :dt::tally-values [rows <- (:wat::core::PersistentVector :- [:wat::core::PersistentMap])] -> :wat::core::String
  (:wat::string::join "|"
    (:wat::core::foldl
      (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::core::String]) r <- :wat::core::PersistentMap]
        -> (:wat::core::Vector :- [:wat::core::String])
        (:wat::core::conj acc
          (:wat::core::match (:wat::map::get r "?f")
            [:wat::core::Option.Some {:value f} (:wat::i64::to-string (:dt::Tally/n f))]
            [:wat::core::Option.None {} "?"])))
      (:wat::core::Vector :- [:wat::core::String])
      rows)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s (:wat::rete::fire-rules
                        (:wat::rete::insert-all
                          (:wat::rete::compile-all (:wat::rete::collect-rules :dt)
                            (:wat::core::PersistentVector (:dt::q-Same) (:dt::q-Tally)))
                          (:wat::core::PersistentVector :- [:wat::core::Record]
                            (:dt::Order :id 1 :part "bolt")
                            (:dt::Stock :part "bolt" :qty 10)
                            (:dt::Stock :part "bolt" :qty 7))))
                    sames   (:wat::rete::query s (:dt::q-Same))
                    tallies (:wat::rete::query s (:dt::q-Tally))]
    (:wat::core::do
      (:dt::show "identical derived facts kept (clara keeps 2)"
                 (:wat::i64::to-string (:wat::core::length sames)))
      (:dt::show "tally rows" (:wat::i64::to-string (:wat::core::length tallies)))
      ;; the number that was missing: clara's acc/count answers 2 here
      (:dt::show "tally VALUE (clara says 2)" (:dt::tally-values tallies)))))
