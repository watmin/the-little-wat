;; SICP §4.2 (lazy evaluation), in wat.
;;
;; The same metacircular evaluator as §4.1 (C-080), changed in exactly one place: an operand is
;; not evaluated at the call, it becomes a THUNK, and it is forced only when its value is actually
;; needed. That one change buys the section's two demonstrations, and costs the third.
;;
;;   BUYS  a divergent argument that is never used costs nothing, so `((lambda (a b) (if (= a 0) 1
;;         b)) 0 (/ 1 0))` answers 1 rather than dividing by zero;
;;   BUYS  `unless` becomes definable as an ORDINARY PROCEDURE, which applicative order cannot
;;         have -- the alternative arm is a thunk, so it is never forced;
;;   COSTS a repeated argument is evaluated REPEATEDLY. `(lambda (x) (+ x (+ x x)))` applied to a
;;         counted argument forces it **3** times, where using it once forces **1** and ignoring
;;         it forces **0**.
;;
;; That last row is call-by-NAME, and SICP's fix is a memoizing thunk. In wat the fix is **P-027**:
;; the whole of `okasaki/lib/susp.wat` exists because there is no force-once-and-shared cell, and
;; F-100 records that streams deliberately do not memoize. EOPL C-062 already priced the same gap
;; asymptotically -- by-name O(n²) against by-need O(n). This file is the third independent route
;; to the same missing primitive, from SICP's side, and the counts are the evidence.
;;
;; Counting without mutation: the evaluator threads a counter and answers `(value, count)`, the
;; same store-threading shape EOPL ch4 uses (C-066). SICP mutates a global.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch42-lazy-evaluation.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch42-lazy-evaluation.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :sicp::LVal :wat::enum::Pure
  :Num   [n <- :wat::core::i64]
  :Bool  [b <- :wat::core::bool]
  :Clo   [params <- :wat::WatAST  body <- :wat::WatAST  env <- :sicp::LEnv]
  :Prim  [name <- :wat::core::String]
  ;; an unevaluated operand: the code, and the frame it was written in
  :Thunk [exp <- :wat::WatAST  env <- :sicp::LEnv])

(:wat::core::defenum :sicp::LEnv :wat::enum::Pure
  :Empty  []
  :Extend [name <- :wat::core::String  v <- :sicp::LVal  rest <- :sicp::LEnv])

;; every step answers a value AND the running force count -- no mutation anywhere
(:wat::core::defenum :sicp::LAns :wat::enum::Pure
  :A [v <- :sicp::LVal  count <- :wat::core::i64])

(:wat::core::defn :sicp::l-lookup [name <- :wat::core::String env <- :sicp::LEnv] -> :sicp::LVal
  (:wat::core::match env
    [:sicp::LEnv.Empty {} (:sicp::LVal.Num {:n 0})]
    [:sicp::LEnv.Extend {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:sicp::l-lookup name rest))]))

(:wat::core::defn :sicp::l-num [v <- :sicp::LVal] -> :wat::core::i64
  (:wat::core::match v
    [:sicp::LVal.Num {:n n} n]
    [:sicp::LVal.Bool {:b b} 0]
    [:sicp::LVal.Clo {:params p :body b :env e} 0]
    [:sicp::LVal.Prim {:name name} 0]
    [:sicp::LVal.Thunk {:exp e :env en} 0]))

(:wat::core::defn :sicp::l-true? [v <- :sicp::LVal] -> :wat::core::bool
  (:wat::core::match v
    [:sicp::LVal.Bool {:b b} b]
    [:sicp::LVal.Num {:n n} true]
    [:sicp::LVal.Clo {:params p :body b :env e} true]
    [:sicp::LVal.Prim {:name name} true]
    [:sicp::LVal.Thunk {:exp e :env en} true]))

(:wat::core::defn :sicp::l-head [exp <- :wat::WatAST] -> :wat::core::String
  (:wat::core::if (:wat::core::empty? exp) ""
    (:wat::core::let [h (:wat::core::first exp)]
      (:wat::core::if (:wat::core::= (:wat::core::ast-kind h) "symbol") (:wat::core::ast-name h) ""))))

(:wat::core::defn :sicp::l-nth [exp <- :wat::WatAST k <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::if (:wat::core::= k 0) (:wat::core::first exp)
    (:sicp::l-nth (:wat::core::rest exp) (:wat::core::- k 1))))

;; `bump` is the counted primitive: applying it is what the force count counts
(:wat::core::defn :sicp::l-prim
  [name <- :wat::core::String args <- (:wat::core::Vector :- [:wat::core::i64]) count <- :wat::core::i64] -> :sicp::LAns
  (:wat::core::let [a (:wat::core::nth args 0)
                    b (:wat::core::if (:wat::core::> (:wat::core::length args) 1) (:wat::core::nth args 1) 0)]
    (:wat::core::if (:wat::core::= name "bump")
      (:sicp::LAns.A {:v (:sicp::LVal.Num {:n a}) :count (:wat::core::+ count 1)})
      (:wat::core::if (:wat::core::= name "+") (:sicp::LAns.A {:v (:sicp::LVal.Num {:n (:wat::core::+ a b)}) :count count})
        (:wat::core::if (:wat::core::= name "-") (:sicp::LAns.A {:v (:sicp::LVal.Num {:n (:wat::core::- a b)}) :count count})
          (:wat::core::if (:wat::core::= name "*") (:sicp::LAns.A {:v (:sicp::LVal.Num {:n (:wat::core::* a b)}) :count count})
            (:wat::core::if (:wat::core::= name "=") (:sicp::LAns.A {:v (:sicp::LVal.Bool {:b (:wat::core::= a b)}) :count count})
              (:wat::core::if (:wat::core::= name "<") (:sicp::LAns.A {:v (:sicp::LVal.Bool {:b (:wat::core::< a b)}) :count count})
                (:wat::core::if (:wat::core::= name "/")
                  (:sicp::LAns.A {:v (:sicp::LVal.Num {:n (:wat::i64::quot a b)}) :count count})
                  (:sicp::LAns.A {:v (:sicp::LVal.Num {:n 0}) :count count}))))))))))

;; force: a thunk is re-evaluated EVERY time, which is call-by-name and the whole cost
(:wat::core::defn :sicp::force-it [v <- :sicp::LVal count <- :wat::core::i64] -> :sicp::LAns
  (:wat::core::match v
    [:sicp::LVal.Thunk {:exp e :env en}
      (:wat::core::match (:sicp::l-eval e en count)
        [:sicp::LAns.A {:v v2 :count c2} (:sicp::force-it v2 c2)])]
    [:sicp::LVal.Num {:n n} (:sicp::LAns.A {:v v :count count})]
    [:sicp::LVal.Bool {:b b} (:sicp::LAns.A {:v v :count count})]
    [:sicp::LVal.Clo {:params p :body b :env e} (:sicp::LAns.A {:v v :count count})]
    [:sicp::LVal.Prim {:name name} (:sicp::LAns.A {:v v :count count})]))

(:wat::core::defn :sicp::actual-value [exp <- :wat::WatAST env <- :sicp::LEnv count <- :wat::core::i64] -> :sicp::LAns
  (:wat::core::match (:sicp::l-eval exp env count)
    [:sicp::LAns.A {:v v :count c} (:sicp::force-it v c)]))

;; operands become thunks; the primitive case forces them, the closure case does not
(:wat::core::defn :sicp::delay-args [ops <- :wat::WatAST env <- :sicp::LEnv params <- :wat::WatAST bound <- :sicp::LEnv] -> :sicp::LEnv
  (:wat::core::if (:wat::core::empty? params) bound
    (:sicp::delay-args (:wat::core::rest ops) env (:wat::core::rest params)
      (:sicp::LEnv.Extend {:name (:wat::core::ast-name (:wat::core::first params))
                           :v (:sicp::LVal.Thunk {:exp (:wat::core::first ops) :env env})
                           :rest bound}))))

;; a primitive needs its arguments' VALUES, so they are forced here, left to right
(:wat::core::defn :sicp::eval-prim-args
  [ops <- :wat::WatAST env <- :sicp::LEnv count <- :wat::core::i64
   acc <- (:wat::core::Vector :- [:wat::core::i64])] -> :sicp::PArgs
  (:wat::core::if (:wat::core::empty? ops) (:sicp::PArgs.P {:args acc :count count})
    (:wat::core::match (:sicp::actual-value (:wat::core::first ops) env count)
      [:sicp::LAns.A {:v v :count c}
        (:sicp::eval-prim-args (:wat::core::rest ops) env c (:wat::core::conj acc (:sicp::l-num v)))])))

(:wat::core::defenum :sicp::PArgs :wat::enum::Pure
  :P [args <- (:wat::core::Vector :- [:wat::core::i64])  count <- :wat::core::i64])

(:wat::core::defn :sicp::l-eval [exp <- :wat::WatAST env <- :sicp::LEnv count <- :wat::core::i64] -> :sicp::LAns
  (:wat::core::let [kind (:wat::core::ast-kind exp)]
    (:wat::core::if (:wat::core::= kind "int")
      (:sicp::LAns.A {:v (:sicp::LVal.Num {:n (:wat::core::Result/expect (:wat::eval-ast! exp) "int")}) :count count})
      (:wat::core::if (:wat::core::= kind "symbol")
        ;; a variable reference FORCES, which is where the repeated evaluation happens
        (:sicp::force-it (:sicp::l-lookup (:wat::core::ast-name exp) env) count)
        (:wat::core::if (:wat::core::not (:wat::core::= kind "list"))
          (:sicp::LAns.A {:v (:sicp::LVal.Num {:n 0}) :count count})
          (:wat::core::let [h (:sicp::l-head exp)]
            (:wat::core::if (:wat::core::= h "if")
              (:wat::core::match (:sicp::actual-value (:sicp::l-nth exp 1) env count)
                [:sicp::LAns.A {:v c :count c1}
                  (:wat::core::if (:sicp::l-true? c)
                    (:sicp::l-eval (:sicp::l-nth exp 2) env c1)
                    (:sicp::l-eval (:sicp::l-nth exp 3) env c1))])
              (:wat::core::if (:wat::core::= h "lambda")
                (:sicp::LAns.A {:v (:sicp::LVal.Clo {:params (:sicp::l-nth exp 1) :body (:sicp::l-nth exp 2) :env env}) :count count})
                ;; application
                (:wat::core::match (:sicp::actual-value (:wat::core::first exp) env count)
                  [:sicp::LAns.A {:v f :count c1}
                    (:wat::core::match f
                      [:sicp::LVal.Prim {:name name}
                        (:wat::core::match (:sicp::eval-prim-args (:wat::core::rest exp) env c1
                                             (:wat::core::Vector :- [:wat::core::i64]))
                          [:sicp::PArgs.P {:args args :count c2} (:sicp::l-prim name args c2)])]
                      [:sicp::LVal.Clo {:params params :body body :env cenv}
                        ;; operands are NOT evaluated here -- they become thunks
                        (:sicp::l-eval body (:sicp::delay-args (:wat::core::rest exp) env params cenv) c1)]
                      [:sicp::LVal.Num {:n n} (:sicp::LAns.A {:v f :count c1})]
                      [:sicp::LVal.Bool {:b b} (:sicp::LAns.A {:v f :count c1})]
                      [:sicp::LVal.Thunk {:exp e :env en} (:sicp::LAns.A {:v f :count c1})])])))))))))

(:wat::core::defn :sicp::l-global [] -> :sicp::LEnv
  (:sicp::LEnv.Extend {:name "+" :v (:sicp::LVal.Prim {:name "+"})
   :rest (:sicp::LEnv.Extend {:name "-" :v (:sicp::LVal.Prim {:name "-"})
    :rest (:sicp::LEnv.Extend {:name "*" :v (:sicp::LVal.Prim {:name "*"})
     :rest (:sicp::LEnv.Extend {:name "=" :v (:sicp::LVal.Prim {:name "="})
      :rest (:sicp::LEnv.Extend {:name "<" :v (:sicp::LVal.Prim {:name "<"})
       :rest (:sicp::LEnv.Extend {:name "/" :v (:sicp::LVal.Prim {:name "/"})
        :rest (:sicp::LEnv.Extend {:name "bump" :v (:sicp::LVal.Prim {:name "bump"})
         :rest (:sicp::LEnv.Extend {:name "true" :v (:sicp::LVal.Bool {:b true})
          :rest (:sicp::LEnv.Extend {:name "false" :v (:sicp::LVal.Bool {:b false})
           :rest (:sicp::LEnv.Empty {})})})})})})})})})}))

(:wat::core::defn :sicp::LE [exp <- :wat::WatAST] -> :wat::core::i64
  (:wat::core::match (:sicp::actual-value exp (:sicp::l-global) 0)
    [:sicp::LAns.A {:v v :count c} (:sicp::l-num v)]))

(:wat::core::defn :sicp::LC [exp <- :wat::WatAST] -> :wat::core::i64
  (:wat::core::match (:sicp::actual-value exp (:sicp::l-global) 0)
    [:sicp::LAns.A {:v v :count c} c]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))]
    (:sicp::check-chapter "oracle/sicp/ch42-lazy-evaluation.expected"
                          "sicp ch42 lazy evaluation"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:sicp::LE (:wat::core::quote (+ 1 2))))
                            (int (:sicp::LE (:wat::core::quote ((lambda (x) (* x x)) 7))))
                            (int (:sicp::LE (:wat::core::quote (if (< 1 2) 10 20))))
                            ;; the divergent argument is never forced
                            (int (:sicp::LE (:wat::core::quote ((lambda (a b) (if (= a 0) 1 b)) 0 (/ 1 0)))))
                            (int (:sicp::LE (:wat::core::quote ((lambda (a b) (if (= a 0) 1 b)) 1 (/ 6 3)))))
                            ;; `unless` as an ordinary procedure
                            (int (:sicp::LE (:wat::core::quote ((lambda (condition usual alternative)
                                                                  (if condition alternative usual))
                                                                (= 1 0) 5 (/ 1 0)))))
                            ;; and the cost: used three times, forced three times
                            (int (:sicp::LE (:wat::core::quote ((lambda (x) (+ x (+ x x))) (bump 7)))))
                            (int (:sicp::LC (:wat::core::quote ((lambda (x) (+ x (+ x x))) (bump 7)))))
                            (int (:sicp::LE (:wat::core::quote ((lambda (x) x) (bump 7)))))
                            (int (:sicp::LC (:wat::core::quote ((lambda (x) x) (bump 7)))))
                            (int (:sicp::LE (:wat::core::quote ((lambda (x) 99) (bump 7)))))
                            (int (:sicp::LC (:wat::core::quote ((lambda (x) 99) (bump 7)))))))))
