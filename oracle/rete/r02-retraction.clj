;; oracle/rete/r02-retraction.clj: the expected results for rete/r02-retraction.wat.
;;
;; Our own rules on clara-rules. r01 inserted facts and never took them away; this asks the
;; question it left open — when a fact goes, what happens to what was derived from it?
;;
;; The two engines answer it by different mechanisms, which is why the comparison is worth
;; making. clara tracks dependencies: retracting a fact retracts what it supported. wat
;; recomputes: "retract-then-fire recomputes the full closure from the reduced input, so
;; consequences vanish transitively" (wat/rete/oracle/fire.wat:360). Same answer expected, by
;; different roads.
;;
;; Four questions, each harder than the last:
;;
;;   1. retract a base fact — does the fact derived from it go?
;;   2. transitively — Stock feeds Shippable, Shippable feeds Invoice. Retract the Stock and
;;      BOTH derived layers should go, not just the first.
;;   3. with support left over — two Stock lines for one part. Retract one; the Shippable still
;;      has support and must STAY.
;;   4. re-insert — put the fact back and the closure must come back.
;;
;; Every line printed after "=> " is a result the wat case must print, in order.
;;
;; Run: tools/rete-oracle.sh r02-retraction

(require '[clara.rules :refer [defrule defquery insert insert-all fire-rules query mk-session
                               insert! retract]]
         '[clojure.string :as str])

;; ---- facts

(defrecord Order [id part])
(defrecord Stock [part qty])

;; ---- derived

(defrecord Shippable [id part])
(defrecord Invoice   [id])

;; ---- rules: Order + Stock -> Shippable -> Invoice

(defrule shippable
  [Order (= ?id id) (= ?part part)]
  [Stock (= ?part part) (> qty 0)]
  =>
  (insert! (->Shippable ?id ?part)))

;; the second layer: a derived fact deriving another
(defrule invoice
  [Shippable (= ?id id)]
  =>
  (insert! (->Invoice ?id)))

(defquery q-shippable [] [Shippable (= ?id id)])
(defquery q-invoice   [] [Invoice   (= ?id id)])

(defn counts [s]
  (str (count (query s q-shippable)) "/" (count (query s q-invoice))))

(defn say [x] (println "=>" x))

;; ---- 1 and 2: retract the base fact, transitively

(let [order (->Order 1 "bolt")
      stock (->Stock "bolt" 10)
      s1 (-> (mk-session [shippable invoice q-shippable q-invoice])
             (insert order stock)
             (fire-rules))]
  ;; both layers derived
  (say (counts s1))
  ;; retract the Stock: Shippable loses its support, and Invoice was derived FROM Shippable,
  ;; so both must go
  (let [s2 (-> s1 (retract stock) (fire-rules))]
    (say (counts s2))
    ;; 4: put it back, and the whole closure returns
    (let [s3 (-> s2 (insert stock) (fire-rules))]
      (say (counts s3)))))

;; ---- 3: support left over

(let [order  (->Order 1 "bolt")
      stockA (->Stock "bolt" 10)
      stockB (->Stock "bolt" 7)
      s1 (-> (mk-session [shippable invoice q-shippable q-invoice])
             (insert order stockA stockB)
             (fire-rules))]
  ;; two Stock lines match the one Order, so the rule fires twice. MEASURED: clara does NOT
  ;; dedupe the identical derived fact — it answers 2/2, one derivation each. (I had guessed it
  ;; would collapse them; the run said otherwise, and the guess is recorded here because wat
  ;; recomputes its closure from the reduced input and may well answer 1/1.)
  (say (counts s1))
  ;; retract one of the two: the other still supports the Shippable, which must STAY
  (let [s2 (-> s1 (retract stockA) (fire-rules))]
    (say (counts s2)))
  ;; retract both: now nothing supports it
  (let [s3 (-> s1 (retract stockA) (retract stockB) (fire-rules))]
    (say (counts s3))))

;; ---- retracting something nothing was derived from

(let [order (->Order 1 "bolt")
      stock (->Stock "bolt" 10)
      spare (->Stock "washer" 0)
      s1 (-> (mk-session [shippable invoice q-shippable q-invoice])
             (insert order stock spare)
             (fire-rules))]
  (say (counts s1))
  (let [s2 (-> s1 (retract spare) (fire-rules))]
    (say (counts s2))))
