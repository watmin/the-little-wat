;; Java interop: our own filled-in koans on the topic of the Clojure Koans' twentieth file. wat is
;; not hosted on the JVM; these rows ask what stands in for each.

;; the class of a string
(= java.lang.String (class "fig"))

;; call a method on a string
(= "SELECT * FROM" (.toUpperCase "select * from"))

;; a method, wrapped as a function
(= ["FIG" "PLUM"] (map (fn [s] (.toUpperCase s)) ["fig" "plum"]))

;; construct an object, and ask it
(= 3 (let [latch (java.util.concurrent.CountDownLatch. 3)] (.getCount latch)))

;; a static method
(== 1024 (Math/pow 2 10))
