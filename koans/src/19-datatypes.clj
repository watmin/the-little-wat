;; Datatypes: our own filled-in koans on the topic of the Clojure Koans' nineteenth file.

(defrecord Medal [metal])

(deftype Trophy [sport])

(defprotocol Honor
  (announce [this who]))

(defrecord Gold [event]
  Honor
  (announce [this who] (str who " wins gold in " (:event this) ".")))

(deftype Bronze [event]
  Honor
  (announce [this who] (str who " takes bronze in " (.-event this) ".")))

;; a record's field, by field access
(= "gold" (.metal (Medal. "gold")))

;; a type's field
(= "golf" (.sport (Trophy. "golf")))

;; a record's field, by keyword
(= "silver" (:metal (Medal. "silver")))

;; a type is not a map, so a keyword finds nothing
(= nil (:sport (Trophy. "chess")))

;; a record is a map; a type is not
(= [true false] (map map? [(Medal. "tin") (Trophy. "darts")]))

;; a record implements a protocol
(= "Ada wins gold in chess." (announce (Gold. "chess") "Ada"))

;; and so does a type
(= "Bob takes bronze in golf." (announce (Bronze. "golf") "Bob"))
