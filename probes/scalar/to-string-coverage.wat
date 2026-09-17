;; probes/scalar/to-string-coverage.wat — which scalars can be shown, and through which door.
;;
;; F-060 originally claimed (a) every scalar but bigint has a `to-string`, and (b) a bigint's
;; digits come only from :wat::edn::write. Both are too narrow. This probe is the evidence for
;; the correction: :wat::core::str and :wat::core::show answer the same digits, and the types
;; that actually lack a to-string are the two arbitrary-precision ones, bigint and rational.

(:wat::core::defn :p::row [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- the three generic doors, on every scalar that has a namespace ----")
    ;; i64 and f64 have a to-string; they also go through str/show
    (:p::row "i64      to-string " (:wat::i64::to-string 42))
    (:p::row "i64      str       " (:wat::core::str 42))
    (:p::row "f64      to-string " (:wat::f64::to-string 1.5))
    (:p::row "f64      str       " (:wat::core::str 1.5))
    ;; bigint: NO to-string. str/show/edn all answer the same N-suffixed digits.
    (:p::row "bigint   str       " (:wat::core::str (:wat::i64::to-bigint 3)))
    (:p::row "bigint   show      " (:wat::core::show (:wat::i64::to-bigint 3)))
    (:p::row "bigint   edn::write" (:wat::edn::write (:wat::i64::to-bigint 3)))
    ;; and full digits, not scientific notation, on a number f64 cannot hold
    (:p::row "bigint   str 2^64  "
      (:wat::core::str (:wat::bigint::* (:wat::i64::to-bigint 4294967296)
                                        (:wat::i64::to-bigint 4294967296))))
    ;; rational: NO to-string either — the second arbitrary-precision type
    (:p::row "rational str       " (:wat::core::str (:wat::i64::to-rational 3)))
    (:p::row "rational show      " (:wat::core::show (:wat::i64::to-rational 3)))

    (:wat::kernel::println "---- str vs show differ on a String, and on nothing else here ----")
    (:p::row "String   str       " (:wat::core::str "hi"))
    (:p::row "String   show      " (:wat::core::show "hi"))
    (:p::row "bool     str       " (:wat::core::str (:wat::core::> 3 2)))
    (:p::row "bool     show      " (:wat::core::show (:wat::core::> 3 2)))

    ;; Recorded so the correction is not mistaken for a defect: a keyword is NOT a bool.
    ;; `(:wat::core::if :wat::core::true 1 0)` is a type-check error, not a truthy keyword:
    ;;   ":wat::core::if: parameter cond expects :wat::core::bool; got :wat::core::keyword"
    ;; wat is right; the bool literal is bare `true`. Checked 2026-09-16, wat-rs a3218644d.
    (:wat::kernel::println "---- absent to-string verbs (unresolved at startup, checked by hand) ----")
    (:wat::kernel::println "bigint::to-string  ABSENT   rational::to-string  ABSENT")
    (:wat::kernel::println "registered to-string verbs are exactly: i64 f64 keyword uuid")))
