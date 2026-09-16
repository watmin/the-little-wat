;; probes/rete/derived-multiplicity.wat: when two supports derive the SAME fact, is it one or two?
;;
;; rete/r02-retraction.wat found wat and clara disagreeing on exactly this. One Order for "bolt",
;; two Stock lines for "bolt" — the rule fires twice and both firings produce the identical
;; (:rt::Shippable :id 1 :part "bolt"). clara answers 2; wat answers 1.
;;
;; Neither is obviously wrong, and the two possible explanations for wat's 1 have different
;; consequences, so this asks which it is:
;;
;;   COLLAPSE   both firings happen and the two identical derived facts become one, because the
;;              closure is a set of facts and wat recomputes it from the reduced input
;;              (wat/rete/oracle/fire.wat:360).
;;   ONE JOIN   the join produced a single token, so the rule only fired once.
;;
;; The two are told apart by making the derived facts DIFFERENT while keeping two supports: if
;; the rule fires once per matching Stock, distinct payloads give 2. And an accumulator over the
;; derived fact says what the engine thinks it has.
;;
;; Run from the repository root: wat probes/rete/derived-multiplicity.wat

(:wat::core::defrecord :dm::Order [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :dm::Stock [part <- :wat::core::String qty <- :wat::core::i64])

;; identical for both supports: only id and part, never the qty that differs
(:wat::core::defrecord :dm::Same [id <- :wat::core::i64 part <- :wat::core::String])
;; carries the qty, so each support derives a DIFFERENT fact
(:wat::core::defrecord :dm::Diff [id <- :wat::core::i64 qty <- :wat::core::i64])
;; what an accumulator makes of the identical ones
(:wat::core::defrecord :dm::Tally [n <- :wat::core::i64])

(:wat::rete::defrule :dm::same
  :when [(:dm::Order (?id <- :id) (?part <- :part))
         (:dm::Stock (?part <- :part) (?qty <- :qty))]
  :then [(:dm::Same :id ?id :part ?part)])

(:wat::rete::defrule :dm::diff
  :when [(:dm::Order (?id <- :id) (?part <- :part))
         (:dm::Stock (?part <- :part) (?qty <- :qty))]
  :then [(:dm::Diff :id ?id :qty ?qty)])

(:wat::rete::defrule :dm::tally
  :when [(?n <- (:wat::rete::acc::count) :from (:dm::Same))]
  :then [(:dm::Tally :n ?n)])

(:wat::rete::defquery :dm::q-Same  :params [] :when [(?f <- :dm::Same)])
(:wat::rete::defquery :dm::q-Diff  :params [] :when [(?f <- :dm::Diff)])
(:wat::rete::defquery :dm::q-Tally :params [] :when [(?f <- :dm::Tally)])

(:wat::core::defn :dm::show [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " (:wat::i64::to-string n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s (:wat::rete::fire-rules
                        (:wat::rete::insert-all
                          (:wat::rete::compile-all (:wat::rete::collect-rules :dm)
                            (:wat::core::PersistentVector (:dm::q-Same) (:dm::q-Diff) (:dm::q-Tally)))
                          (:wat::core::PersistentVector :- [:wat::core::Record]
                            (:dm::Order :id 1 :part "bolt")
                            (:dm::Stock :part "bolt" :qty 10)
                            (:dm::Stock :part "bolt" :qty 7))))]
    (:wat::core::do
      ;; two supports, one identical derived fact each. clara says 2.
      (:dm::show "identical derived facts (clara says 2)" (:wat::core::length (:wat::rete::query s (:dm::q-Same))))
      ;; two supports, DIFFERENT derived facts. If this is 2, the rule fires once per support
      ;; and the answer above is a COLLAPSE, not a single join.
      (:dm::show "distinct derived facts" (:wat::core::length (:wat::rete::query s (:dm::q-Diff))))
      ;; what the engine's own accumulator counts over the identical ones
      (:dm::show "tally rows" (:wat::core::length (:wat::rete::query s (:dm::q-Tally)))))))
