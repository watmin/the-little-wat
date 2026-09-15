;; oracle/mk.clj: the book's ch 10 miniKanren, transliterated to Clojure. A differential
;; oracle for the wat port: which answers come out, and in what ORDER, depends only on the
;; algorithm (unify, append-inf, append-map-inf, defrel's suspension), so both
;; implementations must print the same thing for the same query. Our own code.
;;
;; Terms: atoms are Clojure values; () is the empty list; a Pair is a cons cell, so a list
;; can end in a variable. Output prints an improper tail as (a b & d), as the wat port does.
;;
;; Use: (load-file "oracle/mk.clj") then (in-ns 'mk), from a query file.

(ns mk (:refer-clojure :exclude [== reify]))

(defrecord LVar [id])
(defrecord Pair [a d])

(def counter (atom 0))
(defn lvar [] (->LVar (swap! counter inc)))
(defn lvar? [x] (instance? LVar x))
(defn pair? [x] (instance? Pair x))

;; ---- building terms from quoted data
;; quo: quoted data as a term. (Not q: queries name their variable q.)
(defn quo [x] (if (seq? x) (if (empty? x) () (->Pair (quo (first x)) (quo (rest x)))) x))
(defn kons [a d] (->Pair a d))
(defn lst* [xs d] (reduce (fn [acc a] (->Pair a acc)) d (reverse xs)))
(defn lst [& xs] (lst* xs ()))

;; ---- substitution
(defn walk [v s] (if (lvar? v) (if-let [e (find s v)] (recur (val e) s) v) v))

(defn occurs? [x v s]
  (let [v (walk v s)]
    (cond (lvar? v) (= v x)
          (pair? v) (or (occurs? x (:a v) s) (occurs? x (:d v) s))
          :else false)))

(defn ext-s [x v s] (if (occurs? x v s) nil (assoc s x v)))

(defn unify [u v s]
  (let [u (walk u s) v (walk v s)]
    (cond (and (lvar? u) (lvar? v) (= u v)) s
          (lvar? u) (ext-s u v s)
          (lvar? v) (ext-s v u s)
          (and (pair? u) (pair? v)) (when-let [s (unify (:a u) (:a v) s)] (unify (:d u) (:d v) s))
          :else (when (= u v) s))))

;; ---- streams: nil (empty), [answer rest] (mature), or a fn of no args (a suspension)
(defn append-inf [s t]
  (cond (nil? s) t
        (vector? s) [(first s) (append-inf (second s) t)]
        :else (fn [] (append-inf t (s)))))

(defn append-map-inf [g s]
  (cond (nil? s) nil
        (vector? s) (append-inf (g (first s)) (append-map-inf g (second s)))
        :else (fn [] (append-map-inf g (s)))))

(defn take-inf [n s]
  (loop [n n s s acc []]
    (cond (and n (zero? n)) acc
          (nil? s) acc
          (vector? s) (recur (and n (dec n)) (second s) (conj acc (first s)))
          :else (recur n (s) acc))))

;; ---- goals
(defn == [u v] (fn [s] (if-let [s (unify u v s)] [s nil] nil)))
(def succeed (fn [s] [s nil]))
(def fail (fn [_] nil))
(defn disj2 [g1 g2] (fn [s] (append-inf (g1 s) (g2 s))))
(defn conj2 [g1 g2] (fn [s] (append-map-inf g2 (g1 s))))

(defmacro disj* [& gs]
  (case (count gs) 0 `fail 1 (first gs) `(disj2 ~(first gs) (disj* ~@(rest gs)))))
(defmacro conj* [& gs]
  (case (count gs) 0 `succeed 1 (first gs) `(conj2 ~(first gs) (conj* ~@(rest gs)))))

(defmacro defrel [[name & args] & gs]
  `(defn ~name [~@args] (fn [s#] (fn [] ((conj* ~@gs) s#)))))

(defn call-fresh [f] (f (lvar)))
(defmacro fresh [vars & gs]
  (if (empty? vars)
    `(conj* ~@gs)
    `(call-fresh (fn [~(first vars)] (fresh ~(rest vars) ~@gs)))))

(defmacro conde [& lines] `(disj* ~@(map (fn [l] `(conj* ~@l)) lines)))

;; ---- reification
(defn walk* [v s]
  (let [v (walk v s)]
    (if (pair? v) (->Pair (walk* (:a v) s) (walk* (:d v) s)) v)))

(defn reify-s [v r]
  (let [v (walk v r)]
    (cond (lvar? v) (assoc r v (symbol (str "_" (count r))))
          (pair? v) (reify-s (:d v) (reify-s (:a v) r))
          :else r)))

(defn out [t]
  (if (pair? t)
    (loop [acc [] t t]
      (cond (pair? t) (recur (conj acc (out (:a t))) (:d t))
            (= t ()) (apply list acc)
            :else (apply list (conj acc '& (out t)))))
    t))

(defn reify [v] (fn [s] (let [v (walk* v s)] (out (walk* v (reify-s v {}))))))

(defn run-goal [n q g] (apply list (map (reify q) (take-inf n (g {})))))

(defmacro run [n q & gs]
  (if (seq? q)
    (let [qq (gensym "q")]
      `(run ~n ~qq (fresh ~q (== (lst ~@q) ~qq) ~@gs)))
    `(let [~q (lvar)] (run-goal ~n ~q (conj* ~@gs)))))

(defmacro run* [q & gs] `(run nil ~q ~@gs))

;; Print each query's answers on its own line, labelled, for comparison with the wat port.
(defmacro show [label form] `(println ~label (pr-str ~form)))
