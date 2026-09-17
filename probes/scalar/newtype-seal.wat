;; probes/scalar/newtype-seal.wat — does wat's `newtype` SEAL a representation, or only rename it?
;;
;; EOPL chapter 8 (C-071) draws the line: `opaque t` means the outside gets a NAME and nothing
;; else -- no constructor, no accessor. This probe asks what the wat spelling would be.
;;
;; Result (F-106): `newtype` does the DISTINCTNESS half properly -- arithmetic on the type is
;; refused, and a raw i64 is refused where the type is wanted, both at startup. But the auto-
;; minted constructor (the bare name) and accessor (`<Name>/0`) resolve from ANY namespace, so
;; the representation is public: anyone can unwrap and rewrap. Distinctness without encapsulation.
;;
;; The two rejections cannot live in this file -- they are startup errors, so they would stop it
;; running. They are recorded in F-106 with their verbatim messages, from single-expression runs.

(:wat::core::newtype :ints::T :wat::core::i64)

(:wat::core::defn :ints::zero [] -> :ints::T (:ints::T 0))
(:wat::core::defn :ints::succ [x <- :ints::T] -> :ints::T
  ;; the module's own code unwraps through the same public accessor an outsider would use
  (:ints::T (:wat::core::- (:ints::T/0 x) -1)))

;; a typealias, for contrast: transparent in both directions
(:wat::core::typealias :alias::T :wat::core::i64)
(:wat::core::defn :alias::zero [] -> :alias::T 0)

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- newtype: distinct, but not sealed ----")
    ;; :user:: is a DIFFERENT namespace from :ints:: and reaches straight through
    (:wat::kernel::println
      (:wat::string::concat "unwrapped from :user::        "
        (:wat::i64::to-string (:ints::T/0 (:ints::zero)))))
    (:wat::kernel::println
      (:wat::string::concat "rewrapped from :user::        "
        (:wat::i64::to-string (:ints::T/0 (:ints::T (:wat::core::+ 41 1))))))
    (:wat::kernel::println
      (:wat::string::concat "through the module's own succ "
        (:wat::i64::to-string (:ints::T/0 (:ints::succ (:ints::zero))))))

    (:wat::kernel::println "---- typealias: transparent, as expected ----")
    (:wat::kernel::println
      (:wat::string::concat "arithmetic straight through   "
        (:wat::i64::to-string (:wat::core::- (:alias::zero) 1))))

    (:wat::kernel::println "---- refused at startup, so recorded rather than run (F-106) ----")
    (:wat::kernel::println "  (- zero 1)   no clause of :wat::core::- matches types [:ints::T, :wat::core::i64]")
    (:wat::kernel::println "  (succ 41)    :ints::succ: parameter #1 expects :ints::T; got :wat::core::i64")
    (:wat::kernel::println "  and F-030 still open: printing a newtype panics the runtime, exit 2")))
