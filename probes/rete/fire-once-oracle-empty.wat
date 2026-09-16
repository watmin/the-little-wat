;; probes/rete/fire-once-oracle-empty.wat: what does fire-once$oracle actually produce?
;;
;; probes/rete/fire-verbs-compared.wat printed a joined list of tally VALUES for six fire verbs.
;; Five gave something; one gave an empty string:
;;
;;   fire-rules        (native)   2
;;   fire-rules$oracle            0|2
;;   fire-once         (native)   0
;;   fire-once$oracle             <empty>
;;   fire-fixpoint                0|2
;;   fire-stratified              0|2
;;
;; An empty join is ambiguous and must not be written up from one line. It could mean the query
;; returned no rows at all, or that it returned rows whose fact lookup failed — though the
;; latter would have printed "?" per row, so the former is likely. And "no rows" itself has two
;; readings: the accumulator contributed nothing on a single oracle pass, or that mouth derived
;; NOTHING at all in one pass.
;;
;; This separates them by counting rows rather than joining values, and by asking a
;; NON-accumulator query (the plain derived fact) beside the accumulator one. If the plain query
;; has rows and the tally does not, the accumulator is what is missing; if neither has rows, one
;; oracle pass derives nothing.
;;
;; Run from the repository root: wat probes/rete/fire-once-oracle-empty.wat

(:wat::core::defrecord :fo::Order     [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :fo::Stock     [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :fo::Shippable [id <- :wat::core::i64 qty <- :wat::core::i64])
(:wat::core::defrecord :fo::CountT    [n <- :wat::core::i64])

(:wat::rete::defrule :fo::shippable
  :when [(:fo::Order (?id <- :id) (?part <- :part))
         (:fo::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:fo::Shippable :id ?id :qty ?qty)])

(:wat::rete::defrule :fo::count-rule
  :when [(?n <- (:wat::rete::acc::count) :from (:fo::Shippable))]
  :then [(:fo::CountT :n ?n)])

(:wat::rete::defquery :fo::q-Shippable :params [] :when [(?f <- :fo::Shippable)])
(:wat::rete::defquery :fo::q-Count     :params [] :when [(?f <- :fo::CountT)])

(:wat::core::defn :fo::seeded [] -> :wat::rete::Session
  (:wat::rete::insert-all
    (:wat::rete::compile-all (:wat::rete::collect-rules :fo)
      (:wat::core::PersistentVector (:fo::q-Shippable) (:fo::q-Count)))
    (:wat::core::PersistentVector :- [:wat::core::Record]
      (:fo::Order :id 1 :part "bolt")
      (:fo::Order :id 2 :part "nut")
      (:fo::Stock :part "bolt" :qty 10)
      (:fo::Stock :part "nut" :qty 5))))

(:wat::core::defn :fo::report [label <- :wat::core::String s <- :wat::rete::Session] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label
      "  shippable rows: " (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:fo::q-Shippable))))
      "  tally rows: "     (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:fo::q-Count))))
      "  derived facts: "  (:wat::i64::to-string
                             (:wat::core::length
                               (:wat::rete::collect-derived (:wat::rete::Session/production-memory s)))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:fo::report "fire-once        (native)" (:wat::rete::fire-once (:fo::seeded)))
    (:fo::report "fire-once$oracle         " (:wat::rete::fire-once$oracle (:fo::seeded)))
    (:fo::report "fire-rules       (native)" (:wat::rete::fire-rules (:fo::seeded)))
    (:fo::report "fire-rules$oracle        " (:wat::rete::fire-rules$oracle (:fo::seeded)))))
