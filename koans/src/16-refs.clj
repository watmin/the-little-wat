;; Refs: our own filled-in koans on the topic of the Clojure Koans' sixteenth file.

(def planet (ref "earth"))

(def moons (ref {}))

;; deref reads a ref
(= "earth" (deref planet))

;; @ is deref
(= "earth" @planet)

;; ref-set, inside a transaction
(= "mars" (do (dosync (ref-set planet "mars")) @planet))

;; alter applies a function, inside a transaction
(= "mars!!" (let [bang (fn [x] (str x "!"))] (dosync (ref-set planet "mars") (alter planet bang) (alter planet bang)) @planet))

;; a ref can hold a number
(= 0 (do (dosync (ref-set planet 0)) @planet))

;; alter answers the new value
(= 20 (do (dosync (ref-set planet 10) (alter planet (fn [x] (* 2 x))))))

;; two refs, changed in one transaction
(= ["Luna" "Phobos"] (do (dosync (ref-set planet {}) (alter planet assoc :moon "Luna") (alter moons assoc :moon "Phobos")) [(:moon @planet) (:moon @moons)]))
