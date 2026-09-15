;; probes/koans/str-arity.wat: Clojure's str takes any number of arguments. wat's
;; :wat::core::str takes one (its runtime says so, koans/keyword/02-strings.tsv row 3). Does the
;; checker know, in the keyword spelling?

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::str "pear" " and " "plum")))
