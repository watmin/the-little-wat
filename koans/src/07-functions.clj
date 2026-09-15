;; Functions: our own filled-in koans on the topic of the Clojure Koans' seventh file.

(defn triple [n] (* 3 n))

(defn cube [n] (* n n n))

;; call a defined function
(= 27 (cube 3))

;; and another
(= 12 (triple 4))

;; an anonymous function
(= 14 ((fn [n] (* 7 n)) 2))

;; the short form of an anonymous function
(= 30 (#(* 10 %) 3))

;; with numbered arguments
(= 12 (#(+ %1 %2 %3) 3 4 5))

;; an argument may go unused
(= "xxz" (#(str "xx" %2) "y" "z"))

;; a function that returns a function
(= 20 (((fn [] *)) 4 5))

;; a function passed as an argument
(= 9 ((fn [f] (f 4 5)) +))

;; a function that is given a function, and calls it
(= 16 ((fn [f] (f 4)) (fn [n] (* n n))))

;; a defined function, passed along
(= 64 ((fn [f] (f 4)) cube))
