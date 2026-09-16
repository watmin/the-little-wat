;; wat's rete against clara-rules, second case: what happens when a fact goes away?
;;
;; r01 inserted facts and never took them back. This asks the question it left open, and the two
;; engines answer it by different mechanisms — which is the point of asking:
;;
;;   clara tracks dependencies: retracting a fact retracts what it supported.
;;   wat recomputes: "retract-then-fire recomputes the full closure from the reduced input, so
;;   consequences vanish transitively" (wat/rete/oracle/fire.wat:360).
;;
;; :wat::rete::retract takes a session and a fact and answers a session, dropping every fact
;; equal to it by value (wat/rete/oracle/insert.wat:77) — so it needs the same record value, and
;; the closure only changes on the next fire-rules.
;;
;; Four questions, each harder than the last:
;;   1. retract a base fact — does what was derived from it go?
;;   2. transitively — Stock feeds Shippable, Shippable feeds Invoice. Retracting the Stock must
;;      take BOTH derived layers, not just the first.
;;   3. with support left over — two Stock lines for one part. Retract one and the Shippable
;;      still has support, so it must stay.
;;   4. re-insert — put the fact back and the closure must come back.
;;
;; Seven of the eight answers are clara's (oracle/rete/r02-retraction.clj, run by
;; tools/rete-oracle.sh). The fourth is NOT, and the difference is the point of this case:
;;
;;   two Stock lines match one Order, so the rule fires twice and both firings derive the
;;   IDENTICAL Shippable. clara keeps 2/2; wat keeps 1/1.
;;
;; Neither is wrong. wat's closure is a SET of facts — it recomputes from the reduced input, so
;; two identical derivations collapse into one — while clara's working memory is a BAG of
;; derivations that happen to be equal. Both engines fire the rule twice: give the two firings
;; DIFFERENT payloads and both answer 2 (probes/rete/derived-multiplicity.wat). The difference
;; propagates consistently into the accumulators: acc::count over those facts answers 1 in wat
;; and 2 in clara (probes/rete/derived-multiplicity-tally.wat). F-066.
;;
;; So the expected file holds WAT's answers, with clara's recorded in the finding and in
;; probes/rete/retraction-scenarios.wat, which prints both side by side. Neither engine is the
;; other's oracle on this point, and making the numbers agree would have hidden the only
;; interesting thing here.
;;
;; Each result is "shippables/invoices".
;;
;; Run from the repository root (it reads the expected file by path):
;;   wat rete/r02-retraction.wat

(:wat::load-file! "lib/check.wat")

;; ---- facts

(:wat::core::defrecord :rt::Order [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :rt::Stock [part <- :wat::core::String qty <- :wat::core::i64])

;; ---- derived

(:wat::core::defrecord :rt::Shippable [id <- :wat::core::i64 part <- :wat::core::String])
(:wat::core::defrecord :rt::Invoice   [id <- :wat::core::i64])

;; ---- rules: Order + Stock -> Shippable -> Invoice

(:wat::rete::defrule :rt::shippable
  :when
  [(:rt::Order (?id <- :id) (?part <- :part))
   (:rt::Stock (?part <- :part) (?qty <- :qty))
   (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then
  [(:rt::Shippable :id ?id :part ?part)])

;; the second layer: a derived fact deriving another
(:wat::rete::defrule :rt::invoice
  :when
  [(:rt::Shippable (?id <- :id))]
  :then
  [(:rt::Invoice :id ?id)])

(:wat::rete::defquery :rt::q-Shippable :params [] :when [(?f <- :rt::Shippable)])
(:wat::rete::defquery :rt::q-Invoice   :params [] :when [(?f <- :rt::Invoice)])

;; ---- the session

(:wat::core::defn :rt::queries [] -> (:wat::core::PersistentVector :- [:wat::rete::Query])
  (:wat::core::PersistentVector (:rt::q-Shippable) (:rt::q-Invoice)))

(:wat::core::defn :rt::fresh [] -> :wat::rete::Session
  (:wat::rete::compile-all (:wat::rete::collect-rules :rt) (:rt::queries)))

;; "shippables/invoices" after firing
(:wat::core::defn :rt::counts [s <- :wat::rete::Session] -> :wat::core::String
  (:wat::core::let [fired (:wat::rete::fire-rules s)]
    (:wat::string::concat
      (:wat::i64::to-string (:wat::core::length (:wat::rete::query fired (:rt::q-Shippable))))
      "/"
      (:wat::i64::to-string (:wat::core::length (:wat::rete::query fired (:rt::q-Invoice)))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [order  (:rt::Order :id 1 :part "bolt")
                    stock  (:rt::Stock :part "bolt" :qty 10)
                    stockB (:rt::Stock :part "bolt" :qty 7)
                    spare  (:rt::Stock :part "washer" :qty 0)

                    ;; 1 and 2: both layers derived, then the base fact retracted
                    s1 (:wat::rete::insert (:wat::rete::insert (:rt::fresh) order) stock)
                    s2 (:wat::rete::retract s1 stock)
                    s3 (:wat::rete::insert s2 stock)

                    ;; 3: two Stock lines for one Order
                    t1 (:wat::rete::insert (:wat::rete::insert (:wat::rete::insert (:rt::fresh) order) stock) stockB)
                    t2 (:wat::rete::retract t1 stock)
                    t3 (:wat::rete::retract t2 stockB)

                    ;; retracting something nothing was derived from
                    u1 (:wat::rete::insert (:wat::rete::insert (:wat::rete::insert (:rt::fresh) order) stock) spare)
                    u2 (:wat::rete::retract u1 spare)]
    (:rete::check-results "oracle/rete/r02-retraction.expected"
                          "rete r02 retraction"
                          (:wat::core::Vector :- [:wat::core::String]
                            ;; 1: derived
                            (:rt::counts s1)
                            ;; 2: retract the support — both layers must go, transitively
                            (:rt::counts s2)
                            ;; 4: put it back — the closure returns
                            (:rt::counts s3)
                            ;; 3: two supports for one Order — wat collapses the identical
                            ;; derived facts to one where clara keeps both (F-066)
                            (:rt::counts t1)
                            ;; one retracted, support remains
                            (:rt::counts t2)
                            ;; both retracted, nothing supports it
                            (:rt::counts t3)
                            ;; an unrelated fact, before and after
                            (:rt::counts u1)
                            (:rt::counts u2)))))
