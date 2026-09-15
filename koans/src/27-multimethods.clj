;; Multimethods: our own filled-in koans on the topic of the Clojure Koans' twenty-seventh file.

(defmulti describe (fn [k] k))

(defmethod describe :sun [_] "hot and bright")

(defmethod describe :moon [_] "cold and pale")

(defmulti handle (fn [kind opts] kind))

(defmethod handle :pick [_ opts] (:chosen opts))

(defmethod handle :total [_ opts] (->> (:items opts) (map inc) (reduce +)))

;; dispatch on the argument itself
(= "hot and bright" (describe :sun))

;; on another value
(= "cold and pale" (describe :moon))

;; dispatch on one of two arguments
(= 7 (handle :pick {:chosen 7 :items [1 2]}))

;; a method that computes
(= 9 (handle :total {:chosen 7 :items [1 2 3]}))
