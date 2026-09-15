;; Conditionals: our own filled-in koans on the topic of the Clojure Koans' eighth file.

(defn speed [way]
  (case way
    :cycling "fast"
    :running "brisk"
    :walking "slow"
    "no way"))

;; if picks a branch
(= :yes (if (false? (= 1 2)) :yes :no))

;; if with no else, taken
(= [] (if (> 5 3) []))

;; if with no else, not taken, gives nil
(= nil (if (< 5 3) :yes))

;; zero is not nil
(= nil (if (nil? 0) :yes))

;; an empty list is empty
(= :glory (if (not (empty? ())) :doom :glory))

;; cond tries each test in order
(= :third (let [x 7] (cond (= x 5) :first (= x 6) :second :else :third)))

;; if-not
(= 'doom (if-not (zero? 1) 'doom 'more-doom))

;; case on a keyword
(= "fast" (speed :cycling))

;; case, with a default
(= "no way" (speed :sleeping))
