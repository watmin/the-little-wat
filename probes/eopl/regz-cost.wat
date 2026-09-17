;; probes/eopl/regz-cost.wat — what registerization COSTS in wat.
;;
;; Same language, same continuations, same interpreted program, two shapes:
;;   :eopl::run  — REGISTERIZED: `step : State -> State` plus a trampoline (eopl/lib/cps.wat).
;;   :rz::run    — BEFORE registerization: `value-of-k` and `apply-cont` mutually tail-calling.
;;
;; EOPL motivates registerization as a step toward a machine. In wat the registerized form has to
;; ALLOCATE a State enum on every transition, because `step` must return the next state; the
;; mutually-recursive form allocates nothing and just tail-calls. So the prediction is that
;; registerization costs here. Min of N runs, both arms doing identical interpreted work.

(:wat::load-file! "../../eopl/lib/regz.wat")

(:wat::core::defn :rc::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))

;; letrec f(n) = if zero?(n) then 0 else -(n, -(0, f(-(n,1)))) in (f N)  — non-tail, so the
;; continuation chain actually grows and both machines do real work on it.
(:wat::core::defn :rc::prog [n <- :wat::core::i64] -> :eopl::Exp
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

(:wat::core::defn :rc::best-reg [e <- :eopl::Exp reps <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= reps 0) best
    (:wat::core::let [t0 (:rc::now)
                      v (:eopl::run e)
                      dt (:wat::core::- (:rc::now) t0)]
      (:rc::best-reg e (:wat::core::- reps 1)
        (:wat::core::if (:wat::core::< dt best) dt best)))))

(:wat::core::defn :rc::best-mut [e <- :eopl::Exp reps <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= reps 0) best
    (:wat::core::let [t0 (:rc::now)
                      v (:rz::run e)
                      dt (:wat::core::- (:rc::now) t0)]
      (:rc::best-mut e (:wat::core::- reps 1)
        (:wat::core::if (:wat::core::< dt best) dt best)))))

(:wat::core::defn :rc::row [n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let [e (:rc::prog n)
                    big 999999999999
                    reg (:rc::best-reg e 5 big)
                    mut (:rc::best-mut e 5 big)]
    (:wat::kernel::println
      (:wat::string::concat
        "n=" (:wat::i64::to-string n)
        "  registerized(step/drive)=" (:wat::i64::to-string (:wat::core::/ reg 1000)) " us"
        "   mutual-tail-calls=" (:wat::i64::to-string (:wat::core::/ mut 1000)) " us"
        "   answers " (:wat::core::if (:wat::core::= (:eopl::num-of (:eopl::run e))
                                                    (:eopl::num-of (:rz::run e)))
                        "AGREE" "DIFFER")))))

;; ORDER CONTROL: the registerized arm runs first in every row above, so it could be paying a
;; cold-start cost the second arm avoids. This row runs the two arms in the opposite order. If
;; the gap survives the swap, it is the allocation and not the ordering.
(:wat::core::defn :rc::row-swapped [n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let [e (:rc::prog n)
                    big 999999999999
                    mut (:rc::best-mut e 5 big)
                    reg (:rc::best-reg e 5 big)]
    (:wat::kernel::println
      (:wat::string::concat
        "n=" (:wat::i64::to-string n)
        "  mutual FIRST=" (:wat::i64::to-string (:wat::core::/ mut 1000)) " us"
        "   registerized SECOND=" (:wat::i64::to-string (:wat::core::/ reg 1000)) " us"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- registerization, priced (min of 5) ----")
    (:rc::row 200)
    (:rc::row 1000)
    (:rc::row 4000)
    (:wat::kernel::println "---- same thing with the arms swapped ----")
    (:rc::row-swapped 200)
    (:rc::row-swapped 1000)))
