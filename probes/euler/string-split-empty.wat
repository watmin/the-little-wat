;; probes/euler/string-split-empty.wat: can a String be split into its characters?
;;
;; koans/idiom/02-strings.wat row 11 is marked missing with the note "reverse takes a Vector,
;; PersistentVector or List, not a String, and a String can't be split into characters (split
;; refuses an empty separator)". That note was written from a koan; this asks the runtime
;; directly, because it is the claim every text workload stands on.
;;
;; If split refuses "", then the only road to a character is a one-character subs — which is
;; what mal/lib/reader.wat's char-at does, what aoc/day02 pays 130 ms per 10000 characters for,
;; and what euler/p16-p20-p25-digits.wat walks a 302-digit number with.
;;
;; Run from the repository root: wat probes/euler/string-split-empty.wat

(:wat::core::defn :probe::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [parts (:wat::string::split "abc" "")]
    (:wat::core::do
      (:probe::show "pieces of (split \"abc\" \"\")" (:wat::i64::to-string (:wat::core::length parts)))
      (:probe::show "joined back" (:wat::string::join "|" parts)))))
