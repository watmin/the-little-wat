;; probes/learner/f64-printing.wat: how does wat print an f64? The Little Learner's results
;; are floats, and comparing them with Racket's means comparing printers. Cases where
;; printers commonly differ: shortest round-trip digits, exponent thresholds, integral
;; floats, negative zero, and a transcendental.

(:wat::core::defn :probe::show [label <- :wat::core::String x <- :wat::core::f64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label " " (:wat::f64::to-string x))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:probe::show "0.1+0.2" (:wat::core::+ 0.1 0.2))
    (:probe::show "1e21" 1e21)
    (:probe::show "1e22" 1e22)
    (:probe::show "1/3" (:wat::core::/ 1.0 3.0))
    (:probe::show "100.0" 100.0)
    (:probe::show "1e-7" 1e-7)
    (:probe::show "0.0001" 0.0001)
    (:probe::show "-0.0" (:wat::core::- 0.0 0.0))
    (:probe::show "neg-zero" (:wat::core::* -1.0 0.0))
    (:probe::show "e" (:wat::math::exp 1.0))))
