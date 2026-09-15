;; probes/java/old-visitor-on-new-shape.wat: A Little Java ch 9's runtime failure, in wat. Java's
;; old HasPtV, handed a shape that holds a Union, throws a ClassCastException when the Union is
;; reached. Here the extended shapes' accept expects the extended protocol, and the old visitor,
;; which implements only the old one, is handed to it. Expected: refused at check time.

(:wat::core::defenum :probe::UShapeD :wat::enum::Pure
  :Circle [r <- :wat::core::i64]
  :Union [s <- :probe::UShapeD  t <- :probe::UShapeD])

(:wat::core::defsurface :probe::ShapeVisitorI :nature :wat::core::Struct
  :features [(for-circle [self <- :probe::ShapeVisitorI r <- :wat::core::i64] -> :wat::core::bool)])

(:wat::core::defsurface :probe::UnionVisitorI :nature :wat::core::Struct
  :features [(for-circle [self <- :probe::UnionVisitorI r <- :wat::core::i64] -> :wat::core::bool)
             (for-union [self <- :probe::UnionVisitorI s <- :probe::UShapeD t <- :probe::UShapeD] -> :wat::core::bool)])

(:wat::core::defn :probe::u-accept [sh <- :probe::UShapeD ask <- :probe::UnionVisitorI] -> :wat::core::bool
  (:wat::core::match sh
    [:probe::UShapeD.Circle {:r r} (:probe::UnionVisitorI/for-circle ask r)]
    [:probe::UShapeD.Union {:s s :t t} (:probe::UnionVisitorI/for-union ask s t)]))

;; the old visitor: it knows circles, and nothing of unions
(:wat::core::defstruct :probe::HasPtV [r0 <- :wat::core::i64])
(:wat::core::extend-type :probe::HasPtV :probe::ShapeVisitorI
  (for-circle [self r] -> :wat::core::bool (:wat::core::<= (:probe::HasPtV/r0 self) r)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::core::if (:probe::u-accept (:probe::UShapeD.Union {:s (:probe::UShapeD.Circle {:r 1}) :t (:probe::UShapeD.Circle {:r 5})})
                                      (:probe::HasPtV :r0 3))
      "inside" "outside")))
