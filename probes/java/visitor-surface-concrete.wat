;; probes/java/visitor-surface-concrete.wat: the same visitor protocol as a surface, with accept
;; written at a concrete answer type (one accept per answer type, as the book's Java has before
;; its Object-answering interface). Two visitors: HeightV, and OccursV, a struct with a field
;; (the fruit to count), read through self, as Java's OccursV keeps its fruit.

(:wat::core::defenum :probe::TreeD :wat::enum::Pure
  :Bud []
  :Flat [f <- :wat::core::i64  t <- :probe::TreeD])

(:wat::core::defsurface :probe::TreeVisitorI :- [R] :nature :wat::core::Struct
  :features [(for-bud [self <- (:probe::TreeVisitorI :- [R])] -> R)
             (for-flat [self <- (:probe::TreeVisitorI :- [R]) f <- :wat::core::i64 t <- :probe::TreeD] -> R)])

(:wat::core::defn :probe::accept-int [t <- :probe::TreeD ask <- (:probe::TreeVisitorI :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::match t
    [:probe::TreeD.Bud {} (:probe::TreeVisitorI/for-bud ask)]
    [:probe::TreeD.Flat {:f f :t rest} (:probe::TreeVisitorI/for-flat ask f rest)]))

(:wat::core::defstruct :probe::HeightV [])
(:wat::core::extend-type :probe::HeightV (:probe::TreeVisitorI :- [:wat::core::i64])
  (for-bud [self] -> :wat::core::i64 0)
  (for-flat [self f t] -> :wat::core::i64 (:wat::core::+ 1 (:probe::accept-int t self))))

(:wat::core::defstruct :probe::OccursV [a <- :wat::core::i64])
(:wat::core::extend-type :probe::OccursV (:probe::TreeVisitorI :- [:wat::core::i64])
  (for-bud [self] -> :wat::core::i64 0)
  (for-flat [self f t] -> :wat::core::i64
    (:wat::core::let [rest (:probe::accept-int t self)]
      (:wat::core::if (:wat::core::= f (:probe::OccursV/a self)) (:wat::core::+ 1 rest) rest))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [tree (:probe::TreeD.Flat {:f 7 :t (:probe::TreeD.Flat {:f 3 :t (:probe::TreeD.Flat {:f 7 :t (:probe::TreeD.Bud {})})})})]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "height " (:wat::i64::to-string (:probe::accept-int tree (:probe::HeightV)))))
      (:wat::kernel::println (:wat::string::concat "occurs 7 " (:wat::i64::to-string (:probe::accept-int tree (:probe::OccursV :a 7))))))))
