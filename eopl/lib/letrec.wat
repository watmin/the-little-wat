;; eopl/lib/letrec.wat — EOPL's LETREC language: syntax, values, environments.
;;
;; Friedman & Wand build one language across chapters 3-5 and then change only how it is EXECUTED:
;; chapter 3 recurses directly, chapter 5 makes the continuation a DATA STRUCTURE and drives it
;; from a loop. Same language, two machines -- which is exactly the comparison worth making in
;; wat, because F-099 says a non-tail recursion segfaults past ~110000 frames with no diagnostic.
;;
;; Every type here is a Pure enum: no laziness, no handles, so none of Okasaki's carrier
;; awkwardness. `Val` and `Env` are mutually recursive (a closure captures an environment that
;; holds closures), which wat takes without ceremony.

(:wat::core::defenum :eopl::Exp :wat::enum::Pure
  :Const  [n <- :wat::core::i64]
  :Var    [name <- :wat::core::String]
  :Diff   [a <- :eopl::Exp  b <- :eopl::Exp]
  :IsZero [e <- :eopl::Exp]
  :If     [c <- :eopl::Exp  t <- :eopl::Exp  f <- :eopl::Exp]
  :Let    [name <- :wat::core::String  e <- :eopl::Exp  body <- :eopl::Exp]
  :Proc   [param <- :wat::core::String  body <- :eopl::Exp]
  :Call   [rator <- :eopl::Exp  rand <- :eopl::Exp]
  :Letrec [fname <- :wat::core::String  param <- :wat::core::String
           fbody <- :eopl::Exp  body <- :eopl::Exp])

(:wat::core::defenum :eopl::Val :wat::enum::Pure
  :Num  [n <- :wat::core::i64]
  :Bool [b <- :wat::core::bool]
  :Clo  [param <- :wat::core::String  body <- :eopl::Exp  env <- :eopl::Env])

(:wat::core::defenum :eopl::Env :wat::enum::Pure
  :Empty     []
  :Extend    [name <- :wat::core::String  v <- :eopl::Val  rest <- :eopl::Env]
  ;; a recursive binding is a FRAME, not a cycle -- EOPL's trick for letrec without mutation
  :ExtendRec [fname <- :wat::core::String  param <- :wat::core::String
              fbody <- :eopl::Exp  rest <- :eopl::Env])

(:wat::core::defn :eopl::num-of [v <- :eopl::Val] -> :wat::core::i64
  (:wat::core::match v
    [:eopl::Val.Num {:n n} n]
    [:eopl::Val.Bool {:b b} 0]
    [:eopl::Val.Clo {:param p :body bd :env e} 0]))

(:wat::core::defn :eopl::truthy? [v <- :eopl::Val] -> :wat::core::bool
  (:wat::core::match v
    [:eopl::Val.Bool {:b b} b]
    [:eopl::Val.Num {:n n} (:wat::core::not (:wat::core::= n 0))]
    [:eopl::Val.Clo {:param p :body bd :env e} true]))

;; apply-env — an ExtendRec frame rebuilds the closure on lookup, so the environment stays acyclic
(:wat::core::defn :eopl::apply-env [env <- :eopl::Env name <- :wat::core::String] -> :eopl::Val
  (:wat::core::match env
    [:eopl::Env.Empty {} (:eopl::Val.Num {:n -999})]
    [:eopl::Env.Extend {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:eopl::apply-env rest name))]
    [:eopl::Env.ExtendRec {:fname fname :param param :fbody fbody :rest rest}
      (:wat::core::if (:wat::core::= fname name)
        (:eopl::Val.Clo {:param param :body fbody :env env})
        (:eopl::apply-env rest name))]))
