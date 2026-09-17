;; eopl/ch08-modules.wat — EOPL chapter 8: SIMPLE-MODULES and OPAQUE-TYPES.
;;
;; The chapter's subject is an ABSTRACTION BOUNDARY the type checker enforces. Two modules differ
;; in one word -- `opaque t` versus `transparent t = int` -- and that word decides whether the
;; outside may do arithmetic on the module's values.
;;
;; NEXT.md flagged this chapter as the closest to wat's own design, and the port says why: wat has
;; namespaces and `defsurface`, which are the module half, and no way at all to spell the opaque
;; half. See FINDINGS C-071.

(:wat::load-file! "lib/modules.wat")

(:wat::core::defn :m8::say [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :m8::report [r <- :md::Res] -> :wat::core::String
  (:wat::core::match r
    [:md::Res.Ok {:ty ty} (:wat::string::concat "ACCEPTED : " (:md::show ty))]
    [:md::Res.Err {:msg m} (:wat::string::concat "REJECTED : " m)]))

(:wat::core::defn :m8::check-report [c <- :md::Check] -> :wat::core::String
  (:wat::core::match c
    [:md::Check.Fine {} "well typed"]
    [:md::Check.Bad {:msg m} (:wat::string::concat "REJECTED : " m)]))

;; ---- the body both modules share: t is int, zero is 0, succ adds one, to-int reveals ----
(:wat::core::defn :m8::body [] -> :md::Defns
  (:md::Defns.FCons
    {:d (:md::Defn.TypeDf {:name "t" :ty (:md::Type.TInt {})})
     :rest (:md::Defns.FCons
             {:d (:md::Defn.ValDf {:name "zero" :ty (:md::Type.TQual {:m "ints" :t "t"})
                                   :e (:md::Exp.Lit {:n 0})})
              :rest (:md::Defns.FCons
                      {:d (:md::Defn.ValDf
                            {:name "succ"
                             :ty (:md::Type.TArrow {:a (:md::Type.TQual {:m "ints" :t "t"})
                                                    :r (:md::Type.TQual {:m "ints" :t "t"})})
                             :e (:md::Exp.Proc {:param "x" :pty (:md::Type.TQual {:m "ints" :t "t"})
                                                :body (:md::Exp.Diff {:a (:md::Exp.Var {:name "x"})
                                                                      :b (:md::Exp.Lit {:n -1})})})})
                       :rest (:md::Defns.FCons
                               {:d (:md::Defn.ValDf
                                     {:name "to-int"
                                      :ty (:md::Type.TArrow {:a (:md::Type.TQual {:m "ints" :t "t"})
                                                             :r (:md::Type.TInt {})})
                                      :e (:md::Exp.Proc {:param "x"
                                                         :pty (:md::Type.TQual {:m "ints" :t "t"})
                                                         :body (:md::Exp.Var {:name "x"})})})
                                :rest (:md::Defns.FNil {})})})})}))

(:wat::core::defn :m8::iface [sealed <- :wat::core::bool] -> :md::Decls
  (:md::Decls.DCons
    {:d (:wat::core::if sealed
          (:md::Decl.OpaqueD {:name "t"})
          (:md::Decl.TransD {:name "t" :ty (:md::Type.TInt {})}))
     :rest (:md::Decls.DCons
             {:d (:md::Decl.ValD {:name "zero" :ty (:md::Type.TQual {:m "ints" :t "t"})})
              :rest (:md::Decls.DCons
                      {:d (:md::Decl.ValD
                            {:name "succ"
                             :ty (:md::Type.TArrow {:a (:md::Type.TQual {:m "ints" :t "t"})
                                                    :r (:md::Type.TQual {:m "ints" :t "t"})})})
                       :rest (:md::Decls.DCons
                               {:d (:md::Decl.ValD
                                     {:name "to-int"
                                      :ty (:md::Type.TArrow {:a (:md::Type.TQual {:m "ints" :t "t"})
                                                             :r (:md::Type.TInt {})})})
                                :rest (:md::Decls.DNil {})})})})}))

(:wat::core::defn :m8::module [sealed <- :wat::core::bool] -> :md::Module
  (:md::Module.Mod {:name "ints" :iface (:m8::iface sealed) :body (:m8::body)}))

(:wat::core::defn :m8::menv [sealed <- :wat::core::bool] -> :md::MEnv
  (:md::seal (:m8::module sealed) (:md::MEnv.MNil {})))

(:wat::core::defn :m8::check [e <- :md::Exp sealed <- :wat::core::bool] -> :wat::core::String
  (:m8::report (:md::type-of e (:md::TEnv.TNil {}) (:m8::menv sealed))))

;; what the functor DEMANDS of its argument: zero and succ, at plain int
(:wat::core::defn :m8::required [] -> :md::Decls
  (:md::Decls.DCons
    {:d (:md::Decl.ValD {:name "zero" :ty (:md::Type.TInt {})})
     :rest (:md::Decls.DCons
             {:d (:md::Decl.ValD {:name "succ"
                                  :ty (:md::Type.TArrow {:a (:md::Type.TInt {})
                                                         :r (:md::Type.TInt {})})})
              :rest (:md::Decls.DNil {})})}))

;; module-proc (m : required) => module `twice` exporting `two : int` = (succ (succ zero))
(:wat::core::defn :m8::functor [] -> :md::MProc
  (:md::MProc.MP
    {:param "m" :param-iface (:m8::required)
     :result-name "twice"
     :result-iface (:md::Decls.DCons
                     {:d (:md::Decl.ValD {:name "two" :ty (:md::Type.TInt {})})
                      :rest (:md::Decls.DNil {})})
     :body (:md::Defns.FCons
             {:d (:md::Defn.ValDf
                   {:name "two" :ty (:md::Type.TInt {})
                    :e (:md::Exp.Call
                         {:rator (:md::Exp.QualVar {:m "m" :name "succ"})
                          :rand (:md::Exp.Call {:rator (:md::Exp.QualVar {:m "m" :name "succ"})
                                                :rand (:md::Exp.QualVar {:m "m" :name "zero"})})})})
              :rest (:md::Defns.FNil {})})}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- EOPL ch8: SIMPLE-MODULES ----")

    ;; both modules are well typed: the BODY is checked with t transparent
    (:m8::say "opaque module is well typed     "
      (:m8::check-report (:md::check-module (:m8::module true) (:md::MEnv.MNil {}))))
    (:m8::say "transparent module is well typed"
      (:m8::check-report (:md::check-module (:m8::module false) (:md::MEnv.MNil {}))))

    ;; a name the interface does not export is not there, however plainly the body defines it
    (:m8::say "from ints take nope             "
      (:m8::check (:md::Exp.QualVar {:m "ints" :name "nope"}) true))

    (:wat::kernel::println "---- the same four expressions under both interfaces ----")
    (:wat::kernel::println "(the ONLY difference is `opaque t` vs `transparent t = int`)")

    ;; 1. take the abstract value: fine either way, but the TYPE printed differs
    (:m8::say "  opaque      from ints take zero  " (:m8::check (:md::Exp.QualVar {:m "ints" :name "zero"}) true))
    (:m8::say "  transparent from ints take zero  " (:m8::check (:md::Exp.QualVar {:m "ints" :name "zero"}) false))

    ;; 2. ARITHMETIC on it — the chapter's whole point
    (:m8::say "  opaque      -(zero, 1)           "
      (:m8::check (:md::Exp.Diff {:a (:md::Exp.QualVar {:m "ints" :name "zero"})
                                  :b (:md::Exp.Lit {:n 1})}) true))
    (:m8::say "  transparent -(zero, 1)           "
      (:m8::check (:md::Exp.Diff {:a (:md::Exp.QualVar {:m "ints" :name "zero"})
                                  :b (:md::Exp.Lit {:n 1})}) false))

    ;; 3. the module's OWN operations always work — abstraction hides, it does not forbid
    (:m8::say "  opaque      (succ zero)          "
      (:m8::check (:md::Exp.Call {:rator (:md::Exp.QualVar {:m "ints" :name "succ"})
                                  :rand (:md::Exp.QualVar {:m "ints" :name "zero"})}) true))
    (:m8::say "  opaque      (to-int (succ zero)) "
      (:m8::check (:md::Exp.Call
                    {:rator (:md::Exp.QualVar {:m "ints" :name "to-int"})
                     :rand (:md::Exp.Call {:rator (:md::Exp.QualVar {:m "ints" :name "succ"})
                                           :rand (:md::Exp.QualVar {:m "ints" :name "zero"})})}) true))

    ;; 4. and a raw int cannot be smuggled in where the abstract type is wanted
    (:m8::say "  opaque      (succ 0)             "
      (:m8::check (:md::Exp.Call {:rator (:md::Exp.QualVar {:m "ints" :name "succ"})
                                  :rand (:md::Exp.Lit {:n 0})}) true))
    (:m8::say "  transparent (succ 0)             "
      (:m8::check (:md::Exp.Call {:rator (:md::Exp.QualVar {:m "ints" :name "succ"})
                                  :rand (:md::Exp.Lit {:n 0})}) false))

    ;; ---- 8.4: PARAMETERIZED MODULES ----
    ;; `to-int-twice` takes ANY module exporting `zero : int` and `succ : (int -> int)`.
    ;; It is checked ONCE, against the parameter's interface -- not once per application.
    (:wat::kernel::println "---- ch8.4: a parameterized module is checked once, against its parameter's interface ----")
    (:m8::say "functor body type-checks       "
      (:m8::check-report (:md::check-mproc (:m8::functor) (:md::MEnv.MNil {}))))
    (:m8::say "transparent module satisfies it"
      (:m8::check-report (:md::satisfies? (:m8::module false) (:m8::required) (:md::MEnv.MNil {}))))
    ;; and the OPAQUE module does not -- its `zero` is `ints.t`, not `int`. Same body, same
    ;; values; the seal is the whole difference.
    (:m8::say "opaque module does NOT         "
      (:m8::check-report (:md::satisfies? (:m8::module true) (:m8::required) (:md::MEnv.MNil {}))))

    ;; a module that promises more than it delivers is rejected at the seal, not at the use
    (:wat::kernel::println "---- the interface is a promise the body must keep ----")
    (:m8::say "body missing a promised name    "
      (:m8::check-report
        (:md::check-module
          (:md::Module.Mod {:name "ints"
                            :iface (:md::Decls.DCons
                                     {:d (:md::Decl.ValD {:name "missing" :ty (:md::Type.TInt {})})
                                      :rest (:md::Decls.DNil {})})
                            :body (:m8::body)})
          (:md::MEnv.MNil {}))))))
