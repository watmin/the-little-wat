;; eopl/lib/regz.wat — EOPL chapter 6.5: the interpreter BEFORE registerization.
;;
;; `eopl/lib/cps.wat` is already the registerized machine: one `step : State -> State` over an
;; explicit state, driven by a trampoline. EOPL reaches that form from a different one — two
;; MUTUALLY RECURSIVE procedures, `value-of/k` and `apply-cont`, each tail-calling the other.
;; Registerization is the move from the second to the first, and the book motivates it as a step
;; toward a machine with no procedure calls at all.
;;
;; This file is the "before", over the SAME Cont/Exp/Env/Val types, so the two can be compared on
;; the same program. Two things are worth measuring, and they pull opposite ways:
;;
;;   1. Does wat's TCO span MUTUAL tail calls, or only self-calls? If only self-calls, this file
;;      cannot run deep and wat FORCES registerization. (Measured separately: mutual TCO holds to
;;      10,000,000 — see probes/eopl/mutual-tco.wat. So it is not forced.)
;;   2. The registerized form must ALLOCATE a State enum on every transition, because `step` has
;;      to *return* the next state. The mutually-recursive form allocates nothing — it just tail
;;      calls. So in wat, registerization should cost, not save.

(:wat::load-file! "cps.wat")

(:wat::core::defn :rz::apply-cont [k <- :eopl::Cont v <- :eopl::Val] -> :eopl::Val
  (:wat::core::match k
    [:eopl::Cont.End {} v]
    [:eopl::Cont.ZeroK {:k k2}
      (:rz::apply-cont k2 (:eopl::Val.Bool {:b (:wat::core::= 0 (:eopl::num-of v))}))]
    [:eopl::Cont.LetK {:name name :body body :env env :k k2}
      (:rz::value-of-k body (:eopl::Env.Extend {:name name :v v :rest env}) k2)]
    [:eopl::Cont.IfK {:t t :f f :env env :k k2}
      (:wat::core::if (:eopl::truthy? v)
        (:rz::value-of-k t env k2)
        (:rz::value-of-k f env k2))]
    [:eopl::Cont.Diff1K {:b b :env env :k k2}
      (:rz::value-of-k b env (:eopl::Cont.Diff2K {:v1 v :k k2}))]
    [:eopl::Cont.Diff2K {:v1 v1 :k k2}
      (:rz::apply-cont k2 (:eopl::Val.Num {:n (:wat::core::- (:eopl::num-of v1) (:eopl::num-of v))}))]
    [:eopl::Cont.RatorK {:rand rand :env env :k k2}
      (:rz::value-of-k rand env (:eopl::Cont.RandK {:f v :k k2}))]
    [:eopl::Cont.RandK {:f f :k k2}
      (:wat::core::match f
        [:eopl::Val.Clo {:param param :body body :env cenv}
          (:rz::value-of-k body (:eopl::Env.Extend {:name param :v v :rest cenv}) k2)]
        [:eopl::Val.Num {:n n} (:eopl::Val.Num {:n -998})]
        [:eopl::Val.Bool {:b b} (:eopl::Val.Num {:n -998})])]))

(:wat::core::defn :rz::value-of-k
  [e <- :eopl::Exp env <- :eopl::Env k <- :eopl::Cont] -> :eopl::Val
  (:wat::core::match e
    [:eopl::Exp.Const {:n n} (:rz::apply-cont k (:eopl::Val.Num {:n n}))]
    [:eopl::Exp.Var {:name name} (:rz::apply-cont k (:eopl::apply-env env name))]
    [:eopl::Exp.Proc {:param param :body body}
      (:rz::apply-cont k (:eopl::Val.Clo {:param param :body body :env env}))]
    [:eopl::Exp.Diff {:a a :b b}
      (:rz::value-of-k a env (:eopl::Cont.Diff1K {:b b :env env :k k}))]
    [:eopl::Exp.IsZero {:e inner}
      (:rz::value-of-k inner env (:eopl::Cont.ZeroK {:k k}))]
    [:eopl::Exp.If {:c c :t t :f f}
      (:rz::value-of-k c env (:eopl::Cont.IfK {:t t :f f :env env :k k}))]
    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:rz::value-of-k rhs env (:eopl::Cont.LetK {:name name :body body :env env :k k}))]
    [:eopl::Exp.Call {:rator rator :rand rand}
      (:rz::value-of-k rator env (:eopl::Cont.RatorK {:rand rand :env env :k k}))]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:rz::value-of-k body
        (:eopl::Env.ExtendRec {:fname fname :param param :fbody fbody :rest env}) k)]))

(:wat::core::defn :rz::run [e <- :eopl::Exp] -> :eopl::Val
  (:rz::value-of-k e (:eopl::Env.Empty {}) (:eopl::Cont.End {})))
