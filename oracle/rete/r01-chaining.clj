;; oracle/rete/r01-chaining.clj: the expected results for rete/r01-chaining.wat.
;;
;; Our own rules on clara-rules, a forward-chaining engine in the same family as wat's rete.
;; Nobody's code is ported here — the same problem is given to both engines and their answers
;; compared.
;;
;; The problem is a small supply chain, chosen because it exercises the four things a rete is
;; for, and because each one builds on the last:
;;
;;   join        an Order and a Stock line for the same part
;;   chaining    a derived Shippable feeds the rule that derives Invoice — forward chaining,
;;               which is the whole point of a rete and the thing a single pass would miss
;;   negation    an order with no Hold on it
;;   existence   a part that has at least one supplier
;;   accumulate  how many shippable orders there are
;;
;; Facts are inserted once and never retracted: clara does truth maintenance and wat's rete may
;; not, so retraction is a separate question and is deliberately not asked here.
;;
;; Results print as counts and as sorted "|"-joined strings, never as Clojure seqs, so the wat
;; side can produce the same characters.
;;
;; Every line printed after "=> " is a result the wat case must print, in order.
;;
;; Run: tools/rete-oracle.sh r01-chaining

(require '[clara.rules :refer [defrule defquery insert insert-all fire-rules query mk-session insert!]]
         '[clara.rules.accumulators :as acc]
         '[clojure.string :as str])

;; ---- facts

(defrecord Order    [id part])
(defrecord Stock    [part qty])
(defrecord Hold     [id])
(defrecord Supplier [part name])

;; ---- derived

(defrecord Shippable [id part])
(defrecord Invoice   [id])
(defrecord Sourced   [part])
(defrecord Tally     [n])

;; ---- rules

;; join: an order whose part is in stock
(defrule shippable
  [Order (= ?id id) (= ?part part)]
  [Stock (= ?part part) (> qty 0)]
  =>
  (insert! (->Shippable ?id ?part)))

;; chaining + negation: a shippable order with no hold on it becomes an invoice.
;; Shippable is DERIVED, so this rule only fires if the engine feeds derived facts back in.
(defrule invoice
  [Shippable (= ?id id)]
  [:not [Hold (= ?id id)]]
  =>
  (insert! (->Invoice ?id)))

;; existence: a part with at least one supplier
(defrule sourced
  [Stock (= ?part part)]
  [:exists [Supplier (= ?part part)]]
  =>
  (insert! (->Sourced ?part)))

;; accumulate over a derived fact
(defrule tally
  [?n <- (acc/count) :from [Shippable]]
  =>
  (insert! (->Tally ?n)))

;; ---- queries

(defquery q-shippable [] [Shippable (= ?id id) (= ?part part)])
(defquery q-invoice   [] [Invoice   (= ?id id)])
(defquery q-sourced   [] [Sourced   (= ?part part)])
(defquery q-tally     [] [Tally     (= ?n n)])

;; ---- the facts

(def facts
  [(->Order 1 "bolt")
   (->Order 2 "nut")
   (->Order 3 "washer")
   (->Stock "bolt" 10)
   (->Stock "nut" 5)
   (->Stock "washer" 0)      ;; out of stock: order 3 is not shippable
   (->Hold 2)                ;; order 2 is held: shippable but not invoiced
   (->Supplier "bolt" "acme")
   (->Supplier "bolt" "globex")])   ;; two suppliers, one Sourced — exists, not a join

(defn say [x] (println "=>" x))

(defn joined [xs] (str/join "|" (sort xs)))

(let [s (-> (mk-session [shippable invoice sourced tally
                         q-shippable q-invoice q-sourced q-tally])
            (insert-all facts)
            (fire-rules))
      shippables (query s q-shippable)
      invoices   (query s q-invoice)
      sourceds   (query s q-sourced)
      tallies    (query s q-tally)]
  ;; the join
  (say (count shippables))
  (say (joined (map #(str (:?id %) ":" (:?part %)) shippables)))
  ;; the chain, through a derived fact, with a negation on it
  (say (count invoices))
  (say (joined (map #(str (:?id %)) invoices)))
  ;; existence: two suppliers for bolt, but Sourced once
  (say (count sourceds))
  (say (joined (map :?part sourceds)))
  ;; accumulation over a derived fact
  (say (count tallies))
  (say (joined (map #(str (:?n %)) tallies))))
