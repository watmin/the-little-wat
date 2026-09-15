;; Destructuring: our own filled-in koans on the topic of the Clojure Koans' fifteenth file.

(def address {:street "9 Elm Row" :city "Leith" :country "UK"})

;; destructure a vector argument
(= "ba" ((fn [[a b]] (str b a)) ["a" "b"]))

;; three at once
(= "x, y and z" ((fn [[a b c]] (str a ", " b " and " c)) ["x" "y" "z"]))

;; the rest, with &
(= "Ada Lovelace: Countess, Analyst" (let [[first-name last-name & titles] (list "Ada" "Lovelace" "Countess" "Analyst")] (str first-name " " last-name ": " (apply str (interpose ", " titles)))))

;; the whole, with :as
(= {:whole ["Ada" "Lovelace"] :first "Ada"} (let [[f l :as whole] ["Ada" "Lovelace"]] {:whole whole :first f}))

;; a map, key by key
(= "9 Elm Row, Leith, UK" (let [{street :street city :city country :country} address] (str street ", " city ", " country)))

;; a map, with :keys
(= "9 Elm Row, Leith, UK" (let [{:keys [street city country]} address] (str street ", " city ", " country)))

;; both, in a function's arguments
(= "Ada L., 9 Elm Row, Leith, UK" ((fn [[f l] {:keys [street city country]}] (str f " " (first l) "., " street ", " city ", " country)) ["Ada" "Lovelace"] address))
