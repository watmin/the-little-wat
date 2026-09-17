;; probes/clause/redefinition-and-order.wat — two facts about `defclause` that bear on whether it
;; could ever be made OPEN (an `extend-clause`, the way `extend-type` extends a surface).
;;
;; Measured 2026-09-17, wat-rs a3218644d. Neither can live in this file as a running case -- the
;; first is a startup error and the second needs two whole programs -- so both are recorded with
;; their verbatim output and the file demonstrates the shapes that DO run.
;;
;; FACT 1 (F-110, a defect): a second `defclause` with the same name SILENTLY REPLACES the first.
;;
;;     (:wat::core::defclause :d::f ([x <- :d::A] -> … "a"))
;;     (:wat::core::defclause :d::f ([x <- :d::B] -> … "b"))
;;     (:d::f (:d::A))
;;   => "no clause of `:d::f` matches arity 1 with types [:d::A]; clauses attempted: (1: [:d::B])"
;;
;; "clauses attempted: (1: [:d::B])" is the whole story: the A clause is gone, not merged and not
;; shadowed. `extend-type` in the same situation says "duplicate define: … already registered".
;; So the mechanism that CANNOT be extended silently accepts a redefinition, and the one that can
;; be extended refuses it. That is backwards, and it is the first thing to fix whatever is decided
;; about openness.
;;
;; FACT 2 (not a defect -- a design constraint): clause order is SEMANTICALLY SIGNIFICANT when two
;; clauses overlap. The two functions below hold the same two clauses in opposite orders and answer
;; differently for the same argument. That is what "first-match-wins" means, and it is why an
;; `extend-clause` is harder than `extend-type`: extension would turn a textual order, visible in
;; one form, into a LOAD order determined by the dependency graph.

(:wat::core::defsurface :d::Thing :- [T] :nature :wat::core::Struct
  :features [(name [self <- (:d::Thing :- [T])] -> :wat::core::String)])

(:wat::core::defstruct :d::A [])
(:wat::core::extend-type :d::A (:d::Thing :- [:wat::core::i64])
  (name [self] -> :wat::core::String "a"))

;; both clauses match an :d::A -- the concrete one and the surface one it satisfies
(:wat::core::defclause :d::specific-first
  ([x <- :d::A]                             -> :wat::core::String "concrete clause")
  ([x <- (:d::Thing :- [:wat::core::i64])]  -> :wat::core::String "surface clause"))

(:wat::core::defclause :d::general-first
  ([x <- (:d::Thing :- [:wat::core::i64])]  -> :wat::core::String "surface clause")
  ([x <- :d::A]                             -> :wat::core::String "concrete clause"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- the same argument, the same two clauses, opposite orders ----")
    (:wat::kernel::println (:wat::string::concat "specific first -> " (:d::specific-first (:d::A))))
    (:wat::kernel::println (:wat::string::concat "general first  -> " (:d::general-first (:d::A))))
    (:wat::kernel::println "  order decides, so overlap is resolved TEXTUALLY, not by specificity.")
    (:wat::kernel::println "  CLOS resolves the same overlap by computing the most specific")
    (:wat::kernel::println "  applicable method, which is exactly why CLOS methods can be open.")))
