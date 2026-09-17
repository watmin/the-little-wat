;; probes/oo/surface-subtyping.wat — how much of EOPL ch9's subtyping does wat already have?
;;
;; TYPED-OO (C-073) gives a language two things: SUBSUMPTION (a c2 where a c1 is wanted) and
;; DYNAMIC DISPATCH through a supertype. wat has no classes, so the question is what `defsurface`
;; + `extend-type` deliver. Measured 2026-09-16, wat-rs a3218644d:
;;
;;   concrete -> surface subsumption          YES
;;   a heterogeneous collection at the surface YES
;;   dispatch through it                       YES  (25 + 10 = 35 below)
;;   concrete -> concrete subtyping            NO   (recorded below; it is a startup error)
;;
;; So wat has the interface half of ch9 and not the inheritance half -- "program to an interface,
;; not an implementation", enforced rather than advised.

(:wat::core::defsurface :s::Shape :- [T] :nature :wat::core::Struct
  :features [(area [self <- (:s::Shape :- [T]) x <- T] -> :wat::core::i64)])

(:wat::core::defstruct :s::Sq [])
(:wat::core::extend-type :s::Sq (:s::Shape :- [:wat::core::i64])
  (area [self x] -> :wat::core::i64 (:wat::core::* x x)))

(:wat::core::defstruct :s::Dbl [])
(:wat::core::extend-type :s::Dbl (:s::Shape :- [:wat::core::i64])
  (area [self x] -> :wat::core::i64 (:wat::core::* x 2)))

;; a parameter typed at the SURFACE takes either concrete implementation -- subsumption
(:wat::core::defn :s::use [sh <- (:s::Shape :- [:wat::core::i64]) n <- :wat::core::i64] -> :wat::core::i64
  (:s::Shape/area sh n))

;; and a heterogeneous collection dispatches, which is what ch9 builds by hand
(:wat::core::defn :s::total [v <- (:wat::core::Vector :- [(:s::Shape :- [:wat::core::i64])])
                             i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length v)) acc
    (:s::total v (:wat::core::+ i 1)
      (:wat::core::+ acc (:s::Shape/area (:wat::core::nth v i) 5)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [v (:wat::core::Vector :- [(:s::Shape :- [:wat::core::i64])]
                        (:s::Sq) (:s::Dbl))]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "Sq  through the surface   "
        (:wat::i64::to-string (:s::use (:s::Sq) 5))))
      (:wat::kernel::println (:wat::string::concat "Dbl through the surface   "
        (:wat::i64::to-string (:s::use (:s::Dbl) 5))))
      (:wat::kernel::println (:wat::string::concat "one collection, both       "
        (:wat::i64::to-string (:wat::core::length v)) " elements"))
      (:wat::kernel::println (:wat::string::concat "dispatch through it        "
        (:wat::i64::to-string (:s::total v 0 0)) "   (25 + 10)"))
      ;; the NO row, recorded rather than run -- it is a startup error, so it would stop the file:
      ;;   (:wat::core::defstruct :s::A [n <- :wat::core::i64])
      ;;   (:wat::core::defstruct :s::B [n <- :wat::core::i64])   ; structurally identical
      ;;   (:s::take-a (:s::B 1))
      ;;     => ":s::take-a: parameter #1 expects :s::A; got :s::B"
      (:wat::kernel::println "concrete -> concrete       REJECTED: expects :s::A; got :s::B"))))
