;; probes/paip/vector-contains.wat: is there a membership test for a Vector, and which way round?
;;
;; paip/lib/prolog.wat collects a clause's variable names and must not list one twice, so it
;; asks whether a Vector of String already holds a name. :wat::core::contains? is registered,
;; but nothing in this repository calls it — not the koans, not the books, not mal, not sicp —
;; so both its acceptance of a plain Vector and its argument order are assumptions.
;;
;; Order matters here and has burned this project before: take-nth takes its count first while
;; take and drop take the collection first. A membership test could plausibly read
;; (contains? haystack needle) or (contains? needle haystack), and on a map Clojure's contains?
;; asks about a KEY, which for a vector means its INDEX, not its element. If that is what wat
;; means too, then (contains? ["a"] "a") is false and (contains? ["a"] 0) is true, and
;; paip/lib/prolog.wat needs a different test.
;;
;; Run from the repository root: wat probes/paip/vector-contains.wat

(:wat::core::defn :probe::show [label <- :wat::core::String b <- :wat::core::bool] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " (:wat::core::if b "true" "false"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [names (:wat::core::Vector :- [:wat::core::String] "?x" "?y")]
    (:wat::core::do
      ;; element membership, collection first
      (:probe::show "contains? [?x ?y] \"?x\"" (:wat::core::contains? names "?x"))
      (:probe::show "contains? [?x ?y] \"?z\"" (:wat::core::contains? names "?z")))))
