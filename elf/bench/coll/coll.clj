;; Persistent vectors on the JVM. Size is *command-line-args*.
;; argv: workload N warm|cold plain|timed
(ns coll
  (:import [java.util Arrays]))

(defn now [] (System/nanoTime))

(defn rank [^longs a p den]
  (let [m (alength a)]
    (aget a (int (- (quot (+ (* p m) (dec den)) den) 1)))))

(defn tails [batches]
  (let [a (long-array batches)]
    (Arrays/sort a)
    (println "TAIL" (rank a 50 100) (rank a 99 100) (rank a 999 1000) (aget a (dec (alength a))))))

(defn stamp [timed i batches t0]
  (if (and timed (zero? (rem (inc i) 1000)))
    (let [t1 (now)]
      [(conj batches (- t1 t0)) t1])
    [batches t0]))

;; One owner. transient / conj! is Clojure's in-place builder; persistent!
;; only at the end, so the answer is still a persistent vector.
(defn w1-own [n timed]
  (loop [i 0 v (transient []) batches [] t0 (now)]
    (if (= i n)
      (let [v (persistent! v)]
        (println "ANSWER" (reduce + v))
        (when timed (tails batches)))
      (let [v2 (conj! v i)
            [b2 t2] (stamp timed i batches t0)]
        (recur (inc i) v2 b2 t2)))))

(defn w2-own [n timed]
  (loop [i 0 v (transient []) batches [] t0 (now)]
    (if (= i n)
      (let [v (persistent! v)]
        (println "ANSWER" (reduce + (map count v)))
        (when timed (tails batches)))
      (let [v2 (conj! v "ab")
            [b2 t2] (stamp timed i batches t0)]
        (recur (inc i) v2 b2 t2)))))

(defn w3-own [n timed]
  (loop [i 0 r (transient {:k 0}) batches [] t0 (now)]
    (if (= i n)
      (let [r (persistent! r)]
        (println "ANSWER" (:k r))
        (when timed (tails batches)))
      (let [r2 (assoc! r :k (inc i))
            [b2 t2] (stamp timed i batches t0)]
        (recur (inc i) r2 b2 t2)))))

(defn w1 [n timed]
  (loop [i 0 v [] batches [] t0 (now)]
    (if (= i n)
      (do
        (println "ANSWER" (reduce + v))
        (when timed (tails batches)))
      (let [v2 (conj v i)
            [b2 t2] (stamp timed i batches t0)]
        (recur (inc i) v2 b2 t2)))))

(defn w2 [n timed]
  (loop [i 0 v [] batches [] t0 (now)]
    (if (= i n)
      (do
        (println "ANSWER" (reduce + (map count v)))
        (when timed (tails batches)))
      (let [v2 (conj v "ab")
            [b2 t2] (stamp timed i batches t0)]
        (recur (inc i) v2 b2 t2)))))

(defn w3 [n timed]
  (loop [i 0 r {:k 0} batches [] t0 (now)]
    (if (= i n)
      (do
        (println "ANSWER" (:k r))
        (when timed (tails batches)))
      (let [r2 (assoc r :k (inc i))
            [b2 t2] (stamp timed i batches t0)]
        (recur (inc i) r2 b2 t2)))))

(defn w4 [n timed]
  (loop [i 0 v [] vs [] batches [] t0 (now)]
    (if (= i n)
      (do
        (println "ANSWER" (reduce + (map-indexed (fn [idx ver] (nth ver idx)) vs)))
        (when timed (tails batches)))
      (let [v2 (conj v i)
            vs2 (conj vs v2)
            [b2 t2] (stamp timed i batches t0)]
        (recur (inc i) v2 vs2 b2 t2)))))

(defn w5 [n timed]
  (loop [i 0 s "" batches [] t0 (now)]
    (if (= i n)
      (do
        (println "ANSWER" (count s))
        (when timed (tails batches)))
      (let [s2 (str s "a")
            [b2 t2] (stamp timed i batches t0)]
        (recur (inc i) s2 b2 t2)))))

(defn -main [& [which n-str warm timed]]
  (let [n (Long/parseLong n-str)
        own (= (last *command-line-args*) "own")
        run (fn [timed?]
              (case which
                "w1" (if own (w1-own n timed?) (w1 n timed?))
                "w2" (if own (w2-own n timed?) (w2 n timed?))
                "w3" (if own (w3-own n timed?) (w3 n timed?))
                "w4" (w4 n timed?)
                "w5" (w5 n timed?)))]
    (when (= warm "warm") (run false))
    (run (= timed "timed"))))
