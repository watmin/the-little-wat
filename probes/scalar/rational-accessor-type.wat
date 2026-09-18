;; probes/scalar/rational-accessor-type.wat — `:wat::rational::numerator` is declared to return an
;; i64 and can return a bigint, and nothing reports it (F-111).
;;
;; Found while choosing a Euler problem to press the rational surface (C-093). Measured
;; 2026-09-17, wat-rs a3218644d.
;;
;; The BEHAVIOUR is deliberate and good. `src/intrinsic/rational.rs:218-220` says so:
;;   "Renders as :wat::core::i64 when it fits; :wat::core::bigint otherwise (never silently
;;    truncated)."
;; Refusing to truncate is the right call.
;;
;; The ANNOTATION eleven lines below it does not say that:
;;   "@ret     :wat::core::i64 the numerator of `n`"
;;
;; So the checker believes `i64`, and a bigint flows through a parameter declared `i64` into a
;; function declared to RETURN `i64`, with no error at check time or at run time. Exactly two
;; intrinsics have this shape -- `numerator` and `denominator` -- and both are in rational.rs.

(:wat::core::defn :r::takes-i64 [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ n 0))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [small 3/4
                    ;; 2^64, which no i64 can hold
                    huge (:wat::bigint::* (:wat::i64::to-bigint 4294967296) (:wat::i64::to-bigint 4294967296))
                    r (:wat::bigint::to-rational huge)]
    (:wat::core::do
      (:wat::kernel::println "---- the declared case: small enough to be an i64 ----")
      (:wat::kernel::println (:wat::string::concat "  numerator 3/4          "
        (:wat::core::str (:wat::rational::numerator small))))
      (:wat::kernel::println (:wat::string::concat "  through an i64 function "
        (:wat::core::str (:r::takes-i64 (:wat::rational::numerator small)))))

      (:wat::kernel::println "---- the undeclared case: a numerator past i64 ----")
      (:wat::kernel::println (:wat::string::concat "  the rational           " (:wat::core::str r)))
      ;; the checker accepts this call; the value arriving is a bigint
      (:wat::kernel::println (:wat::string::concat "  through the SAME i64 function "
        (:wat::core::str (:r::takes-i64 (:wat::rational::numerator r)))))
      (:wat::kernel::println "  -- the trailing N says that is a bigint, out of a function whose")
      (:wat::kernel::println "     signature is [n <- :wat::core::i64] -> :wat::core::i64.")

      (:wat::kernel::println "---- what the source says ----")
      (:wat::kernel::println "  rational.rs:219  \"i64 when it fits; bigint otherwise (never")
      (:wat::kernel::println "                    silently truncated)\"   <- deliberate, and right")
      (:wat::kernel::println "  rational.rs:229  \"@ret :wat::core::i64\"  <- and the checker believes this")
      (:wat::kernel::println "  the same pair at 242 / 252 for `denominator`; no other intrinsic does it"))))
