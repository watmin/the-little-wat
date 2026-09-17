;; eopl/ch03-let-and-proc.wat — EOPL chapter 3: LET and PROC, as the separate languages the book
;; presents them as.
;;
;; LETREC (eopl/lib/letrec.wat) is the language the three machines of chapters 3-5 run, and it is
;; the union of these two plus recursion. Building LET and PROC separately is the chapter's actual
;; method: each language adds EXACTLY ONE THING, and you can see what that one thing costs.
;;
;; The wat observation is that the increment is a TYPE fact here, not a runtime one. In Scheme,
;; "LET has no procedures" means the interpreter has no clause for them and a program containing
;; one gets an error. In wat, `:l3::Exp` simply has no `Proc` variant, so a LET program containing
;; a procedure CANNOT BE BUILT -- the ill-formed program is unrepresentable rather than rejected.
;; That is the same move the Little Schemer ports kept running into and it is worth naming once.

;; ---------------------------------------------------------------------------------------------
;; LET — arithmetic, zero?, if, let. No procedures at all.
(:wat::core::defenum :l3::Exp :wat::enum::Pure
  :Const  [n <- :wat::core::i64]
  :Var    [name <- :wat::core::String]
  :Diff   [a <- :l3::Exp  b <- :l3::Exp]
  :IsZero [e <- :l3::Exp]
  :If     [c <- :l3::Exp  t <- :l3::Exp  f <- :l3::Exp]
  :Let    [name <- :wat::core::String  e <- :l3::Exp  body <- :l3::Exp])

;; LET's value domain is exactly two things -- there is nowhere to put a closure
(:wat::core::defenum :l3::Val :wat::enum::Pure
  :Num [n <- :wat::core::i64]  :Bool [b <- :wat::core::bool])

(:wat::core::defenum :l3::Env :wat::enum::Pure
  :Empty [] :Extend [name <- :wat::core::String  v <- :l3::Val  rest <- :l3::Env])

(:wat::core::defn :l3::look [env <- :l3::Env name <- :wat::core::String] -> :l3::Val
  (:wat::core::match env
    [:l3::Env.Empty {} (:l3::Val.Num {:n -999})]
    [:l3::Env.Extend {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:l3::look rest name))]))

(:wat::core::defn :l3::num [v <- :l3::Val] -> :wat::core::i64
  (:wat::core::match v [:l3::Val.Num {:n n} n] [:l3::Val.Bool {:b b} 0]))

(:wat::core::defn :l3::true? [v <- :l3::Val] -> :wat::core::bool
  (:wat::core::match v [:l3::Val.Bool {:b b} b]
                       [:l3::Val.Num {:n n} (:wat::core::not (:wat::core::= n 0))]))

(:wat::core::defn :l3::eval [e <- :l3::Exp env <- :l3::Env] -> :l3::Val
  (:wat::core::match e
    [:l3::Exp.Const {:n n} (:l3::Val.Num {:n n})]
    [:l3::Exp.Var {:name name} (:l3::look env name)]
    [:l3::Exp.Diff {:a a :b b}
      (:l3::Val.Num {:n (:wat::core::- (:l3::num (:l3::eval a env)) (:l3::num (:l3::eval b env)))})]
    [:l3::Exp.IsZero {:e inner}
      (:l3::Val.Bool {:b (:wat::core::= 0 (:l3::num (:l3::eval inner env)))})]
    [:l3::Exp.If {:c c :t t :f f}
      (:wat::core::if (:l3::true? (:l3::eval c env)) (:l3::eval t env) (:l3::eval f env))]
    [:l3::Exp.Let {:name name :e rhs :body body}
      (:l3::eval body (:l3::Env.Extend {:name name :v (:l3::eval rhs env) :rest env}))]))

(:wat::core::defn :l3::run [e <- :l3::Exp] -> :wat::core::i64
  (:l3::num (:l3::eval e (:l3::Env.Empty {}))))

;; ---------------------------------------------------------------------------------------------
;; PROC — LET plus exactly two productions, `proc` and a call. Everything else is copied verbatim,
;; which is the chapter's point: the increment is small and local.
(:wat::core::defenum :p3::Exp :wat::enum::Pure
  :Const  [n <- :wat::core::i64]
  :Var    [name <- :wat::core::String]
  :Diff   [a <- :p3::Exp  b <- :p3::Exp]
  :IsZero [e <- :p3::Exp]
  :If     [c <- :p3::Exp  t <- :p3::Exp  f <- :p3::Exp]
  :Let    [name <- :wat::core::String  e <- :p3::Exp  body <- :p3::Exp]
  :Proc   [param <- :wat::core::String  body <- :p3::Exp]
  :Call   [rator <- :p3::Exp  rand <- :p3::Exp])

;; and the value domain grows by exactly one variant, which is where the cost actually lands:
;; `Val` and `Env` become MUTUALLY RECURSIVE, because a closure captures an environment that holds
;; closures. wat takes that without ceremony (C-061 noted the same).
(:wat::core::defenum :p3::Val :wat::enum::Pure
  :Num  [n <- :wat::core::i64]
  :Bool [b <- :wat::core::bool]
  :Clo  [param <- :wat::core::String  body <- :p3::Exp  env <- :p3::Env])

(:wat::core::defenum :p3::Env :wat::enum::Pure
  :Empty [] :Extend [name <- :wat::core::String  v <- :p3::Val  rest <- :p3::Env])

(:wat::core::defn :p3::look [env <- :p3::Env name <- :wat::core::String] -> :p3::Val
  (:wat::core::match env
    [:p3::Env.Empty {} (:p3::Val.Num {:n -999})]
    [:p3::Env.Extend {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:p3::look rest name))]))

(:wat::core::defn :p3::num [v <- :p3::Val] -> :wat::core::i64
  (:wat::core::match v [:p3::Val.Num {:n n} n] [:p3::Val.Bool {:b b} 0]
                       [:p3::Val.Clo {:param p :body b :env e} 0]))

(:wat::core::defn :p3::true? [v <- :p3::Val] -> :wat::core::bool
  (:wat::core::match v [:p3::Val.Bool {:b b} b]
                       [:p3::Val.Num {:n n} (:wat::core::not (:wat::core::= n 0))]
                       [:p3::Val.Clo {:param p :body b :env e} true]))

(:wat::core::defn :p3::eval [e <- :p3::Exp env <- :p3::Env] -> :p3::Val
  (:wat::core::match e
    [:p3::Exp.Const {:n n} (:p3::Val.Num {:n n})]
    [:p3::Exp.Var {:name name} (:p3::look env name)]
    [:p3::Exp.Diff {:a a :b b}
      (:p3::Val.Num {:n (:wat::core::- (:p3::num (:p3::eval a env)) (:p3::num (:p3::eval b env)))})]
    [:p3::Exp.IsZero {:e inner}
      (:p3::Val.Bool {:b (:wat::core::= 0 (:p3::num (:p3::eval inner env)))})]
    [:p3::Exp.If {:c c :t t :f f}
      (:wat::core::if (:p3::true? (:p3::eval c env)) (:p3::eval t env) (:p3::eval f env))]
    [:p3::Exp.Let {:name name :e rhs :body body}
      (:p3::eval body (:p3::Env.Extend {:name name :v (:p3::eval rhs env) :rest env}))]
    [:p3::Exp.Proc {:param param :body body}
      (:p3::Val.Clo {:param param :body body :env env})]
    [:p3::Exp.Call {:rator rator :rand rand}
      (:wat::core::match (:p3::eval rator env)
        [:p3::Val.Clo {:param param :body body :env cenv}
          (:p3::eval body (:p3::Env.Extend {:name param :v (:p3::eval rand env) :rest cenv}))]
        [:p3::Val.Num {:n n} (:p3::Val.Num {:n -998})]
        [:p3::Val.Bool {:b b} (:p3::Val.Num {:n -998})])]))

(:wat::core::defn :p3::run [e <- :p3::Exp] -> :wat::core::i64
  (:p3::num (:p3::eval e (:p3::Env.Empty {}))))

(:wat::core::defn :c3::row [label <- :wat::core::String got <- :wat::core::i64 want <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " (:wat::i64::to-string got)
      (:wat::core::if (:wat::core::= got want) "   PASS" "   FAIL"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- EOPL ch3: LET ----")
    ;; let x = 5 in -(x, 3)
    (:c3::row "let x = 5 in -(x,3)          "
      (:l3::run (:l3::Exp.Let {:name "x" :e (:l3::Exp.Const {:n 5})
                               :body (:l3::Exp.Diff {:a (:l3::Exp.Var {:name "x"})
                                                     :b (:l3::Exp.Const {:n 3})})})) 2)
    ;; let x = 5 in let x = -(x,1) in -(x,1)   -- shadowing, EOPL 3.2's example
    (:c3::row "nested let shadows           "
      (:l3::run (:l3::Exp.Let
                  {:name "x" :e (:l3::Exp.Const {:n 5})
                   :body (:l3::Exp.Let
                           {:name "x" :e (:l3::Exp.Diff {:a (:l3::Exp.Var {:name "x"})
                                                         :b (:l3::Exp.Const {:n 1})})
                            :body (:l3::Exp.Diff {:a (:l3::Exp.Var {:name "x"})
                                                  :b (:l3::Exp.Const {:n 1})})})})) 3)
    (:c3::row "if zero?(0) then 1 else 2    "
      (:l3::run (:l3::Exp.If {:c (:l3::Exp.IsZero {:e (:l3::Exp.Const {:n 0})})
                              :t (:l3::Exp.Const {:n 1}) :f (:l3::Exp.Const {:n 2})})) 1)

    (:wat::kernel::println "---- EOPL ch3: PROC adds exactly two productions ----")
    ;; let f = proc(x) -(x,1) in (f 5)
    (:c3::row "let f = proc(x) -(x,1) in f 5"
      (:p3::run (:p3::Exp.Let
                  {:name "f"
                   :e (:p3::Exp.Proc {:param "x"
                                      :body (:p3::Exp.Diff {:a (:p3::Exp.Var {:name "x"})
                                                            :b (:p3::Exp.Const {:n 1})})})
                   :body (:p3::Exp.Call {:rator (:p3::Exp.Var {:name "f"})
                                         :rand (:p3::Exp.Const {:n 5})})})) 4)
    ;; a closure that CAPTURES: let x = 200 in let f = proc(z) -(z,x) in (f 300)
    (:c3::row "a closure captures its env   "
      (:p3::run (:p3::Exp.Let
                  {:name "x" :e (:p3::Exp.Const {:n 200})
                   :body (:p3::Exp.Let
                           {:name "f"
                            :e (:p3::Exp.Proc {:param "z"
                                               :body (:p3::Exp.Diff {:a (:p3::Exp.Var {:name "z"})
                                                                     :b (:p3::Exp.Var {:name "x"})})})
                            :body (:p3::Exp.Call {:rator (:p3::Exp.Var {:name "f"})
                                                  :rand (:p3::Exp.Const {:n 300})})})})) 100)
    ;; and that the capture is LEXICAL: rebinding x after the proc is made must not change it
    (:c3::row "capture is lexical, not dynamic"
      (:p3::run (:p3::Exp.Let
                  {:name "x" :e (:p3::Exp.Const {:n 200})
                   :body (:p3::Exp.Let
                           {:name "f"
                            :e (:p3::Exp.Proc {:param "z"
                                               :body (:p3::Exp.Diff {:a (:p3::Exp.Var {:name "z"})
                                                                     :b (:p3::Exp.Var {:name "x"})})})
                            :body (:p3::Exp.Let
                                    {:name "x" :e (:p3::Exp.Const {:n 1})
                                     :body (:p3::Exp.Call {:rator (:p3::Exp.Var {:name "f"})
                                                           :rand (:p3::Exp.Const {:n 300})})})})})) 100)

    (:wat::kernel::println "---- what separating them shows ----")
    (:wat::kernel::println "  PROC adds two productions to the syntax and ONE variant to the value")
    (:wat::kernel::println "  domain -- and that one variant is what makes Val and Env mutually")
    (:wat::kernel::println "  recursive, since a closure captures an environment holding closures.")
    (:wat::kernel::println "  In wat the increment is a TYPE fact: :l3::Exp has no Proc variant, so")
    (:wat::kernel::println "  a LET program containing a procedure cannot be BUILT, not merely")
    (:wat::kernel::println "  rejected. The ill-formed program is unrepresentable.")))
