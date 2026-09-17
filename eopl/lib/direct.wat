;; eopl/lib/direct.wat — EOPL chapter 3's interpreter: direct recursion on the host stack.
;; Every nested expression is a nested `:eopl::value-of` call, so the interpreted program's depth
;; becomes wat's depth -- and F-099 says that segfaults past ~110000 frames, silently.

(:wat::load-file! "letrec.wat")

(:wat::core::defn :eopl::value-of [e <- :eopl::Exp env <- :eopl::Env] -> :eopl::Val
  (:wat::core::match e
    [:eopl::Exp.Const {:n n} (:eopl::Val.Num {:n n})]
    [:eopl::Exp.Var {:name name} (:eopl::apply-env env name)]
    [:eopl::Exp.Diff {:a a :b b}
      (:eopl::Val.Num {:n (:wat::core::- (:eopl::num-of (:eopl::value-of a env))
                                         (:eopl::num-of (:eopl::value-of b env)))})]
    [:eopl::Exp.IsZero {:e inner}
      (:eopl::Val.Bool {:b (:wat::core::= 0 (:eopl::num-of (:eopl::value-of inner env)))})]
    [:eopl::Exp.If {:c c :t t :f f}
      (:wat::core::if (:eopl::truthy? (:eopl::value-of c env))
        (:eopl::value-of t env) (:eopl::value-of f env))]
    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:eopl::value-of body (:eopl::Env.Extend {:name name :v (:eopl::value-of rhs env) :rest env}))]
    [:eopl::Exp.Proc {:param param :body body}
      (:eopl::Val.Clo {:param param :body body :env env})]
    [:eopl::Exp.Call {:rator rator :rand rand}
      (:wat::core::match (:eopl::value-of rator env)
        [:eopl::Val.Clo {:param param :body body :env cenv}
          (:eopl::value-of body (:eopl::Env.Extend {:name param :v (:eopl::value-of rand env) :rest cenv}))]
        [:eopl::Val.Num {:n n} (:eopl::Val.Num {:n -998})]
        [:eopl::Val.Bool {:b b} (:eopl::Val.Num {:n -998})])]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:eopl::value-of body
        (:eopl::Env.ExtendRec {:fname fname :param param :fbody fbody :rest env}))]))

(:wat::core::defn :eopl::direct-run [e <- :eopl::Exp] -> :eopl::Val
  (:eopl::value-of e (:eopl::Env.Empty {})))
