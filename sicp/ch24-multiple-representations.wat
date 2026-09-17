;; SICP §2.4 (multiple representations for abstract data), in wat.
;;
;; A complex number held two ways -- rectangular and polar -- reached three ways. The section
;; exists to compare the three, so all three are built here rather than the one that fits wat best.
;;
;;   1. EXPLICIT DISPATCH on a type tag. In wat the tag is an enum, so `real-part`'s dispatch is
;;      checked exhaustive; SICP's ends in `(else (error "unknown type"))`, a case the reader is
;;      told to worry about and the compiler never sees. Adding a third representation is a
;;      compile error here and a run-time surprise there -- which is the section's own complaint
;;      about explicit dispatch, answered.
;;
;;   2. DATA-DIRECTED: a table keyed by (operation, type), holding PROCEDURES. This works in wat --
;;      a `HashMap` can hold closures -- and it is the first thing in this repository to put
;;      functions in a map rather than in a struct. The key is a single String `"op/type"`, since
;;      the map is keyed by one value.
;;
;;   3. MESSAGE PASSING: the object IS a procedure, `[String :-> f64]`. This types cleanly only
;;      because every selector here answers an f64. A message-passing object whose messages return
;;      DIFFERENT types has no wat spelling short of an enum return -- which is the typed
;;      language's real objection to this style, and worth naming: SICP's version silently relies
;;      on the answers being unioned by the untyped language.
;;
;; The trade the section is about comes out differently here. SICP prefers data-directed because
;; it is additive. In wat the enum is additive *at compile time* -- add a variant and every
;; `match` that does not handle it fails -- while the table is additive at RUN time and a missing
;; entry is an Option you must handle. Both are safe; only the enum tells you before you ship.
;;
;; Floats are reported as tolerance comparisons, so formatting cannot fail a passing chapter.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch24-multiple-representations.scm,
;; run by tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch24-multiple-representations.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defn :sicp::near? [a <- :wat::core::f64 b <- :wat::core::f64 eps <- :wat::core::f64] -> :wat::core::bool
  (:wat::core::< (:wat::f64::abs (:wat::core::- a b)) eps))

(:wat::core::defn :sicp::fsq [x <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* x x))

;; ---- 1. explicit dispatch: the tag is an enum, so the dispatch is checked exhaustive
(:wat::core::defenum :sicp::Complex :wat::enum::Pure
  :Rect  [re <- :wat::core::f64  im <- :wat::core::f64]
  :Polar [mag <- :wat::core::f64  ang <- :wat::core::f64])

(:wat::core::defn :sicp::real-part [z <- :sicp::Complex] -> :wat::core::f64
  (:wat::core::match z
    [:sicp::Complex.Rect {:re re :im im} re]
    [:sicp::Complex.Polar {:mag m :ang a} (:wat::core::* m (:wat::math::cos a))]))

(:wat::core::defn :sicp::imag-part [z <- :sicp::Complex] -> :wat::core::f64
  (:wat::core::match z
    [:sicp::Complex.Rect {:re re :im im} im]
    [:sicp::Complex.Polar {:mag m :ang a} (:wat::core::* m (:wat::math::sin a))]))

(:wat::core::defn :sicp::magnitude [z <- :sicp::Complex] -> :wat::core::f64
  (:wat::core::match z
    [:sicp::Complex.Rect {:re re :im im}
      (:wat::math::sqrt (:wat::core::+ (:sicp::fsq re) (:sicp::fsq im)))]
    [:sicp::Complex.Polar {:mag m :ang a} m]))

;; written ONCE, against the selectors, and it works across representations
(:wat::core::defn :sicp::add-complex [z1 <- :sicp::Complex z2 <- :sicp::Complex] -> :sicp::Complex
  (:sicp::Complex.Rect {:re (:wat::core::+ (:sicp::real-part z1) (:sicp::real-part z2))
                        :im (:wat::core::+ (:sicp::imag-part z1) (:sicp::imag-part z2))}))

;; ---- 2. data-directed: a table of (operation, type) -> procedure
;; The table holds CLOSURES over the untagged contents, so each entry takes the two components.
(:wat::core::typealias :sicp::Op [:wat::core::f64 :wat::core::f64 :-> :wat::core::f64])
(:wat::core::typealias :sicp::Table (:wat::core::HashMap :- [:wat::core::String :sicp::Op]))

(:wat::core::defn :sicp::put [t <- :sicp::Table op <- :wat::core::String ty <- :wat::core::String f <- :sicp::Op] -> :sicp::Table
  (:wat::core::assoc t (:wat::string::concat op "/" ty) f))

(:wat::core::defn :sicp::get-entry [t <- :sicp::Table op <- :wat::core::String ty <- :wat::core::String]
  -> (:wat::core::Option :- [:sicp::Op])
  (:wat::core::get t (:wat::string::concat op "/" ty)))

(:wat::core::defn :sicp::tag-of [z <- :sicp::Complex] -> :wat::core::String
  (:wat::core::match z
    [:sicp::Complex.Rect {:re re :im im} "rectangular"]
    [:sicp::Complex.Polar {:mag m :ang a} "polar"]))

(:wat::core::defn :sicp::part1 [z <- :sicp::Complex] -> :wat::core::f64
  (:wat::core::match z
    [:sicp::Complex.Rect {:re re :im im} re]
    [:sicp::Complex.Polar {:mag m :ang a} m]))

(:wat::core::defn :sicp::part2 [z <- :sicp::Complex] -> :wat::core::f64
  (:wat::core::match z
    [:sicp::Complex.Rect {:re re :im im} im]
    [:sicp::Complex.Polar {:mag m :ang a} a]))

(:wat::core::defn :sicp::build-table [] -> :sicp::Table
  (:wat::core::let [t0 (:wat::core::HashMap :- [:wat::core::String :sicp::Op])
                    t1 (:sicp::put t0 "real-part" "rectangular"
                         (:wat::core::fn [x <- :wat::core::f64 y <- :wat::core::f64] -> :wat::core::f64 x))
                    t2 (:sicp::put t1 "imag-part" "rectangular"
                         (:wat::core::fn [x <- :wat::core::f64 y <- :wat::core::f64] -> :wat::core::f64 y))
                    t3 (:sicp::put t2 "magnitude" "rectangular"
                         (:wat::core::fn [x <- :wat::core::f64 y <- :wat::core::f64] -> :wat::core::f64
                           (:wat::math::sqrt (:wat::core::+ (:sicp::fsq x) (:sicp::fsq y)))))
                    t4 (:sicp::put t3 "real-part" "polar"
                         (:wat::core::fn [r <- :wat::core::f64 a <- :wat::core::f64] -> :wat::core::f64
                           (:wat::core::* r (:wat::math::cos a))))
                    t5 (:sicp::put t4 "imag-part" "polar"
                         (:wat::core::fn [r <- :wat::core::f64 a <- :wat::core::f64] -> :wat::core::f64
                           (:wat::core::* r (:wat::math::sin a))))
                    t6 (:sicp::put t5 "magnitude" "polar"
                         (:wat::core::fn [r <- :wat::core::f64 a <- :wat::core::f64] -> :wat::core::f64 r))]
    t6))

;; a missing entry is an Option the caller must handle -- run-time, but not silent
(:wat::core::defn :sicp::apply-generic [t <- :sicp::Table op <- :wat::core::String z <- :sicp::Complex] -> :wat::core::f64
  (:wat::core::match (:sicp::get-entry t op (:sicp::tag-of z))
    [:wat::core::Option.Some {:value f} (f (:sicp::part1 z) (:sicp::part2 z))]
    [:wat::core::Option.None {} 0.0]))

(:wat::core::defn :sicp::has-entry? [t <- :sicp::Table op <- :wat::core::String ty <- :wat::core::String] -> :wat::core::bool
  (:wat::core::match (:sicp::get-entry t op ty)
    [:wat::core::Option.Some {:value f} true]
    [:wat::core::Option.None {} false]))

;; ---- 3. message passing: the object IS a procedure
(:wat::core::typealias :sicp::Msg [:wat::core::String :-> :wat::core::f64])

(:wat::core::defn :sicp::make-from-real-imag-msg [x <- :wat::core::f64 y <- :wat::core::f64] -> :sicp::Msg
  (:wat::core::fn [op <- :wat::core::String] -> :wat::core::f64
    (:wat::core::if (:wat::core::= op "real-part") x
      (:wat::core::if (:wat::core::= op "imag-part") y
        (:wat::core::if (:wat::core::= op "magnitude")
          (:wat::math::sqrt (:wat::core::+ (:sicp::fsq x) (:sicp::fsq y)))
          0.0)))))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [z-rect (:sicp::Complex.Rect {:re 3.0 :im 4.0})
                    z-polar (:sicp::Complex.Polar {:mag 5.0 :ang 0.0})
                    tbl (:sicp::build-table)
                    zm (:sicp::make-from-real-imag-msg 3.0 4.0)
                    eps 0.0001]
    (:sicp::check-chapter "oracle/sicp/ch24-multiple-representations.expected"
                          "sicp ch24 multiple representations"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::b (:sicp::near? (:sicp::real-part z-rect) 3.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::imag-part z-rect) 4.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::magnitude z-rect) 5.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::real-part z-polar) 5.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::imag-part z-polar) 0.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::magnitude z-polar) 5.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::real-part (:sicp::add-complex z-rect z-polar)) 8.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::imag-part (:sicp::add-complex z-rect z-polar)) 4.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::magnitude (:sicp::add-complex z-rect z-rect)) 10.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::apply-generic tbl "real-part" z-rect) 3.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::apply-generic tbl "magnitude" z-rect) 5.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::apply-generic tbl "real-part" z-polar) 5.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::apply-generic tbl "magnitude" z-polar) 5.0 eps))
                            (:sicp::b (:sicp::has-entry? tbl "angle" "polar"))
                            (:sicp::b (:sicp::has-entry? tbl "nonesuch" "polar"))
                            (:sicp::b (:sicp::near? (zm "real-part") 3.0 eps))
                            (:sicp::b (:sicp::near? (zm "imag-part") 4.0 eps))
                            (:sicp::b (:sicp::near? (zm "magnitude") 5.0 eps))
                            (:sicp::b (:sicp::near? (:sicp::real-part z-rect) (:sicp::apply-generic tbl "real-part" z-rect) eps))
                            (:sicp::b (:sicp::near? (:sicp::magnitude z-rect) (zm "magnitude") eps))))))
