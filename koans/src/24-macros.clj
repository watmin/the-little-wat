;; Macros: our own filled-in koans on the topic of the Clojure Koans' twenty-fourth file.

(defmacro greeting [x] (str "Hi, " x))

(defmacro infix [form] (list (second form) (first form) (nth form 2)))

(defmacro infix-concise [form] `(~(second form) ~(first form) ~(nth form 2)))

(defmacro recursive-infix [form]
  (cond (not (seq? form)) form
        (= 1 (count form)) `(recursive-infix ~(first form))
        :else (let [operator (second form) first-arg (first form) others (drop 2 form)]
                `(~operator (recursive-infix ~first-arg) (recursive-infix ~others)))))

;; a macro that builds a string as it expands
(= "Hi, macros" (greeting "macros"))

;; a macro that rearranges its form
(= 12 (infix (8 + 4)))

;; what it expands to
(= '(+ 8 4) (macroexpand '(infix (8 + 4))))

;; the same, by syntax-quote
(= '(* 6 7) (macroexpand '(infix-concise (6 * 7))))

;; only one level is rearranged
(= '(+ 6 (7 * 2)) (macroexpand '(infix-concise (6 + (7 * 2)))))

;; a macro that recurs
(= 42 (recursive-infix (6 + (4 * 5) + (2 * 8))))
