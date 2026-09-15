;; probes/learner/string-to-f64.wat: what does :wat::string::to-f64 accept, and what does
;; it return? The oracle prints Racket flonums: 1e-07, 0.30000000000000004, -0.0, 8.0.

(:wat::core::defn :probe::try [s <- :wat::core::String] -> :wat::core::nil
  (:wat::core::match (:wat::string::to-f64 s)
    [:wat::core::Option.Some {:value x} (:wat::kernel::println (:wat::string::concat s " -> " (:wat::f64::to-string x)))]
    [:wat::core::Option.None {} (:wat::kernel::println (:wat::string::concat s " -> None"))]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:probe::try "1e-07")
    (:probe::try "0.30000000000000004")
    (:probe::try "-0.0")
    (:probe::try "8.0")
    (:probe::try "8")
    (:probe::try "+inf.0")
    (:probe::try "7/13")
    (:probe::try "pear")))
