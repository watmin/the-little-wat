;; A Little Java, A Few Patterns, chapter 9 (Be a Good Visitor).
;; Shapes with a point-in-shape visitor, and then the datatype extended after the fact: a new
;; variant, Union, a visitor interface that extends the old one, and a visitor that extends
;; the old visitor. Java checks none of the extension: a visitor that isn't "good" (that makes
;; plain HasPtVs for a translated Union) fails at runtime with a ClassCastException.
;;
;; In wat the first half is a closed enum (ShapeD), a surface for the visitor protocol
;; (ShapeVisitorI) and a struct that extend-types it (HasPtV {p}). The extension can't extend
;; either: an enum is closed, and a surface can't extend another (defsurface has no :extends).
;; So it is a second enum, UShapeD, restating the three old variants beside Union, a second
;; surface, UnionVisitorI, restating the three old features beside for-union, and UnionHasPtV
;; implementing all four. What Java finds at runtime, wat finds at check time: the old visitor
;; is refused where the new protocol is expected (probes/java/old-visitor-on-new-shape.wat).
;; Results are printed as the Java oracle's are (oracle/java/ch09-be-a-good-visitor.java, run
;; by tools/java-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch09-be-a-good-visitor.wat

(:wat::load-file! "lib/check.wat")

;; ---- points

;; a record, not a struct: a Pure enum (ShapeD) may not hold a struct, even one of two i64s
;; (a defstruct is impure to the containment rule; a defrecord is pure data)
(:wat::core::defrecord :lj::CartesianPt [x <- :wat::core::i64  y <- :wat::core::i64])

(:wat::core::defn :lj::pt [x <- :wat::core::i64 y <- :wat::core::i64] -> :lj::CartesianPt (:lj::CartesianPt :x x :y y))

;; Java's (int) Math.sqrt(...), truncated; wat's conversion answers an Option
(:wat::core::defn :lj::distance-to-o [p <- :lj::CartesianPt] -> :wat::core::i64
  (:wat::core::let [x (:lj::CartesianPt/x p)
                    y (:lj::CartesianPt/y p)]
    (:wat::core::match (:wat::f64::to-i64 (:wat::math::sqrt (:wat::i64::to-f64 (:wat::core::+ (:wat::core::* x x) (:wat::core::* y y)))))
      [:wat::core::Option.Some {:value k} k]
      [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message "a distance out of i64's range")])))

(:wat::core::defn :lj::pt-minus [p <- :lj::CartesianPt q <- :lj::CartesianPt] -> :lj::CartesianPt
  (:lj::pt (:wat::core::- (:lj::CartesianPt/x p) (:lj::CartesianPt/x q)) (:wat::core::- (:lj::CartesianPt/y p) (:lj::CartesianPt/y q))))

(:wat::core::defn :lj::in-circle? [p <- :lj::CartesianPt r <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::<= (:lj::distance-to-o p) r))

(:wat::core::defn :lj::in-square? [p <- :lj::CartesianPt s <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::let [x (:lj::CartesianPt/x p)
                    y (:lj::CartesianPt/y p)]
    (:wat::core::if (:wat::core::if (:wat::core::>= x 0) (:wat::core::>= y 0) false)
      (:wat::core::if (:wat::core::<= x s) (:wat::core::<= y s) false)
      false)))

;; ---- shapes and the point-in-shape visitor

(:wat::core::defenum :lj::ShapeD :wat::enum::Pure
  :Circle [r <- :wat::core::i64]
  :Square [s <- :wat::core::i64]
  :Trans [q <- :lj::CartesianPt  s <- :lj::ShapeD])

(:wat::core::defsurface :lj::ShapeVisitorI :nature :wat::core::Struct
  :features [(for-circle [self <- :lj::ShapeVisitorI r <- :wat::core::i64] -> :wat::core::bool)
             (for-square [self <- :lj::ShapeVisitorI s <- :wat::core::i64] -> :wat::core::bool)
             (for-trans [self <- :lj::ShapeVisitorI q <- :lj::CartesianPt s <- :lj::ShapeD] -> :wat::core::bool)])

(:wat::core::defn :lj::accept [sh <- :lj::ShapeD ask <- :lj::ShapeVisitorI] -> :wat::core::bool
  (:wat::core::match sh
    [:lj::ShapeD.Circle {:r r} (:lj::ShapeVisitorI/for-circle ask r)]
    [:lj::ShapeD.Square {:s s} (:lj::ShapeVisitorI/for-square ask s)]
    [:lj::ShapeD.Trans {:q q :s s} (:lj::ShapeVisitorI/for-trans ask q s)]))

(:wat::core::defstruct :lj::HasPtV [p <- :lj::CartesianPt])
(:wat::core::extend-type :lj::HasPtV :lj::ShapeVisitorI
  (for-circle [self r] -> :wat::core::bool (:lj::in-circle? (:lj::HasPtV/p self) r))
  (for-square [self s] -> :wat::core::bool (:lj::in-square? (:lj::HasPtV/p self) s))
  (for-trans [self q s] -> :wat::core::bool (:lj::accept s (:lj::HasPtV :p (:lj::pt-minus (:lj::HasPtV/p self) q)))))

;; ---- the extension: shapes with Union, and a protocol that knows it

(:wat::core::defenum :lj::UShapeD :wat::enum::Pure
  :Circle [r <- :wat::core::i64]
  :Square [s <- :wat::core::i64]
  :Trans [q <- :lj::CartesianPt  s <- :lj::UShapeD]
  :Union [s <- :lj::UShapeD  t <- :lj::UShapeD])

(:wat::core::defsurface :lj::UnionVisitorI :nature :wat::core::Struct
  :features [(for-circle [self <- :lj::UnionVisitorI r <- :wat::core::i64] -> :wat::core::bool)
             (for-square [self <- :lj::UnionVisitorI s <- :wat::core::i64] -> :wat::core::bool)
             (for-trans [self <- :lj::UnionVisitorI q <- :lj::CartesianPt s <- :lj::UShapeD] -> :wat::core::bool)
             (for-union [self <- :lj::UnionVisitorI s <- :lj::UShapeD t <- :lj::UShapeD] -> :wat::core::bool)])

(:wat::core::defn :lj::u-accept [sh <- :lj::UShapeD ask <- :lj::UnionVisitorI] -> :wat::core::bool
  (:wat::core::match sh
    [:lj::UShapeD.Circle {:r r} (:lj::UnionVisitorI/for-circle ask r)]
    [:lj::UShapeD.Square {:s s} (:lj::UnionVisitorI/for-square ask s)]
    [:lj::UShapeD.Trans {:q q :s s} (:lj::UnionVisitorI/for-trans ask q s)]
    [:lj::UShapeD.Union {:s s :t t} (:lj::UnionVisitorI/for-union ask s t)]))

;; Java's UnionHasPtV inherits HasPtV's methods and adds forUnion; here all four are written
(:wat::core::defstruct :lj::UnionHasPtV [p <- :lj::CartesianPt])
(:wat::core::extend-type :lj::UnionHasPtV :lj::UnionVisitorI
  (for-circle [self r] -> :wat::core::bool (:lj::in-circle? (:lj::UnionHasPtV/p self) r))
  (for-square [self s] -> :wat::core::bool (:lj::in-square? (:lj::UnionHasPtV/p self) s))
  (for-trans [self q s] -> :wat::core::bool (:lj::u-accept s (:lj::UnionHasPtV :p (:lj::pt-minus (:lj::UnionHasPtV/p self) q))))
  (for-union [self s t] -> :wat::core::bool (:wat::core::if (:lj::u-accept s self) true (:lj::u-accept t self))))

(:wat::core::defn :lj::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [circle (:wat::core::fn [r <- :wat::core::i64] -> :lj::ShapeD (:lj::ShapeD.Circle {:r r}))
                    square (:wat::core::fn [s <- :wat::core::i64] -> :lj::ShapeD (:lj::ShapeD.Square {:s s}))
                    trans (:wat::core::fn [q <- :lj::CartesianPt s <- :lj::ShapeD] -> :lj::ShapeD (:lj::ShapeD.Trans {:q q :s s}))
                    u-circle (:wat::core::fn [r <- :wat::core::i64] -> :lj::UShapeD (:lj::UShapeD.Circle {:r r}))
                    u-square (:wat::core::fn [s <- :wat::core::i64] -> :lj::UShapeD (:lj::UShapeD.Square {:s s}))
                    u-trans (:wat::core::fn [q <- :lj::CartesianPt s <- :lj::UShapeD] -> :lj::UShapeD (:lj::UShapeD.Trans {:q q :s s}))
                    u-union (:wat::core::fn [s <- :lj::UShapeD t <- :lj::UShapeD] -> :lj::UShapeD (:lj::UShapeD.Union {:s s :t t}))
                    has-pt (:wat::core::fn [x <- :wat::core::i64 y <- :wat::core::i64] -> :lj::HasPtV (:lj::HasPtV :p (:lj::pt x y)))
                    u-has-pt (:wat::core::fn [x <- :wat::core::i64 y <- :wat::core::i64] -> :lj::UnionHasPtV (:lj::UnionHasPtV :p (:lj::pt x y)))
                    u (u-union (u-square 2) (u-trans (:lj::pt 10 0) (u-circle 3)))
                    tu (u-trans (:lj::pt 1 1) (u-union (u-circle 1) (u-square 1)))
                    bool :lj::show-bool]
    (:lj::check-chapter "oracle/java/ch09-be-a-good-visitor.expected"
                        "little-java ch09 be-a-good-visitor"
                        (:wat::core::Vector :- [:wat::core::String]
                          (bool (:lj::accept (circle 10) (has-pt 3 4)))
                          (bool (:lj::accept (circle 4) (has-pt 3 4)))
                          (bool (:lj::accept (square 5) (has-pt 3 4)))
                          (bool (:lj::accept (square 2) (has-pt 3 4)))
                          (bool (:lj::accept (trans (:lj::pt 5 6) (circle 10)) (has-pt 10 10)))
                          (bool (:lj::accept (trans (:lj::pt 5 6) (square 3)) (has-pt 10 10)))
                          (bool (:lj::u-accept u (u-has-pt 1 1)))
                          (bool (:lj::u-accept u (u-has-pt 12 1)))
                          (bool (:lj::u-accept u (u-has-pt 6 6)))
                          (bool (:lj::u-accept tu (u-has-pt 2 2)))))))
