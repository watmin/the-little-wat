;; eopl/lib/lazy.wat — EOPL chapter 4: call-by-value, call-by-name, call-by-need.
;;
;; The three parameter-passing disciplines differ in exactly one way -- WHEN and HOW OFTEN an
;; argument is evaluated:
;;
;;   by-value  evaluate once, BEFORE the call, whether or not the body uses it
;;   by-name   evaluate on EVERY use, never if unused
;;   by-need   evaluate on FIRST use, then remember -- at most once, never if unused
;;
;; by-need is by-name plus memoization, which makes it the same distinction F-100 is about:
;; `:wat::stream::` is by-name (a forced suspension is not remembered), and P-027's `Susp<T>` is
;; what turns it into by-need. So this chapter exercises the suspension for something other than
;; Okasaki, and shows the difference on a language where it can be observed directly.
;;
;; The suspension is okasaki/lib/susp.wat -- still the LRU stand-in (P-027).

(:wat::load-file! "letrec.wat")
(:wat::load-file! "../../okasaki/lib/susp.wat")

;; A lazy closure captures a LEnv of thunks, and `:eopl::Val`'s `Clo` carries a strict `Env`, so
;; the lazy value type is kept beside it rather than widening `Val`. Both LVal and LEnv are Impure
;; enums: a by-need thunk holds a suspension, which is a live handle (containment rule), and the
;; chain must share rather than copy (F-098). That is the same carrier rule Okasaki needed five
;; times.
(:wat::core::defenum :eopl::LVal :wat::enum::Impure
  :LNum  [n <- :wat::core::i64]
  :LBool [b <- :wat::core::bool]
  :LClo  [param <- :wat::core::String  body <- :eopl::Exp  env <- :eopl::LEnv])

(:wat::core::defn :eopl::l-num [v <- :eopl::LVal] -> :wat::core::i64
  (:wat::core::match v
    [:eopl::LVal.LNum {:n n} n]
    [:eopl::LVal.LBool {:b b} 0]
    [:eopl::LVal.LClo {:param p :body b :env e} 0]))

(:wat::core::defn :eopl::l-true? [v <- :eopl::LVal] -> :wat::core::bool
  (:wat::core::match v
    [:eopl::LVal.LBool {:b b} b]
    [:eopl::LVal.LNum {:n n} (:wat::core::not (:wat::core::= n 0))]
    [:eopl::LVal.LClo {:param p :body b :env e} true]))

;; a binding now carries an LVal-producing thunk
(:wat::core::defenum :eopl::LThunk :wat::enum::Impure
  :LTVal  [v <- :eopl::LVal]
  :LTExp  [e <- :eopl::Exp  env <- :eopl::LEnv]
  :LTSusp [s <- (:ok::Susp :- [:eopl::LVal])])

(:wat::core::defenum :eopl::LEnv :wat::enum::Impure
  :LEmpty     []
  :LExtend    [name <- :wat::core::String  th <- :eopl::LThunk  rest <- :eopl::LEnv]
  :LExtendRec [fname <- :wat::core::String  param <- :wat::core::String
               fbody <- :eopl::Exp  rest <- :eopl::LEnv])

;; strategy selector, so one interpreter serves all three
(:wat::core::defenum :eopl::Strategy :wat::enum::Pure
  :ByValue [] :ByName [] :ByNeed [])

(:wat::core::defn :eopl::l-lookup [env <- :eopl::LEnv name <- :wat::core::String] -> :eopl::LThunk
  (:wat::core::match env
    [:eopl::LEnv.LEmpty {} (:eopl::LThunk.LTVal {:v (:eopl::LVal.LNum {:n -999})})]
    [:eopl::LEnv.LExtend {:name n :th th :rest rest}
      (:wat::core::if (:wat::core::= n name) th (:eopl::l-lookup rest name))]
    [:eopl::LEnv.LExtendRec {:fname fname :param param :fbody fbody :rest rest}
      (:wat::core::if (:wat::core::= fname name)
        (:eopl::LThunk.LTVal {:v (:eopl::LVal.LClo {:param param :body fbody :env env})})
        (:eopl::l-lookup rest name))]))

(:wat::core::defn :eopl::force-thunk [th <- :eopl::LThunk st <- :eopl::Strategy] -> :eopl::LVal
  (:wat::core::match th
    [:eopl::LThunk.LTVal {:v v} v]
    [:eopl::LThunk.LTExp {:e e :env env} (:eopl::l-eval e env st)]
    [:eopl::LThunk.LTSusp {:s s} (:ok::force s)]))

(:wat::core::defn :eopl::l-eval [e <- :eopl::Exp env <- :eopl::LEnv st <- :eopl::Strategy] -> :eopl::LVal
  (:wat::core::match e
    [:eopl::Exp.Const {:n n} (:eopl::LVal.LNum {:n n})]
    [:eopl::Exp.Var {:name name} (:eopl::force-thunk (:eopl::l-lookup env name) st)]
    [:eopl::Exp.Diff {:a a :b b}
      (:eopl::LVal.LNum {:n (:wat::core::- (:eopl::l-num (:eopl::l-eval a env st))
                                           (:eopl::l-num (:eopl::l-eval b env st)))})]
    [:eopl::Exp.IsZero {:e inner}
      (:eopl::LVal.LBool {:b (:wat::core::= 0 (:eopl::l-num (:eopl::l-eval inner env st)))})]
    [:eopl::Exp.If {:c c :t t :f f}
      (:wat::core::if (:eopl::l-true? (:eopl::l-eval c env st))
        (:eopl::l-eval t env st) (:eopl::l-eval f env st))]
    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:eopl::l-eval body
        (:eopl::LEnv.LExtend {:name name :th (:eopl::mk-thunk rhs env st) :rest env}) st)]
    [:eopl::Exp.Proc {:param param :body body}
      (:eopl::LVal.LClo {:param param :body body :env env})]
    [:eopl::Exp.Call {:rator rator :rand rand}
      (:wat::core::match (:eopl::l-eval rator env st)
        [:eopl::LVal.LClo {:param param :body body :env cenv}
          (:eopl::l-eval body
            (:eopl::LEnv.LExtend {:name param :th (:eopl::mk-thunk rand env st) :rest cenv}) st)]
        [:eopl::LVal.LNum {:n n} (:eopl::LVal.LNum {:n -998})]
        [:eopl::LVal.LBool {:b b} (:eopl::LVal.LNum {:n -998})])]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:eopl::l-eval body
        (:eopl::LEnv.LExtendRec {:fname fname :param param :fbody fbody :rest env}) st)]))

;; THE WHOLE DIFFERENCE BETWEEN THE THREE DISCIPLINES IS HERE
(:wat::core::defn :eopl::mk-thunk [e <- :eopl::Exp env <- :eopl::LEnv st <- :eopl::Strategy] -> :eopl::LThunk
  (:wat::core::match st
    ;; by-value: evaluate now, once, whether the body uses it or not
    [:eopl::Strategy.ByValue {} (:eopl::LThunk.LTVal {:v (:eopl::l-eval e env st)})]
    ;; by-name: keep the expression, re-evaluate on every use
    [:eopl::Strategy.ByName {} (:eopl::LThunk.LTExp {:e e :env env})]
    ;; by-need: keep it behind a memoizing suspension -- evaluated at most once
    [:eopl::Strategy.ByNeed {}
      (:eopl::LThunk.LTSusp
        {:s (:ok::delay (:wat::core::fn [] -> :eopl::LVal (:eopl::l-eval e env st)))})]))

(:wat::core::defn :eopl::l-run [e <- :eopl::Exp st <- :eopl::Strategy] -> :eopl::LVal
  (:eopl::l-eval e (:eopl::LEnv.LEmpty {}) st))
