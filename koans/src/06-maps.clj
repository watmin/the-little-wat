;; Maps: our own filled-in koans on the topic of the Clojure Koans' sixth file.

;; hash-map builds a map
(= {:x 1 :y 2} (hash-map :x 1 :y 2))

;; one key, one value
(= {:x 1} (hash-map :x 1))

;; the count of a map is its number of entries
(= 3 (count {:x 1 :y 2 :z 3}))

;; get a value by its key
(= 2 (get {:x 1 :y 2} :y))

;; a map is a function of its keys
(= 1 ({:x 1 :y 2} :x))

;; a keyword is a function of maps
(= 2 (:y {:x 1 :y 2}))

;; keys need not be keywords
(= "Lyon" ({1998 "Paris" 2007 "Lyon"} 2007))

;; a missing key gives nil
(= nil (get {:x 1} :z))

;; or a default
(= :none (get {:x 1} :z :none))

;; contains? a key, even one whose value is nil
(= true (contains? {:x nil :y nil} :y))

;; or not
(= false (contains? {:x nil :y nil} :z))

;; assoc gives a new map with an entry added
(= {1 "one" 2 "two"} (assoc {1 "one"} 2 "two"))

;; dissoc gives one with an entry removed
(= {1 "one"} (dissoc {1 "one" 2 "two"} 2))

;; merge
(= {:x 1 :y 2 :z 3} (merge {:x 1 :y 2} {:z 3}))

;; merge-with combines the values of a shared key
(= {:x 1 :y 5 :z 3} (merge-with + {:x 1 :y 2} {:y 3 :z 3}))

;; the keys, sorted
(= '(1998 2007 2012) (sort (keys {2007 "Lyon" 1998 "Paris" 2012 "Nice"})))

;; the values, sorted
(= '("Lyon" "Nice" "Paris") (sort (vals {2007 "Lyon" 1998 "Paris" 2012 "Nice"})))

;; a map's entries as a seq, and back into a map
(= {:x 10 :y 20} (into {} (map (fn [[k v]] [k (* 10 v)]) {:x 1 :y 2})))
