;; probes/euler/regex-find.wat: can a match be retrieved, not merely detected?
;;
;; :wat::regex::matches? answers a bool. Every text workload needs the matched text itself, or a
;; capture group, or at least the position of the match. Clojure has re-find, re-matches,
;; re-seq and re-groups; Rust's regex crate — which wat-rs depends on in full — has find,
;; captures and find_iter.
;;
;; The name asked here is the obvious one. If it is unresolved at startup, the answer is that
;; the surface is the single predicate.
;;
;; Its own file because a startup refusal ends the program.
;;
;; Run from the repository root: wat probes/euler/regex-find.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::regex::find "[0-9]+" "abc123def")))
