;; Metadata: our own filled-in koans on the topic of the Clojure Koans' twenty-third file.

(def team (with-meta 'Gulls {:league "Coastal"}))

;; metadata on a symbol
(= {:league "Coastal"} (meta team))

;; metadata by reader syntax
(= {:division "North"} (meta '^{:division "North"} Gulls))

;; a number can't carry metadata
(= "no metadata" (try (with-meta 7 {:prime true}) (catch ClassCastException e "no metadata")))

;; merge keeps the first map's metadata
(= {:foo :bar} (meta (merge '^{:foo :bar} {:a 1 :b 2} {:b 3 :c 4})))

;; and not the second's
(= nil (meta (merge {:a 1 :b 2} '^{:foo :bar} {:b 3 :c 4})))

;; a type hint is metadata too
(= \C (#(.charAt ^String % 0) "Cast me"))

;; an atom in metadata can change
(= 8 (let [t (with-meta 'Gulls {:titles (atom 7)})] (swap! (:titles (meta t)) inc) @(:titles (meta t))))

;; vary-meta changes metadata
(= {:league "Coastal" :ground "Pier Park"} (meta (vary-meta team assoc :ground "Pier Park")))

;; metadata takes no part in equality
(= 'Gulls (vary-meta team dissoc :league))

;; nor in printing
(= "Gulls" (pr-str (vary-meta team dissoc :league)))
