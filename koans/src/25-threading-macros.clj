;; Threading macros: our own filled-in koans on the topic of the Clojure Koans' twenty-fifth file.

(def nums '(1 2 3 4 5))

(def rows-of-maps '({:n 1} {:n 2} {:n 3}))

(defn n-of-map [m a b] (get m :n))

(defn ns-of-coll [a b coll] (map :n coll))

;; thread first
(= {:n 1} (-> {} (assoc :n 1)))

;; through strings
(= "fig, and plum, and pear" (-> "fig" (str ", and plum") (str ", and pear")))

;; a bare function in the thread
(= "padded" (-> " padded " clojure.string/trim))

;; deeper, with update-in and get-in
(= 6 (-> {} (assoc :a 1) (assoc :c {:d 4 :e 5}) (update-in [:c :e] inc) (get-in [:c :e])))

;; the value goes in first
(= 1 (-> {} (assoc :n 1) (n-of-map "x" "y")))

;; thread last
(= '(2 3 4) (->> [1 2 3] (map inc)))

;; a longer thread last
(= 12 (->> nums (map inc) (filter even?) (into []) (reduce +)))

;; the value goes in last
(= [1 2 3] (->> rows-of-maps (ns-of-coll "x" "y") (into [])))
