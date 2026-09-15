;; probes/learner/enum-with-fn-field.wat: can a Pure enum variant hold a function? The
;; Little Learner's dual numbers carry their backpropagation link as a closure. As Pure it is
;; refused (arc 293 containment rule), the error located in src/check.rs; so Impure.

(:wat::core::defenum :probe::Link :wat::enum::Impure
  :End  [id <- :wat::core::i64]
  :Step [f <- [:wat::core::f64 :-> :wat::core::f64]])

(:wat::core::defn :probe::run [l <- :probe::Link x <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::match l
    [:probe::Link.End {:id id} (:wat::core::+ x (:wat::i64::to-f64 id))]
    [:probe::Link.Step {:f f} (f x)]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [k 3.0
                    step (:probe::Link.Step {:f (:wat::core::fn [z <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* k z))})]
    (:wat::core::do
      (:wat::kernel::println (:wat::f64::to-string (:probe::run step 2.0)))
      (:wat::kernel::println (:wat::f64::to-string (:probe::run (:probe::Link.End {:id 4}) 2.0))))))
