;; Runtime polymorphism: our own filled-in koans on the topic of the Clojure Koans' tenth file.

(defn greet
  ([] "Hello!")
  ([a] (str "Hello, " a "."))
  ([a & more] (str "Hello to all: " (apply str (interpose ", " (cons a more))) "!")))

(defmulti sound (fn [x] (:kind x)))

(defmethod sound :dog [a] (str (:name a) " barks."))

(defmethod sound :cat [a] (str (:name a) " meows."))

(defmethod sound :default [a] (str (:name a) " is quiet."))

;; a function of no arguments
(= "Hello!" (greet))

;; the same function, of one
(= "Hello, Ada." (greet "Ada"))

;; and of any number more
(= "Hello to all: Ada, Bob, Cy!" (greet "Ada" "Bob" "Cy"))

;; a multimethod dispatches on a function of its argument
(= "Rex barks." (sound {:kind :dog :name "Rex"}))

;; another of its methods
(= "Tom meows." (sound {:kind :cat :name "Tom"}))

;; its default method
(= "Nemo is quiet." (sound {:kind :fish :name "Nemo"}))

;; a missing dispatch value goes to the default too
(= "Anon is quiet." (sound {:name "Anon"}))
