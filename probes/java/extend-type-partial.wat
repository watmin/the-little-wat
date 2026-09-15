;; probes/java/extend-type-partial.wat: must extend-type implement every feature of the surface?
;; Java refuses to compile a class that leaves an interface method out. Here HalfV implements
;; for-bud and not for-flat, and then for-flat is called.

(:wat::core::defenum :probe::TreeD :wat::enum::Pure
  :Bud []
  :Flat [t <- :probe::TreeD])

(:wat::core::defsurface :probe::TreeVisitorI :- [R] :nature :wat::core::Struct
  :features [(for-bud [self <- (:probe::TreeVisitorI :- [R])] -> R)
             (for-flat [self <- (:probe::TreeVisitorI :- [R]) t <- :probe::TreeD] -> R)])

(:wat::core::defstruct :probe::HalfV [])
(:wat::core::extend-type :probe::HalfV (:probe::TreeVisitorI :- [:wat::core::i64])
  (for-bud [self] -> :wat::core::i64 0))

(:wat::core::defn :probe::accept-int [t <- :probe::TreeD ask <- (:probe::TreeVisitorI :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::match t
    [:probe::TreeD.Bud {} (:probe::TreeVisitorI/for-bud ask)]
    [:probe::TreeD.Flat {:t rest} (:probe::TreeVisitorI/for-flat ask rest)]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::string::concat "bud: " (:wat::i64::to-string (:probe::accept-int (:probe::TreeD.Bud {}) (:probe::HalfV)))))
    (:wat::kernel::println (:wat::string::concat "flat: " (:wat::i64::to-string (:probe::accept-int (:probe::TreeD.Flat {:t (:probe::TreeD.Bud {})}) (:probe::HalfV)))))))
