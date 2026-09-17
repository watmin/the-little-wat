;; eopl/ch05-cps-interpreter.wat — EOPL chapters 3 and 5: one language, two machines.
;;
;; Friedman & Wand build the LETREC language once and then change only how it is EXECUTED:
;; chapter 3 recurses directly on the host stack, chapter 5 makes the continuation a DATA
;; STRUCTURE and drives it from a loop. In a host with a growable stack that is a presentation
;; choice. In wat it is not, and this file measures why.
;;
;; F-099: a non-tail recursion past ~110000 frames SEGFAULTS, exit 139, empty stderr, no
;; wat-level error. A direct-style interpreter turns the INTERPRETED program's depth into wat's
;; depth, so that ceiling lands on the user's program. The CPS machine moves it into the heap.
;;
;;   non-tail interpreted recursion    direct (ch3)        CPS (ch5)
;;     depth 40000                     ok                  ok
;;     depth 50000                     SEGFAULT, exit 139  ok
;;     depth 300000                    --                  ok
;;
;; And one result that came as a surprise: wat's TCO is preserved THROUGH the direct interpreter.
;; A tail call in the interpreted language lands in tail position in `value-of`, so the host
;; collapses the frame too -- a tail-recursive interpreted program runs at any depth in EITHER
;; machine. The ceiling only appears for interpreted recursion that must return.
;;
;; Run: wat eopl/ch05-cps-interpreter.wat

(:wat::load-file! "lib/cps.wat")
(:wat::load-file! "lib/direct.wat")

(:wat::core::defn :c5::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; --- a battery both machines must agree on --------------------------------------------------
(:wat::core::defn :c5::e-arith [] -> :eopl::Exp
  (:eopl::Exp.Diff {:a (:eopl::Exp.Const {:n 10}) :b (:eopl::Exp.Const {:n 4})}))

(:wat::core::defn :c5::e-let [] -> :eopl::Exp
  (:eopl::Exp.Let {:name "x" :e (:eopl::Exp.Const {:n 7})
                   :body (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "x"}) :b (:eopl::Exp.Const {:n 2})})}))

(:wat::core::defn :c5::e-proc [] -> :eopl::Exp
  (:eopl::Exp.Call
    {:rator (:eopl::Exp.Proc {:param "y"
              :body (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "y"}) :b (:eopl::Exp.Const {:n 1})})})
     :rand (:eopl::Exp.Const {:n 100})}))

(:wat::core::defn :c5::e-if [] -> :eopl::Exp
  (:eopl::Exp.If {:c (:eopl::Exp.IsZero {:e (:eopl::Exp.Const {:n 0})})
                  :t (:eopl::Exp.Const {:n 1}) :f (:eopl::Exp.Const {:n 2})}))

;; letrec f(n) = if zero?(n) then 0 else -(f(-(n,1)), 0)  -- NOT tail recursive
(:wat::core::defn :c5::e-countdown [n <- :wat::core::i64] -> :eopl::Exp
  (:eopl::Exp.Letrec
    {:fname "f" :param "n"
     :fbody (:eopl::Exp.If
              {:c (:eopl::Exp.IsZero {:e (:eopl::Exp.Var {:name "n"})})
               :t (:eopl::Exp.Const {:n 0})
               :f (:eopl::Exp.Diff
                    {:a (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "f"})
                                          :rand (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "n"})
                                                                  :b (:eopl::Exp.Const {:n 1})})})
                     :b (:eopl::Exp.Const {:n 0})})})
     :body (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "f"}) :rand (:eopl::Exp.Const {:n n})})}))

(:wat::core::defn :c5::agree? [e <- :eopl::Exp] -> :wat::core::bool
  (:wat::core::= (:eopl::num-of (:eopl::run e)) (:eopl::num-of (:eopl::direct-run e))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:c5::say "arith   both machines agree" (:wat::core::if (:c5::agree? (:c5::e-arith)) "PASS" "FAIL"))
    (:c5::say "let     both machines agree" (:wat::core::if (:c5::agree? (:c5::e-let)) "PASS" "FAIL"))
    (:c5::say "proc    both machines agree" (:wat::core::if (:c5::agree? (:c5::e-proc)) "PASS" "FAIL"))
    (:c5::say "if      both machines agree" (:wat::core::if (:c5::agree? (:c5::e-if)) "PASS" "FAIL"))
    (:c5::say "letrec  both machines agree" (:wat::core::if (:c5::agree? (:c5::e-countdown 500)) "PASS" "FAIL"))
    (:wat::kernel::println "---- non-tail interpreted recursion, depth the CPS machine reaches ----")
    (:c5::say "CPS at depth 60000 (past the direct ceiling)"
      (:wat::i64::to-string (:eopl::num-of (:eopl::run (:c5::e-countdown 60000)))))
    (:wat::kernel::println "   (direct segfaults between 40000 and 50000 -- F-099, measured separately;")
    (:wat::kernel::println "    it is not run here because a probe that segfaults takes the suite with it)")))
