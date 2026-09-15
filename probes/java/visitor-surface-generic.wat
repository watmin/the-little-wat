;; probes/java/visitor-surface-generic.wat: A Little Java's visitor protocol as a wat surface.
;; TreeVisitorI :- [R] is the interface, a visitor is a struct that extend-types it at its answer
;; type, and accept is written once, generic over R, as Java's Object-answering accept is.
;; Does a generic fn over the surface take a struct that extends it at i64 (F-029's shape)?

(:wat::core::defenum :probe::TreeD :wat::enum::Pure
  :Bud []
  :Flat [t <- :probe::TreeD])

(:wat::core::defsurface :probe::TreeVisitorI :- [R] :nature :wat::core::Struct
  :features [(for-bud [self <- (:probe::TreeVisitorI :- [R])] -> R)
             (for-flat [self <- (:probe::TreeVisitorI :- [R]) t <- :probe::TreeD] -> R)])

(:wat::core::defn :probe::accept :- [R] [t <- :probe::TreeD ask <- (:probe::TreeVisitorI :- [R])] -> R
  (:wat::core::match t
    [:probe::TreeD.Bud {} (:probe::TreeVisitorI/for-bud ask)]
    [:probe::TreeD.Flat {:t rest} (:probe::TreeVisitorI/for-flat ask rest)]))

(:wat::core::defstruct :probe::HeightV [])
(:wat::core::extend-type :probe::HeightV (:probe::TreeVisitorI :- [:wat::core::i64])
  (for-bud [self] -> :wat::core::i64 0)
  (for-flat [self t] -> :wat::core::i64 (:wat::core::+ 1 (:probe::accept t self))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::i64::to-string
    (:probe::accept (:probe::TreeD.Flat {:t (:probe::TreeD.Flat {:t (:probe::TreeD.Bud {})})}) (:probe::HeightV)))))
