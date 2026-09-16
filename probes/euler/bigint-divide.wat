;; probes/euler/bigint-divide.wat: is there a bigint division, as F-047 says there is?
;;
;; F-047 records "bigint +, -, * and /". A grep of wat-rs's registered intrinsics finds
;; :wat::bigint::+, -, *, to-f64 and to-rational — and no /. One of the two is wrong, and it
;; matters: without division or a modulo there is no way to take a bigint apart digit by digit,
;; which is what Project Euler's p16, p20 and p48 all need.
;;
;; Its own file because a startup refusal ends the program.
;;
;; Run from the repository root: wat probes/euler/bigint-divide.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [hundred (:wat::i64::to-bigint 100)
                    ten     (:wat::i64::to-bigint 10)]
    (:wat::kernel::println (:wat::edn::write (:wat::bigint::/ hundred ten)))))
