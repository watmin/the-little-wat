;; probes/rete/insert-native-vs-oracle.wat: do the two INSERT mouths agree?
;;
;; F-067 found wat's rete disagreeing with its own declared SPEC on the fire verbs. Insertion is
;; the other paired mouth — :wat::rete::insert reaches insert$native, and insert$oracle is the
;; pure-wat reference (wat/rete/oracle/insert.wat:18, :47, :53) — and nothing has asked whether
;; those two agree.
;;
;; It matters more than the fire difference would suggest: an accumulator edge case is narrow,
;; but if facts enter the network differently depending on which mouth inserted them, everything
;; downstream inherits it. A clean result here bounds F-067 to the fire path, which is worth
;; knowing precisely.
;;
;; The same session is built four ways — native/oracle insert crossed with native/oracle fire —
;; and every combination should give the same conclusions. Where they differ, the difference is
;; attributable to the mouth that differs.
;;
;; Run from the repository root: wat probes/rete/insert-native-vs-oracle.wat

(:wat::core::defrecord :iv::Order     [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :iv::Stock     [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :iv::Hold      [id <- :wat::core::i64])
(:wat::core::defrecord :iv::Shippable [id <- :wat::core::i64 part <- :wat::core::String])
(:wat::core::defrecord :iv::Invoice   [id <- :wat::core::i64])

(:wat::rete::defrule :iv::shippable
  :when [(:iv::Order (?id <- :id) (?part <- :part))
         (:iv::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:iv::Shippable :id ?id :part ?part)])

;; a negation over a derived fact, so the comparison covers the stratified path too
(:wat::rete::defrule :iv::invoice
  :when [(:iv::Shippable (?id <- :id))
         (:wat::rete::not (:iv::Hold (?id <- :id)))]
  :then [(:iv::Invoice :id ?id)])

(:wat::rete::defquery :iv::q-Shippable :params [] :when [(?f <- :iv::Shippable)])
(:wat::rete::defquery :iv::q-Invoice   :params [] :when [(?f <- :iv::Invoice)])

(:wat::core::defn :iv::facts [] -> (:wat::core::PersistentVector :- [:wat::core::Record])
  (:wat::core::PersistentVector :- [:wat::core::Record]
    (:iv::Order :id 1 :part "bolt")
    (:iv::Order :id 2 :part "nut")
    (:iv::Order :id 3 :part "washer")
    (:iv::Stock :part "bolt" :qty 10)
    (:iv::Stock :part "nut" :qty 5)
    (:iv::Stock :part "washer" :qty 0)
    (:iv::Hold :id 2)))

(:wat::core::defn :iv::empty [] -> :wat::rete::Session
  (:wat::rete::compile-all (:wat::rete::collect-rules :iv)
    (:wat::core::PersistentVector (:iv::q-Shippable) (:iv::q-Invoice))))

(:wat::core::defn :iv::by-native [] -> :wat::rete::Session
  (:wat::rete::insert-all (:iv::empty) (:iv::facts)))

(:wat::core::defn :iv::by-oracle [] -> :wat::rete::Session
  (:wat::rete::insert-all$oracle (:iv::empty) (:iv::facts)))

(:wat::core::defn :iv::shape [s <- :wat::rete::Session] -> :wat::core::String
  (:wat::string::concat
    (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:iv::q-Shippable)))) "/"
    (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:iv::q-Invoice))))))

(:wat::core::defn :iv::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [nn (:iv::shape (:wat::rete::fire-rules        (:iv::by-native)))
                    no (:iv::shape (:wat::rete::fire-rules$oracle (:iv::by-native)))
                    on (:iv::shape (:wat::rete::fire-rules        (:iv::by-oracle)))
                    oo (:iv::shape (:wat::rete::fire-rules$oracle (:iv::by-oracle)))
                    fn-count (:wat::core::length (:wat::rete::Session/facts (:iv::by-native)))
                    fo-count (:wat::core::length (:wat::rete::Session/facts (:iv::by-oracle)))]
    (:wat::core::do
      (:iv::show "facts after insert-all        (native)" (:wat::i64::to-string fn-count))
      (:iv::show "facts after insert-all$oracle        " (:wat::i64::to-string fo-count))
      (:iv::show "insert native + fire native   shippable/invoice" nn)
      (:iv::show "insert native + fire SPEC     shippable/invoice" no)
      (:iv::show "insert SPEC   + fire native   shippable/invoice" on)
      (:iv::show "insert SPEC   + fire SPEC     shippable/invoice" oo)
      (:iv::show "the two insert mouths agree"
                 (:wat::core::if (:wat::core::= fn-count fo-count) "true" "FALSE"))
      (:iv::show "insert mouth changes the conclusions"
                 (:wat::core::if (:wat::core::= nn on) "no" "YES")))))
