;; probes/rational/laws.wat: wat has exact rationals, and a hole where they collapse.
;;
;; :wat::rational:: is five verbs (+ - * / to-f64) over a num_rational::BigRational, with reader
;; literal syntax (`1/2`, `-3/2`). It is named ZERO times across USER-GUIDE.md,
;; WAT-CHEATSHEET.md, CLOJURE-ROSETTA.md and docs/README.md -- a whole branch of the numeric
;; tower, with its own literal form, that no user-facing page mentions (the F-088 shape).
;;
;; The reader normalizes: 2/4 reads as 1/2, sign moves to the numerator, and a literal that
;; reduces to a whole number (4/2) is read as an i64 -- never a rational. That is deliberate and
;; documented in crates/wat-reader/src/ast.rs, and it is exactly Clojure's behaviour, verified
;; against clj 1.12.6 in the same session:
;;
;;              clojure                         wat
;;   2/4    ->  clojure.lang.Ratio  1/2         rational  1/2
;;   4/2    ->  java.lang.Long      2           i64       2
;;
;; So this file checks the thing rationals EXIST for -- exactness -- and then the hole.
;;
;; THE HOLE (F-090). wat/core.wat:118-120 declares `+` over rationals as
;; `([x <- rational y <- rational] -> :wat::core::rational ...)`, and the comment eight lines
;; above admits what actually happens: "this stone's pinned collapse: a BigRational result
;; reducing to a whole number becomes bigint". So the declared return type is rational and the
;; runtime value can be a bigint. Four of the five verbs were made lenient to absorb that.
;; `to-f64` was not -- so L6 below type-checks and dies at runtime.
;;
;; Expected: every line PASS except the one marked, which reports the runtime death.
;;
;; Run: wat probes/rational/laws.wat

(:wat::core::defn :rl::say [label <- :wat::core::String ok <- :wat::core::bool] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    (:wat::core::if ok "PASS  " "FAIL  ") label))))

(:wat::core::defn :rl::show [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] "      " label "  " v))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; L1 -- the reader reduces to lowest terms
    (:rl::say "L1 2/4 reads as 1/2" (:wat::core::= 2/4 1/2))
    ;; L2 -- EXACTNESS, the whole point. f64 cannot do this.
    (:rl::say "L2 1/3 + 1/3 + 1/3 = 1 exactly"
      (:wat::core::= (:wat::rational::+ (:wat::rational::+ 1/3 1/3) 1/3) 1))
    (:rl::say "L2 control: 0.1 + 0.2 /= 0.3 in f64"
      (:wat::core::not (:wat::core::= (:wat::f64::+ 0.1 0.2) 0.3)))
    ;; L3 -- field laws
    (:rl::say "L3 commutative" (:wat::core::= (:wat::rational::+ 1/3 1/4) (:wat::rational::+ 1/4 1/3)))
    (:rl::say "L3 associative"
      (:wat::core::= (:wat::rational::+ (:wat::rational::+ 1/3 1/4) 1/5)
                     (:wat::rational::+ 1/3 (:wat::rational::+ 1/4 1/5))))
    (:rl::say "L3 distributive"
      (:wat::core::= (:wat::rational::* 2/3 (:wat::rational::+ 1/4 1/5))
                     (:wat::rational::+ (:wat::rational::* 2/3 1/4) (:wat::rational::* 2/3 1/5))))
    (:rl::say "L3 x * (1/x) = 1" (:wat::core::= (:wat::rational::* 2/3 3/2) 1))
    ;; L4 -- arbitrary precision: no i64 overflow
    (:rl::show "L4 1/9223372036854775807 + itself ="
      (:wat::edn::write (:wat::rational::+ 1/9223372036854775807 1/9223372036854775807)))
    ;; L5 -- four verbs absorb a COLLAPSED (whole-valued) rational
    (:rl::say "L5 + absorbs a collapsed operand" (:wat::core::= (:wat::rational::+ (:wat::rational::+ 1/2 1/2) 1/2) 3/2))
    (:rl::say "L5 - absorbs" (:wat::core::= (:wat::rational::- (:wat::rational::+ 1/2 1/2) 1/2) 1/2))
    (:rl::say "L5 * absorbs" (:wat::core::= (:wat::rational::* (:wat::rational::+ 1/2 1/2) 3/4) 3/4))
    (:rl::say "L5 / absorbs" (:wat::core::= (:wat::rational::/ (:wat::rational::+ 1/2 1/2) 3/4) 4/3))
    ;; L6 -- to-f64 does NOT. The control proves it is the collapse, not the verb.
    (:rl::show "L6 to-f64 of an UNcollapsed rational" (:wat::edn::write (:wat::rational::to-f64 (:wat::rational::+ 1/4 1/4))))
    (:wat::kernel::println "      L6 to-f64 of a COLLAPSED rational -- F-090, uncomment to see it die:")
    (:wat::kernel::println "      (:wat::rational::to-f64 (:wat::rational::+ 1/2 1/2))")
    (:wat::kernel::println "        -> RuntimeError :wat::rational::to-f64: expected rational, got wat::core::bigint `1N`")
    ;; (:rl::show "L6" (:wat::edn::write (:wat::rational::to-f64 (:wat::rational::+ 1/2 1/2))))
    ))
