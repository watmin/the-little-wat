;; probes/rete/retraction-scenarios.wat: wat's answer to every one of r02's questions.
;;
;; rete/r02-retraction.wat checks wat against clara and stops at the first mismatch, which came
;; at result 3 (two supports for one Order: wat 1/1, clara 2/2). That left results 4 to 7
;; unmeasured — and the standing rule here is to capture what happened, not to re-run a red
;; until it turns green.
;;
;; This prints wat's answer to all eight, with clara's beside it, so the whole picture is on
;; record before anything is rewritten.
;;
;; Run from the repository root: wat probes/rete/retraction-scenarios.wat

(:wat::core::defrecord :rs2::Order [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :rs2::Stock [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :rs2::Shippable [id <- :wat::core::i64 part <- :wat::core::String])
(:wat::core::defrecord :rs2::Invoice   [id <- :wat::core::i64])

(:wat::rete::defrule :rs2::shippable
  :when [(:rs2::Order (?id <- :id) (?part <- :part))
         (:rs2::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:rs2::Shippable :id ?id :part ?part)])

(:wat::rete::defrule :rs2::invoice
  :when [(:rs2::Shippable (?id <- :id))]
  :then [(:rs2::Invoice :id ?id)])

(:wat::rete::defquery :rs2::q-Shippable :params [] :when [(?f <- :rs2::Shippable)])
(:wat::rete::defquery :rs2::q-Invoice   :params [] :when [(?f <- :rs2::Invoice)])

(:wat::core::defn :rs2::fresh [] -> :wat::rete::Session
  (:wat::rete::compile-all (:wat::rete::collect-rules :rs2)
    (:wat::core::PersistentVector (:rs2::q-Shippable) (:rs2::q-Invoice))))

(:wat::core::defn :rs2::counts [s <- :wat::rete::Session] -> :wat::core::String
  (:wat::core::let [fired (:wat::rete::fire-rules s)]
    (:wat::string::concat
      (:wat::i64::to-string (:wat::core::length (:wat::rete::query fired (:rs2::q-Shippable))))
      "/"
      (:wat::i64::to-string (:wat::core::length (:wat::rete::query fired (:rs2::q-Invoice)))))))

(:wat::core::defn :rs2::show [label <- :wat::core::String wat <- :wat::core::String clara <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": wat " wat ", clara " clara)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [order  (:rs2::Order :id 1 :part "bolt")
                    stock  (:rs2::Stock :part "bolt" :qty 10)
                    stockB (:rs2::Stock :part "bolt" :qty 7)
                    spare  (:rs2::Stock :part "washer" :qty 0)

                    s1 (:wat::rete::insert (:wat::rete::insert (:rs2::fresh) order) stock)
                    s2 (:wat::rete::retract s1 stock)
                    s3 (:wat::rete::insert s2 stock)

                    t1 (:wat::rete::insert (:wat::rete::insert (:wat::rete::insert (:rs2::fresh) order) stock) stockB)
                    t2 (:wat::rete::retract t1 stock)
                    t3 (:wat::rete::retract t2 stockB)

                    u1 (:wat::rete::insert (:wat::rete::insert (:wat::rete::insert (:rs2::fresh) order) stock) spare)
                    u2 (:wat::rete::retract u1 spare)]
    (:wat::core::do
      (:rs2::show "1 derived"                        (:rs2::counts s1) "1/1")
      (:rs2::show "2 support retracted, transitive"  (:rs2::counts s2) "0/0")
      (:rs2::show "3 re-inserted, closure returns"   (:rs2::counts s3) "1/1")
      (:rs2::show "4 two supports, one Order"        (:rs2::counts t1) "2/2")
      (:rs2::show "5 one support retracted"          (:rs2::counts t2) "1/1")
      (:rs2::show "6 both retracted"                 (:rs2::counts t3) "0/0")
      (:rs2::show "7 unrelated fact present"         (:rs2::counts u1) "1/1")
      (:rs2::show "8 unrelated fact retracted"       (:rs2::counts u2) "1/1"))))
