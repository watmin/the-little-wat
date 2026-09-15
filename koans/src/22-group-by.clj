;; Group-by: our own filled-in koans on the topic of the Clojure Koans' twenty-second file.

(defn odds-and-evens [coll] (let [{odds true evens false} (group-by odd? coll)] [odds evens]))

;; group words by length
(= {5 ["hello" "world"] 3 ["fig" "zap"]} (group-by count ["hello" "world" "fig" "zap"]))

;; split odd from even, three ways
(= (odds-and-evens [1 2 3 4 5]) ((juxt filter remove) odd? [1 2 3 4 5]) [[1 3 5] [2 4]])

;; group maps by a key
(= {1 [{:id 1 :name "Ada"} {:id 1 :last "Byron"}] 2 [{:id 2 :name "Bob"}]} (group-by :id [{:id 1 :name "Ada"} {:id 2 :name "Bob"} {:id 1 :last "Byron"}]))

;; a missing key groups under nil
(= {"Ada" [{:id 1 :name "Ada"}] "Bob" [{:id 2 :name "Bob"}] nil [{:id 1 :last "Byron"}]} (group-by :name [{:id 1 :name "Ada"} {:id 2 :name "Bob"} {:id 1 :last "Byron"}]))

;; group by a computed value
(= {:late [{:name "Cy" :late true} {:name "Di" :late true}] :early [{:name "Ed" :late false}]} (group-by #(if (:late %) :late :early) [{:name "Cy" :late true} {:name "Ed" :late false} {:name "Di" :late true}]))
