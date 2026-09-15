;; Strings: our own filled-in koans on the topic of the Clojure Koans' second file.

;; a string is itself
(= "plum" "plum")

;; str of a symbol is its name
(= "fig" (str 'fig))

;; str joins its arguments
(= "pear and plum" (str "pear" " and " "plum"))

;; a character of a string, by index
(= \e (get "pear" 1))

;; the length of a string
(= 9 (count "fig tree!"))

;; a character is not a one-character string
(= false (= \p "p"))

;; a substring, from start to end
(= "tree" (subs "fig tree" 4 8))

;; join with no separator
(= "456" (string/join [4 5 6]))

;; join with a separator
(= "4-5-6" (string/join "-" [4 5 6]))

;; split into lines
(= ["a" "b" "c"] (string/split-lines "a\nb\nc"))

;; reverse a string
(= "mulp" (string/reverse "plum"))

;; where a substring first occurs
(= 4 (string/index-of "fig tree" "tree"))

;; where it last occurs
(= 9 (string/last-index-of "fig tree fig" "fig"))

;; a substring that isn't there
(= nil (string/index-of "fig tree" "plum"))

;; trim whitespace from both ends
(= "fig tree" (string/trim " \t fig tree\n "))

;; a character is a char
(= true (char? \f))

;; a string is not a char
(= false (char? "f"))

;; a char is not a string
(= false (string? \f))

;; a string is a string
(= true (string? "f"))

;; the empty string is blank
(= true (string/blank? ""))

;; whitespace alone is blank
(= true (string/blank? "  \t\n "))

;; text is not blank
(= false (string/blank? "fig\ntree"))
