;; probes/paip/multiple-dispatch.wat — does wat have multiple dispatch?
;;
;; **Yes: `:wat::core::defclause`.** This probe replaces an earlier one that concluded the
;; opposite, and the history is worth keeping: the first version tested `defsurface` +
;; `extend-type`, found that a concrete type may extend a surface only once, and stopped there.
;; It never asked whether another mechanism existed. It does, it is one of wat's two polymorphism
;; mechanisms, and it carries wat's own arithmetic. See F-109.
;;
;; What `defclause` does, measured 2026-09-16, wat-rs a3218644d:
;;
;;   1. dispatches per ARGUMENT POSITION, first-match-wins -- so collide(asteroid, ship) and
;;      collide(asteroid, asteroid) run different code, which is the whole of PAIP ch13;
;;   2. dispatches on the RUNTIME type, not merely the declared one -- one statically-typed
;;      function whose parameters are both a surface type selects three different clauses;
;;   3. a missing combination at a CONCRETELY-typed call site is a COMPILE error
;;      ("1 type-check error … NoMatchingClause"), and only degrades to a runtime error when the
;;      call site's static type is wider than the clauses.
;;
;; (3) is the part an earlier finding got backwards: it claimed a hand-built dispatch table was
;; needed and that such a table "loses exhaustiveness". The table does; `defclause` does not.
;;
;; The compile-error case cannot live in this file, since it stops the program. It is:
;;   (:wat::core::defclause :d::collide ([a <- :d::Asteroid b <- :d::Ship] -> … ))
;;   (:d::collide (:d::Ship) (:d::Asteroid))
;;   => #wat.check/CheckErrors "1 type-check error" … NoMatchingClause

(:wat::core::defsurface :d::Thing :- [T] :nature :wat::core::Struct
  :features [(name [self <- (:d::Thing :- [T])] -> :wat::core::String)])

(:wat::core::defstruct :d::Asteroid [])
(:wat::core::defstruct :d::Ship [])

(:wat::core::extend-type :d::Asteroid (:d::Thing :- [:wat::core::i64])
  (name [self] -> :wat::core::String "asteroid"))
(:wat::core::extend-type :d::Ship (:d::Thing :- [:wat::core::i64])
  (name [self] -> :wat::core::String "ship"))

;; MULTIPLE dispatch: the second argument's type selects the clause
(:wat::core::defclause :d::collide
  ([a <- :d::Asteroid  b <- :d::Ship]     -> :wat::core::String "ship destroyed")
  ([a <- :d::Asteroid  b <- :d::Asteroid] -> :wat::core::String "both shatter")
  ([a <- :d::Ship      b <- :d::Ship]     -> :wat::core::String "both damaged")
  ([a <- :d::Ship      b <- :d::Asteroid] -> :wat::core::String "ship destroyed too"))

;; one statically-typed function: BOTH parameters are the surface type, so anything that varies
;; between the calls below is the arguments' RUNTIME types
(:wat::core::defn :d::via [x <- (:d::Thing :- [:wat::core::i64]) y <- (:d::Thing :- [:wat::core::i64])] -> :wat::core::String
  (:d::collide x y))

;; single dispatch on `self`, for contrast: this is what a surface does
(:wat::core::defn :d::describe [t <- (:d::Thing :- [:wat::core::i64])] -> :wat::core::String
  (:d::Thing/name t))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- defclause: dispatch on EVERY argument ----")
    (:wat::kernel::println (:d::collide (:d::Asteroid) (:d::Ship)))
    (:wat::kernel::println (:d::collide (:d::Asteroid) (:d::Asteroid)))
    (:wat::kernel::println (:d::collide (:d::Ship) (:d::Ship)))
    (:wat::kernel::println (:d::collide (:d::Ship) (:d::Asteroid)))

    (:wat::kernel::println "---- and on the RUNTIME type: same function, surface-typed parameters ----")
    (:wat::kernel::println (:wat::string::concat "A,S -> " (:d::via (:d::Asteroid) (:d::Ship))))
    (:wat::kernel::println (:wat::string::concat "A,A -> " (:d::via (:d::Asteroid) (:d::Asteroid))))
    (:wat::kernel::println (:wat::string::concat "S,S -> " (:d::via (:d::Ship) (:d::Ship))))

    (:wat::kernel::println "---- a surface, for contrast: dispatch on `self` only ----")
    (:wat::kernel::println (:d::describe (:d::Asteroid)))
    (:wat::kernel::println (:d::describe (:d::Ship)))

    (:wat::kernel::println "---- what the docs say, and where ----")
    (:wat::kernel::println "  OP-PLACEMENT.md: \"first-match-wins by per-position type match\"")
    (:wat::kernel::println "  mentions: USER-GUIDE 3, cheatsheet 0, rosetta 0, SERVICE-PROGRAMS 0")))
