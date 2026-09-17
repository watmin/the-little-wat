;; probes/eopl/cps6-depth.wat — the depth ladder for EOPL chapter 6.
;;
;; Run: wat probes/eopl/cps6-depth.wat <direct|cps> <n>
;;
;; One interpreted program, `sum(n) = n + sum(n-1)`, written so the recursive call is NOT in tail
;; position (its result is consumed by a Diff). Run under the SAME direct interpreter both ways:
;; as written, and after :c6::cps-of-program. F-099 predicts the first dies; C-061 (wat's TCO
;; survives the interpreter) predicts the second does not.
;;
;; A segfault is the expected outcome of the `direct` arm past some depth, so each rung runs in
;; its own process and the driver reads the exit status — never through a pipe (R-005).

(:wat::load-file! "../../eopl/lib/letrec.wat")
(:wat::load-file! "../../eopl/lib/direct.wat")
(:wat::load-file! "../../eopl/lib/cps6.wat")

;; letrec f(n) = if zero?(n) then 0 else -(n, -(0, f(-(n,1)))) in (f N)
(:wat::core::defn :p::prog [n <- :wat::core::i64] -> :eopl::Exp
  (:eopl::Exp.Letrec
    {:fname "f" :param "n"
     :fbody (:eopl::Exp.If
              {:c (:eopl::Exp.IsZero {:e (:eopl::Exp.Var {:name "n"})})
               :t (:eopl::Exp.Const {:n 0})
               :f (:eopl::Exp.Diff
                    {:a (:eopl::Exp.Var {:name "n"})
                     :b (:eopl::Exp.Diff
                          {:a (:eopl::Exp.Const {:n 0})
                           :b (:eopl::Exp.Call
                                {:rator (:eopl::Exp.Var {:name "f"})
                                 :rand (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "n"})
                                                         :b (:eopl::Exp.Const {:n 1})})})})})})
     :body (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "f"})
                             :rand (:eopl::Exp.Const {:n n})})}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [args (:wat::runtime::argv)
                    mode (:wat::core::if (:wat::core::> (:wat::core::length args) 2)
                           (:wat::core::nth args 2) "cps")
                    ;; :wat::string::to-i64 answers an Option, so the argument needs unwrapping
                    n (:wat::core::if (:wat::core::> (:wat::core::length args) 3)
                        (:wat::core::match (:wat::string::to-i64 (:wat::core::nth args 3))
                          [:wat::core::Option.Some {:value v} v]
                          [:wat::core::Option.None {} 100])
                        100)
                    src (:p::prog n)
                    e (:wat::core::if (:wat::core::= mode "direct")
                        src (:c6::cps-of-program src))]
    (:wat::kernel::println
      (:wat::string::concat mode " n=" (:wat::i64::to-string n)
        " => " (:wat::i64::to-string (:eopl::num-of (:eopl::direct-run e)))))))
