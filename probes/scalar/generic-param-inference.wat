;; probes/scalar/generic-param-inference.wat — how a generic struct's type parameter gets bound,
;; and the annotation that is silently ignored (F-107).
;;
;; Found while porting EOPL ch2 (C-074), whose dictionary is exactly the shape below: a generic
;; struct holding a value of T and a function over T.
;;
;; Measured 2026-09-16, wat-rs a3218644d. Each row below is a SEPARATE single-file run, because
;; the failures are startup errors; only the working shapes can live in one file.
;;
;;   (:p::Ops :seed (:p::E.A {}) :step (fn [x <- :p::E] -> :p::E x))
;;     REFUSED: ":p::Ops: parameter #2 expects [:p::E.A :-> :p::E.A]; got [:p::E :-> :p::E]"
;;     T was bound from field #1 to the VARIANT type :p::E.A, not to the enum :p::E.
;;     The enclosing fn's declared return type, (:p::Ops :- [:p::E]), did not pin it.
;;     The diagnostic blames field #2, which is the field that was written correctly.
;;
;;   (:p::Ops :- [:p::E] :seed (:p::E.A {}) :step ...)        REFUSED, identical message.
;;   (:p::Ops :- [:wat::core::i64] :seed (:p::E.A {}) ...)    REFUSED, IDENTICAL message.
;;     A deliberately wrong explicit type argument changes nothing, so the annotation at a
;;     kwargs construction site is parsed and DISCARDED. That is the part that matters: an
;;     annotation with no effect and no diagnostic is worse than one that is rejected.
;;
;; The two shapes that DO work are below, and they are both accidents of ordering rather than
;; anything a user would reason their way to.

(:wat::core::defenum :p::E :wat::enum::Pure :A [] :B [n <- :wat::core::i64])

;; WORKS: the value goes through a function whose return type is declared, pinning T to the enum
(:wat::core::defstruct :p::Ops :- [T] [seed <- T  step <- [T :-> T]])
(:wat::core::defn :p::empty [] -> :p::E (:p::E.A {}))
(:wat::core::defn :p::mk-via-fn [] -> (:p::Ops :- [:p::E])
  (:p::Ops :seed (:p::empty)
           :step (:wat::core::fn [x <- :p::E] -> :p::E x)))

;; WORKS: the FUNCTION field is declared first, so T is pinned from its annotation before the
;; bare variant literal is seen. Same struct, same values, different field order.
(:wat::core::defstruct :p::Ops2 :- [T] [step <- [T :-> T]  seed <- T])
(:wat::core::defn :p::mk-reordered [] -> (:p::Ops2 :- [:p::E])
  (:p::Ops2 :step (:wat::core::fn [x <- :p::E] -> :p::E x)
            :seed (:p::E.A {})))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- generic parameter inference ----")
    (:wat::kernel::println "seed via a declared-return fn   OK")
    (:wat::kernel::println "function field declared first   OK")
    (:wat::kernel::println "bare variant literal first      REFUSED (T binds to the variant)")
    (:wat::kernel::println "explicit :- [T] at the ctor     IGNORED (a wrong one errors the same)")
    ;; prove both working constructions really exist and are usable
    (:wat::kernel::println
      (:wat::string::concat "both built, step is identity:  "
        (:wat::core::match ((:p::Ops/step (:p::mk-via-fn)) (:p::empty))
          [:p::E.A {} "A"]
          [:p::E.B {:n n} "B"])
        (:wat::core::match ((:p::Ops2/step (:p::mk-reordered)) (:p::empty))
          [:p::E.A {} "A"]
          [:p::E.B {:n n} "B"])))))
