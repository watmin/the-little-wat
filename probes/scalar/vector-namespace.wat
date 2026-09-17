;; probes/scalar/vector-namespace.wat — which type does the `:wat::vector::` namespace serve?
;;
;; Answer (F-108, measured 2026-09-16, wat-rs a3218644d): PersistentVector, and ONLY that. Every
;; one of the six verbs rejects a value of the type actually named `Vector`:
;;
;;   :wat::vector::length    :wat::vector::length: parameter #1 expects (:wat::core::PersistentVector …)
;;   :wat::vector::get       … expects (:wat::core::PersistentVector …)
;;   :wat::vector::empty?    … expects (:wat::core::PersistentVector …)
;;   :wat::vector::conj      … expects (:wat::core::PersistentVector …)
;;   :wat::vector::contains? … expects (:wat::core::PersistentVector …)
;;   :wat::vector::concat    :wat::core::PersistentVector/concat: parameter #1 expects (PersistentVector …)
;;
;; The last is the worst of the six, because the error names a verb the author never wrote.
;;
;; A plain `Vector` is served from `:wat::core::` instead -- `concat`, `conj`, `length`, `nth`,
;; `first`, `rest`, `mapv`, `filterv`. Those refusals are startup errors, so they are recorded
;; above rather than run; what runs below is the working pair of routes for each type.
;;
;; Found while porting SICP §2.2 (C-077), by reaching for `:wat::vector::concat` on a `Vector`,
;; which is the obvious thing to reach for and the wrong one.

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [v  (:wat::core::Vector :- [:wat::core::i64] 1 2)
                    pv (:wat::core::PersistentVector :- [:wat::core::i64] 1 2)]
    (:wat::core::do
      (:wat::kernel::println "---- the type named Vector: served from :wat::core:: ----")
      (:wat::kernel::println (:wat::string::concat "core::length  "
        (:wat::i64::to-string (:wat::core::length v))))
      (:wat::kernel::println (:wat::string::concat "core::concat  "
        (:wat::i64::to-string (:wat::core::length (:wat::core::concat v v)))))
      (:wat::kernel::println (:wat::string::concat "core::conj    "
        (:wat::i64::to-string (:wat::core::length (:wat::core::conj v 9)))))

      (:wat::kernel::println "---- the type named PersistentVector: served from :wat::vector:: ----")
      (:wat::kernel::println (:wat::string::concat "vector::length "
        (:wat::i64::to-string (:wat::vector::length pv))))
      (:wat::kernel::println (:wat::string::concat "vector::concat "
        (:wat::i64::to-string (:wat::vector::length (:wat::vector::concat pv pv)))))
      (:wat::kernel::println (:wat::string::concat "vector::conj   "
        (:wat::i64::to-string (:wat::vector::length (:wat::vector::conj pv 9)))))
      (:wat::kernel::println (:wat::string::concat "vector::contains? "
        (:wat::core::str (:wat::vector::contains? pv 1))))

      (:wat::kernel::println "---- so the namespace and the type do not share a name ----")
      (:wat::kernel::println "  :wat::vector::*  serves  PersistentVector  (6 verbs, all of them)")
      (:wat::kernel::println "  :wat::core::*    serves  Vector"))))
