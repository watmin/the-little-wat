;; probes/learner/ch01-mutant.wat: chapter 1 checked against a copy of the oracle with its
;; first value one ulp off (38.00000000000001). The exact comparison must refuse it.
;;

(:wat::load-file! "../../books/little-learner/lib/malt.wat")
(:wat::load-file! "../../books/little-learner/lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [theta (:wat::core::fn [w <- :wat::core::f64 b <- :wat::core::f64] -> :ll::V
                            (:ll::lst (:wat::core::Vector :- [:ll::V] (:ll::num w) (:ll::num b))))
                    line-at-5 (:ll::line (:ll::num 5.0))]
    (:ll::check-chapter "probes/learner/ch01-mutant.expected"
                        "little-learner ch01 the-lines-sleep-tonight"
                        (:wat::core::Vector :- [:ll::V]
                          ;; a line is a function of x that, given theta = (w b), gives w*x + b
                          ((:ll::line (:ll::num 8.0)) (theta 4.0 6.0))
                          ((:ll::line (:ll::num 2.0)) (theta 0.5 1.5))
                          ((:ll::line (:ll::num -3.0)) (theta 1.0 0.0))
                          ((:ll::line (:ll::num 0.0)) (theta 7.0 -2.5))
                          ((:ll::line (:ll::num 0.1)) (theta 0.2 0.3))
                          ((:ll::line (:ll::num 1e10)) (theta 1e-10 1.0))
                          ;; the same x with different parameters: a family of lines
                          (line-at-5 (theta 1.0 0.0))
                          (line-at-5 (theta 2.0 1.0))
                          (line-at-5 (theta -0.5 3.25))
                          ;; the arithmetic under it
                          (:ll::+ (:ll::num 0.1) (:ll::num 0.2))
                          (:ll::* (:ll::num 3.0) (:ll::+ (:ll::num 1.0) (:ll::num 2.0)))
                          (:ll::- (:ll::num 1.0) (:ll::num 3.5))
                          (:ll::/ (:ll::num 1.0) (:ll::num 3.0))))))
