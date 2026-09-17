;; eopl/lib/cps.wat — EOPL chapter 5: the continuation as a DATA STRUCTURE, driven by a loop.
;;
;; Chapter 5's move is to defunctionalize the continuation -- every "what to do next" becomes an
;; enum variant instead of a host-stack frame -- and then run a trampoline: a TAIL-recursive
;; driver that steps a machine state until it is Done.
;;
;; In wat that move has a consequence the book does not mention, because its host has a growable
;; stack: the interpreted program's depth moves OFF the host stack and INTO THE HEAP. F-099 says
;; wat segfaults past ~110000 non-tail frames with an empty stderr; TCO makes tail recursion
;; unbounded (1,000,000 verified). The driver below is tail-recursive, so the interpreter's own
;; depth is constant no matter how deep the interpreted program goes.

(:wat::load-file! "letrec.wat")

(:wat::core::defenum :eopl::Cont :wat::enum::Pure
  :End    []
  :ZeroK  [k <- :eopl::Cont]
  :LetK   [name <- :wat::core::String  body <- :eopl::Exp  env <- :eopl::Env  k <- :eopl::Cont]
  :IfK    [t <- :eopl::Exp  f <- :eopl::Exp  env <- :eopl::Env  k <- :eopl::Cont]
  :Diff1K [b <- :eopl::Exp  env <- :eopl::Env  k <- :eopl::Cont]
  :Diff2K [v1 <- :eopl::Val  k <- :eopl::Cont]
  :RatorK [rand <- :eopl::Exp  env <- :eopl::Env  k <- :eopl::Cont]
  :RandK  [f <- :eopl::Val  k <- :eopl::Cont])

(:wat::core::defenum :eopl::State :wat::enum::Pure
  :Eval  [e <- :eopl::Exp  env <- :eopl::Env  k <- :eopl::Cont]
  :Apply [k <- :eopl::Cont  v <- :eopl::Val]
  :Done  [v <- :eopl::Val])

;; one transition of the machine
(:wat::core::defn :eopl::step [s <- :eopl::State] -> :eopl::State
  (:wat::core::match s
    [:eopl::State.Done {:v v} s]
    [:eopl::State.Eval {:e e :env env :k k}
      (:wat::core::match e
        [:eopl::Exp.Const {:n n} (:eopl::State.Apply {:k k :v (:eopl::Val.Num {:n n})})]
        [:eopl::Exp.Var {:name name} (:eopl::State.Apply {:k k :v (:eopl::apply-env env name)})]
        [:eopl::Exp.Proc {:param param :body body}
          (:eopl::State.Apply {:k k :v (:eopl::Val.Clo {:param param :body body :env env})})]
        [:eopl::Exp.Diff {:a a :b b}
          (:eopl::State.Eval {:e a :env env :k (:eopl::Cont.Diff1K {:b b :env env :k k})})]
        [:eopl::Exp.IsZero {:e inner}
          (:eopl::State.Eval {:e inner :env env :k (:eopl::Cont.ZeroK {:k k})})]
        [:eopl::Exp.If {:c c :t t :f f}
          (:eopl::State.Eval {:e c :env env :k (:eopl::Cont.IfK {:t t :f f :env env :k k})})]
        [:eopl::Exp.Let {:name name :e rhs :body body}
          (:eopl::State.Eval {:e rhs :env env :k (:eopl::Cont.LetK {:name name :body body :env env :k k})})]
        [:eopl::Exp.Call {:rator rator :rand rand}
          (:eopl::State.Eval {:e rator :env env :k (:eopl::Cont.RatorK {:rand rand :env env :k k})})]
        [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
          (:eopl::State.Eval {:e body
                              :env (:eopl::Env.ExtendRec {:fname fname :param param :fbody fbody :rest env})
                              :k k})])]
    [:eopl::State.Apply {:k k :v v}
      (:wat::core::match k
        [:eopl::Cont.End {} (:eopl::State.Done {:v v})]
        [:eopl::Cont.ZeroK {:k k2}
          (:eopl::State.Apply {:k k2 :v (:eopl::Val.Bool {:b (:wat::core::= 0 (:eopl::num-of v))})})]
        [:eopl::Cont.LetK {:name name :body body :env env :k k2}
          (:eopl::State.Eval {:e body :env (:eopl::Env.Extend {:name name :v v :rest env}) :k k2})]
        [:eopl::Cont.IfK {:t t :f f :env env :k k2}
          (:wat::core::if (:eopl::truthy? v)
            (:eopl::State.Eval {:e t :env env :k k2})
            (:eopl::State.Eval {:e f :env env :k k2}))]
        [:eopl::Cont.Diff1K {:b b :env env :k k2}
          (:eopl::State.Eval {:e b :env env :k (:eopl::Cont.Diff2K {:v1 v :k k2})})]
        [:eopl::Cont.Diff2K {:v1 v1 :k k2}
          (:eopl::State.Apply {:k k2
            :v (:eopl::Val.Num {:n (:wat::core::- (:eopl::num-of v1) (:eopl::num-of v))})})]
        [:eopl::Cont.RatorK {:rand rand :env env :k k2}
          (:eopl::State.Eval {:e rand :env env :k (:eopl::Cont.RandK {:f v :k k2})})]
        [:eopl::Cont.RandK {:f f :k k2}
          (:wat::core::match f
            [:eopl::Val.Clo {:param param :body body :env cenv}
              ;; the TAIL CALL: the closure's body is evaluated under k2, not a new frame
              (:eopl::State.Eval {:e body :env (:eopl::Env.Extend {:name param :v v :rest cenv}) :k k2})]
            [:eopl::Val.Num {:n n} (:eopl::State.Done {:v (:eopl::Val.Num {:n -998})})]
            [:eopl::Val.Bool {:b b} (:eopl::State.Done {:v (:eopl::Val.Num {:n -998})})])])]))

;; the trampoline — TAIL recursive, so the host stack stays constant
(:wat::core::defn :eopl::drive [s <- :eopl::State] -> :eopl::Val
  (:wat::core::match s
    [:eopl::State.Done {:v v} v]
    [:eopl::State.Eval {:e e :env env :k k} (:eopl::drive (:eopl::step s))]
    [:eopl::State.Apply {:k k :v v} (:eopl::drive (:eopl::step s))]))

(:wat::core::defn :eopl::run [e <- :eopl::Exp] -> :eopl::Val
  (:eopl::drive (:eopl::State.Eval {:e e :env (:eopl::Env.Empty {}) :k (:eopl::Cont.End {})})))
