;; wat's rete, against clara-rules on the same problem: a small supply chain.
;;
;; wat ships a rete — defrule, defquery, insert, fire-rules, a Session with alpha, beta and
;; production memories, negation, existence and nine accumulators — and no suite here had ever
;; touched it. Nor has anything else: `\brete\b`, `:wat::rete::` and `defrule` appear ZERO times
;; in USER-GUIDE.md, WAT-CHEATSHEET.md, CLOJURE-ROSETTA.md and the docs README (F-065).
;;
;; The rules are ours, written twice — here, and in Clojure on clara-rules
;; (oracle/rete/r01-chaining.clj, run by tools/rete-oracle.sh). Nobody's code is ported; the same
;; problem goes to both engines and the answers must agree.
;;
;; Four things, each building on the last:
;;   join        an Order and a Stock line for the same part
;;   chaining    the derived Shippable feeds the rule deriving Invoice — forward chaining, which
;;               is the whole point of a rete and what a single pass would miss
;;   negation    an order with no Hold on it, over a DERIVED fact
;;   existence   a part with at least one supplier: two suppliers, one Sourced
;;   accumulate  how many shippable orders there are
;;
;; Facts are inserted and never retracted: clara does truth maintenance and wat may differ, so
;; retraction is a separate question and is not asked here.
;;
;; Run from the repository root (it reads the expected file by path):
;;   wat rete/r01-chaining.wat

(:wat::load-file! "lib/check.wat")

;; ---- facts

(:wat::core::defrecord :sc::Order    [id <- :wat::core::i64     part <- :wat::core::String])
(:wat::core::defrecord :sc::Stock    [part <- :wat::core::String qty <- :wat::core::i64])
(:wat::core::defrecord :sc::Hold     [id <- :wat::core::i64])
(:wat::core::defrecord :sc::Supplier [part <- :wat::core::String name <- :wat::core::String])

;; ---- derived

(:wat::core::defrecord :sc::Shippable [id <- :wat::core::i64 part <- :wat::core::String])
(:wat::core::defrecord :sc::Invoice   [id <- :wat::core::i64])
(:wat::core::defrecord :sc::Sourced   [part <- :wat::core::String])
(:wat::core::defrecord :sc::Tally     [n <- :wat::core::i64])

;; ---- rules

;; join: an order whose part is in stock
(:wat::rete::defrule :sc::shippable
  :when
  [(:sc::Order (?id <- :id) (?part <- :part))
   (:sc::Stock (?part <- :part) (?qty <- :qty))
   (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then
  [(:sc::Shippable :id ?id :part ?part)])

;; chaining + negation over a DERIVED fact: a shippable order with no hold becomes an invoice.
;; This fires only if the engine feeds what it derived back into the network.
(:wat::rete::defrule :sc::invoice
  :when
  [(:sc::Shippable (?id <- :id))
   (:wat::rete::not (:sc::Hold (?id <- :id)))]
  :then
  [(:sc::Invoice :id ?id)])

;; existence: a part with at least one supplier — two suppliers must still derive one Sourced
(:wat::rete::defrule :sc::sourced
  :when
  [(:sc::Stock (?part <- :part))
   (:wat::rete::exists (:sc::Supplier (?part <- :part)))]
  :then
  [(:sc::Sourced :part ?part)])

;; accumulate over a derived fact
(:wat::rete::defrule :sc::tally
  :when
  [(?n <- (:wat::rete::acc::count) :from (:sc::Shippable))]
  :then
  [(:sc::Tally :n ?n)])

;; ---- queries

(:wat::rete::defquery :sc::q-Shippable :params [] :when [(?f <- :sc::Shippable)])
(:wat::rete::defquery :sc::q-Invoice   :params [] :when [(?f <- :sc::Invoice)])
(:wat::rete::defquery :sc::q-Sourced   :params [] :when [(?f <- :sc::Sourced)])
(:wat::rete::defquery :sc::q-Tally     :params [] :when [(?f <- :sc::Tally)])

;; ---- the session

(:wat::core::defn :sc::queries [] -> (:wat::core::PersistentVector :- [:wat::rete::Query])
  (:wat::core::PersistentVector
    (:sc::q-Shippable) (:sc::q-Invoice) (:sc::q-Sourced) (:sc::q-Tally)))

;; the facts, inserted once. washer is out of stock; order 2 is held; bolt has two suppliers.
(:wat::core::defn :sc::seed [s <- :wat::rete::Session] -> :wat::rete::Session
  (:wat::rete::insert-all s
    (:wat::core::PersistentVector :- [:wat::core::Record]
      (:sc::Order :id 1 :part "bolt")
      (:sc::Order :id 2 :part "nut")
      (:sc::Order :id 3 :part "washer")
      (:sc::Stock :part "bolt" :qty 10)
      (:sc::Stock :part "nut" :qty 5)
      (:sc::Stock :part "washer" :qty 0)
      (:sc::Hold :id 2)
      (:sc::Supplier :part "bolt" :name "acme")
      (:sc::Supplier :part "bolt" :name "globex"))))

(:wat::core::defn :sc::fired [] -> :wat::rete::Session
  (:wat::rete::fire-rules
    (:sc::seed (:wat::rete::compile-all (:wat::rete::collect-rules :sc) (:sc::queries)))))

;; ---- reading the answers back

(:wat::core::typealias :sc::Rows (:wat::core::PersistentVector :- [:wat::core::PersistentMap]))

(:wat::core::defn :sc::count-of [rows <- :sc::Rows] -> :wat::core::String
  (:wat::i64::to-string (:wat::core::length rows)))

;; a query row is a map of binding name to value; ?f is the whole fact
(:wat::core::defn :sc::shippable-key [r <- :wat::core::PersistentMap] -> :wat::core::String
  (:wat::core::match (:wat::map::get r "?f")
    [:wat::core::Option.Some {:value f}
      (:wat::string::concat (:wat::i64::to-string (:sc::Shippable/id f)) ":" (:sc::Shippable/part f))]
    [:wat::core::Option.None {} "?"]))

(:wat::core::defn :sc::invoice-key [r <- :wat::core::PersistentMap] -> :wat::core::String
  (:wat::core::match (:wat::map::get r "?f")
    [:wat::core::Option.Some {:value f} (:wat::i64::to-string (:sc::Invoice/id f))]
    [:wat::core::Option.None {} "?"]))

(:wat::core::defn :sc::sourced-key [r <- :wat::core::PersistentMap] -> :wat::core::String
  (:wat::core::match (:wat::map::get r "?f")
    [:wat::core::Option.Some {:value f} (:sc::Sourced/part f)]
    [:wat::core::Option.None {} "?"]))

(:wat::core::defn :sc::tally-key [r <- :wat::core::PersistentMap] -> :wat::core::String
  (:wat::core::match (:wat::map::get r "?f")
    [:wat::core::Option.Some {:value f} (:wat::i64::to-string (:sc::Tally/n f))]
    [:wat::core::Option.None {} "?"]))

(:wat::core::defn :sc::keys-of [rows <- :sc::Rows f <- [:wat::core::PersistentMap :-> :wat::core::String]] -> :wat::core::String
  (:rete::sorted-join
    (:wat::core::foldl
      (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::core::String]) r <- :wat::core::PersistentMap]
        -> (:wat::core::Vector :- [:wat::core::String])
        (:wat::core::conj acc (f r)))
      (:wat::core::Vector :- [:wat::core::String])
      rows)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s          (:sc::fired)
                    shippables (:wat::rete::query s (:sc::q-Shippable))
                    invoices   (:wat::rete::query s (:sc::q-Invoice))
                    sourceds   (:wat::rete::query s (:sc::q-Sourced))
                    tallies    (:wat::rete::query s (:sc::q-Tally))]
    (:rete::check-results "oracle/rete/r01-chaining.expected"
                          "rete r01 chaining"
                          (:wat::core::Vector :- [:wat::core::String]
                            ;; the join
                            (:sc::count-of shippables)
                            (:sc::keys-of shippables :sc::shippable-key)
                            ;; the chain, through a derived fact, with a negation on it
                            (:sc::count-of invoices)
                            (:sc::keys-of invoices :sc::invoice-key)
                            ;; existence: two suppliers for bolt, one Sourced
                            (:sc::count-of sourceds)
                            (:sc::keys-of sourceds :sc::sourced-key)
                            ;; accumulation over a derived fact
                            (:sc::count-of tallies)
                            (:sc::keys-of tallies :sc::tally-key)))))
