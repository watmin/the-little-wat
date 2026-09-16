;; probes/rete/fire-verbs-compared.wat: which fire verbs leak the accumulator's empty first pass?
;;
;; F-067 measured four of them on a rule that counts a derived fact:
;;
;;   fire-rules (native)   2       fire-once        0
;;   fire-rules$oracle     0|2     fire-fixpoint    0|2
;;
;; One public verb was never asked: :wat::rete::fire-stratified. It matters because
;; fire-rules$oracle DELEGATES to it — "now delegates to fire-stratified (which handles
;; negation-over-derived correctly) instead of a bare fire-fixpoint. Within each stratum
;; fire-stratified still uses fire-fixpoint" (fire.wat:357). So:
;;
;;   if fire-stratified leaks, the stale row comes from the fixpoint INSIDE a stratum, and
;;     F-067's list of affected user-callable verbs grows by one;
;;   if it does not, then fire-rules$oracle's leak arrives from somewhere else and the
;;     mechanism is narrower than the delegation suggests.
;;
;; Either answer tightens the finding, and neither can be inferred from what is already
;; measured. fire-once$oracle is asked too, to separate "one pass" from "the wat mouth".
;;
;; Run from the repository root: wat probes/rete/fire-verbs-compared.wat

(:wat::core::defrecord :fv::Order     [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :fv::Stock     [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :fv::Shippable [id <- :wat::core::i64 qty <- :wat::core::i64])
(:wat::core::defrecord :fv::CountT    [n <- :wat::core::i64])

(:wat::rete::defrule :fv::shippable
  :when [(:fv::Order (?id <- :id) (?part <- :part))
         (:fv::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:fv::Shippable :id ?id :qty ?qty)])

(:wat::rete::defrule :fv::count-rule
  :when [(?n <- (:wat::rete::acc::count) :from (:fv::Shippable))]
  :then [(:fv::CountT :n ?n)])

(:wat::rete::defquery :fv::q-Count :params [] :when [(?f <- :fv::CountT)])

(:wat::core::defn :fv::seeded [] -> :wat::rete::Session
  (:wat::rete::insert-all
    (:wat::rete::compile-all (:wat::rete::collect-rules :fv)
      (:wat::core::PersistentVector (:fv::q-Count)))
    (:wat::core::PersistentVector :- [:wat::core::Record]
      (:fv::Order :id 1 :part "bolt")
      (:fv::Order :id 2 :part "nut")
      (:fv::Stock :part "bolt" :qty 10)
      (:fv::Stock :part "nut" :qty 5))))

(:wat::core::defn :fv::vals [s <- :wat::rete::Session] -> :wat::core::String
  (:wat::string::join "|"
    (:wat::core::sort
      (:wat::core::foldl
        (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::core::String]) r <- :wat::core::PersistentMap]
          -> (:wat::core::Vector :- [:wat::core::String])
          (:wat::core::conj acc
            (:wat::core::match (:wat::map::get r "?f")
              [:wat::core::Option.Some {:value rec} (:wat::i64::to-string (:fv::CountT/n rec))]
              [:wat::core::Option.None {} "?"])))
        (:wat::core::Vector :- [:wat::core::String])
        (:wat::rete::query s (:fv::q-Count))))))

(:wat::core::defn :fv::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; the four F-067 already has, re-measured here so the table is one run
    (:fv::show "fire-rules        (native)" (:fv::vals (:wat::rete::fire-rules (:fv::seeded))))
    (:fv::show "fire-rules$oracle (the SPEC)" (:fv::vals (:wat::rete::fire-rules$oracle (:fv::seeded))))
    (:fv::show "fire-once         (native)" (:fv::vals (:wat::rete::fire-once (:fv::seeded))))
    (:fv::show "fire-once$oracle          " (:fv::vals (:wat::rete::fire-once$oracle (:fv::seeded))))
    (:fv::show "fire-fixpoint             " (:fv::vals (:wat::rete::fire-fixpoint (:fv::seeded))))
    ;; the one never asked
    (:fv::show "fire-stratified           " (:fv::vals (:wat::rete::fire-stratified (:fv::seeded))))))
