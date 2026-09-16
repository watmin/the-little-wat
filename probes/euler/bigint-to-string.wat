;; probes/euler/bigint-to-string.wat: can a bigint's digits be reached as a String?
;;
;; Every scalar in wat has a to-string: :wat::i64::to-string, :wat::f64::to-string. The
;; registered bigint verbs are +, -, *, to-f64 and to-rational — there appears to be no
;; :wat::bigint::to-string. If there isn't one, then a big integer can be computed and printed
;; but never taken apart, and Project Euler's digit-sum problems (p16: the digits of 2^1000;
;; p20: the digits of 100!; p48: the last ten digits of a sum) cannot be written at all.
;;
;; :wat::edn::write is asked separately in probes/euler/bigint-surface.wat, since it may answer
;; the digits by another road.
;;
;; Its own file because a startup refusal ends the program.
;;
;; Run from the repository root: wat probes/euler/bigint-to-string.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::bigint::to-string (:wat::i64::to-bigint 12345))))
