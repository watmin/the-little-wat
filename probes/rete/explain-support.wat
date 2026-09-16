;; probes/rete/explain-support.wat: can wat's rete say WHY it concluded something?
;;
;; :wat::rete::fire-rules-explain is the one public fire verb no case here has used. It answers
;; an :wat::rete::Explained — a record of [session, support] where support is a PersistentMap —
;; backed by a DerivationNode provenance tree in which (wat/rete.wat:245):
;;
;;   fact: the derived (or base) fact this node represents
;;   rule: Some(rule-name) for a derived fact; None for a base/asserted leaf
;;   via:  one DerivationStep per supporting fact. Empty <=> base fact; non-empty <=> derived.
;;
;; An engine that can explain its own conclusions is a real capability, and it is one more thing
;; nothing tells a user about (F-065). This asks the smallest questions: does the verb run, does
;; the session inside the Explained hold the same conclusions as a plain fire, and is the
;; support map non-empty — i.e. is there provenance to read at all?
;;
;; Run from the repository root: wat probes/rete/explain-support.wat

(:wat::core::defrecord :ex::Order [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :ex::Stock [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :ex::Shippable [id <- :wat::core::i64 part <- :wat::core::String])
(:wat::core::defrecord :ex::Invoice   [id <- :wat::core::i64])

;; two layers, so the provenance tree has a derived fact supporting a derived fact
(:wat::rete::defrule :ex::shippable
  :when [(:ex::Order (?id <- :id) (?part <- :part))
         (:ex::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:ex::Shippable :id ?id :part ?part)])

(:wat::rete::defrule :ex::invoice
  :when [(:ex::Shippable (?id <- :id))]
  :then [(:ex::Invoice :id ?id)])

(:wat::rete::defquery :ex::q-Shippable :params [] :when [(?f <- :ex::Shippable)])
(:wat::rete::defquery :ex::q-Invoice   :params [] :when [(?f <- :ex::Invoice)])

(:wat::core::defn :ex::seeded [] -> :wat::rete::Session
  (:wat::rete::insert-all
    (:wat::rete::compile-all (:wat::rete::collect-rules :ex)
      (:wat::core::PersistentVector (:ex::q-Shippable) (:ex::q-Invoice)))
    (:wat::core::PersistentVector :- [:wat::core::Record]
      (:ex::Order :id 1 :part "bolt")
      (:ex::Stock :part "bolt" :qty 10))))

(:wat::core::defn :ex::shape [s <- :wat::rete::Session] -> :wat::core::String
  (:wat::string::concat
    (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:ex::q-Shippable)))) "/"
    (:wat::i64::to-string (:wat::core::length (:wat::rete::query s (:ex::q-Invoice))))))

(:wat::core::defn :ex::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [plain     (:wat::rete::fire-rules (:ex::seeded))
                    explained (:wat::rete::fire-rules-explain (:ex::seeded))
                    ex-sess   (:wat::rete::Explained/session explained)
                    support   (:wat::rete::Explained/support explained)]
    (:wat::core::do
      (:ex::show "plain fire     shippable/invoice" (:ex::shape plain))
      (:ex::show "explained fire shippable/invoice" (:ex::shape ex-sess))
      (:ex::show "same conclusions"
                 (:wat::core::if (:wat::core::= (:ex::shape plain) (:ex::shape ex-sess)) "true" "FALSE"))
      ;; is there provenance to read at all?
      (:ex::show "support entries" (:wat::i64::to-string (:wat::map::length support)))
      (:ex::show "support is empty?"
                 (:wat::core::if (:wat::core::= (:wat::map::length support) 0) "yes — nothing to read" "no")))))
