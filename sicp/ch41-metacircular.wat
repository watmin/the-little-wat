;; SICP §4.1 (the metacircular evaluator), in wat.
;;
;; The word METACIRCULAR is doing real work in the section's title: the evaluator is written in the
;; language it evaluates, and a program is the same data the evaluator manipulates. Almost every
;; port of chapter 4 quietly drops that -- it defines an `Exp` enum, and the result is an
;; interpreter for a DIFFERENT language that happens to look similar. EOPL's ports here do exactly
;; that, correctly, because EOPL is not claiming otherwise.
;;
;; wat can keep it. `:wat::WatAST` is wat's own quoted form (C-004), so the programs below are
;; written `(:wat::core::quote (+ 1 2))` -- real wat syntax, read by wat's own reader -- and the
;; evaluator takes them apart with `ast-kind`, `ast-name`, `first` and `rest`. Nothing here
;; re-declares the syntax of the language being evaluated, which is the whole point of the section.
;;
;; What that costs, and it is worth being exact about: the dispatch on `ast-kind` is a STRING
;; comparison, not a `match`, so this is the one evaluator in this repository whose dispatch is NOT
;; checked exhaustive. That is the price of metacircularity in a typed host -- the same trade
;; C-004 records -- and it is why the enum versions elsewhere are the right default.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch41-metacircular.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch41-metacircular.wat

(:wat::load-file! "lib/check.wat")

;; ---- values the evaluator can produce
(:wat::core::defenum :sicp::Val :wat::enum::Pure
  :Num  [n <- :wat::core::i64]
  :Bool [b <- :wat::core::bool]
  :Sym  [name <- :wat::core::String]
  :Clo  [params <- :wat::WatAST  body <- :wat::WatAST  env <- :sicp::Env]
  :Prim [name <- :wat::core::String])

(:wat::core::defenum :sicp::Env :wat::enum::Pure
  :Empty  []
  :Extend [name <- :wat::core::String  v <- :sicp::Val  rest <- :sicp::Env])

(:wat::core::defn :sicp::lookup-var [name <- :wat::core::String env <- :sicp::Env] -> :sicp::Val
  (:wat::core::match env
    [:sicp::Env.Empty {} (:sicp::Val.Sym {:name name})]
    [:sicp::Env.Extend {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:sicp::lookup-var name rest))]))

(:wat::core::defn :sicp::num-of [v <- :sicp::Val] -> :wat::core::i64
  (:wat::core::match v
    [:sicp::Val.Num {:n n} n]
    [:sicp::Val.Bool {:b b} 0]
    [:sicp::Val.Sym {:name name} 0]
    [:sicp::Val.Clo {:params p :body b :env e} 0]
    [:sicp::Val.Prim {:name name} 0]))

(:wat::core::defn :sicp::truthy? [v <- :sicp::Val] -> :wat::core::bool
  (:wat::core::match v
    [:sicp::Val.Bool {:b b} b]
    [:sicp::Val.Num {:n n} true]
    [:sicp::Val.Sym {:name name} true]
    [:sicp::Val.Clo {:params p :body b :env e} true]
    [:sicp::Val.Prim {:name name} true]))

;; ---- primitives
(:wat::core::defn :sicp::apply-prim [name <- :wat::core::String args <- (:wat::core::Vector :- [:sicp::Val])] -> :sicp::Val
  (:wat::core::let [a (:sicp::num-of (:wat::core::nth args 0))
                    b (:wat::core::if (:wat::core::> (:wat::core::length args) 1)
                        (:sicp::num-of (:wat::core::nth args 1)) 0)]
    (:wat::core::if (:wat::core::= name "+") (:sicp::Val.Num {:n (:wat::core::+ a b)})
      (:wat::core::if (:wat::core::= name "-") (:sicp::Val.Num {:n (:wat::core::- a b)})
        (:wat::core::if (:wat::core::= name "*") (:sicp::Val.Num {:n (:wat::core::* a b)})
          (:wat::core::if (:wat::core::= name "=") (:sicp::Val.Bool {:b (:wat::core::= a b)})
            (:wat::core::if (:wat::core::= name "<") (:sicp::Val.Bool {:b (:wat::core::< a b)})
              (:sicp::Val.Num {:n 0}))))))))

;; ---- the evaluator, over wat's OWN quoted forms
(:wat::core::defn :sicp::head-name [exp <- :wat::WatAST] -> :wat::core::String
  (:wat::core::if (:wat::core::empty? exp) ""
    (:wat::core::let [h (:wat::core::first exp)]
      (:wat::core::if (:wat::core::= (:wat::core::ast-kind h) "symbol") (:wat::core::ast-name h) ""))))

(:wat::core::defn :sicp::nth-form [exp <- :wat::WatAST k <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::if (:wat::core::= k 0) (:wat::core::first exp)
    (:sicp::nth-form (:wat::core::rest exp) (:wat::core::- k 1))))

;; bind a list of parameter symbols to a vector of values
(:wat::core::defn :sicp::bind-params
  [params <- :wat::WatAST args <- (:wat::core::Vector :- [:sicp::Val]) i <- :wat::core::i64 env <- :sicp::Env] -> :sicp::Env
  (:wat::core::if (:wat::core::empty? params) env
    (:sicp::bind-params (:wat::core::rest params) args (:wat::core::+ i 1)
      (:sicp::Env.Extend {:name (:wat::core::ast-name (:wat::core::first params))
                          :v (:wat::core::nth args i) :rest env}))))

(:wat::core::defn :sicp::eval-args
  [rest <- :wat::WatAST env <- :sicp::Env acc <- (:wat::core::Vector :- [:sicp::Val])] -> (:wat::core::Vector :- [:sicp::Val])
  (:wat::core::if (:wat::core::empty? rest) acc
    (:sicp::eval-args (:wat::core::rest rest) env
      (:wat::core::conj acc (:sicp::my-eval (:wat::core::first rest) env)))))

;; `let` is DERIVED, exactly as SICP has it: bind each pair, then evaluate the body
(:wat::core::defn :sicp::bind-lets [binds <- :wat::WatAST env <- :sicp::Env outer <- :sicp::Env] -> :sicp::Env
  (:wat::core::if (:wat::core::empty? binds) env
    (:wat::core::let [pair (:wat::core::first binds)
                      name (:wat::core::ast-name (:wat::core::first pair))
                      v (:sicp::my-eval (:sicp::nth-form pair 1) outer)]
      (:sicp::bind-lets (:wat::core::rest binds)
        (:sicp::Env.Extend {:name name :v v :rest env}) outer))))

;; NOTE: this dispatch is a chain of string comparisons, NOT a match. It is the one evaluator here
;; that the checker cannot prove exhaustive -- the price of working on the host's own syntax.
(:wat::core::defn :sicp::my-eval [exp <- :wat::WatAST env <- :sicp::Env] -> :sicp::Val
  (:wat::core::let [kind (:wat::core::ast-kind exp)]
    (:wat::core::if (:wat::core::= kind "int")
      (:sicp::Val.Num {:n (:wat::core::Result/expect (:wat::eval-ast! exp) "expected an int literal")})
      (:wat::core::if (:wat::core::= kind "symbol")
        (:sicp::lookup-var (:wat::core::ast-name exp) env)
        ;; the list branch is explicit rather than a fallthrough: `ast-kind` has more kinds than
        ;; this evaluator handles (string, float, keyword …), and a fallthrough sent one of them
        ;; into `first`/`empty?`, which only a list node accepts. The checker cannot catch that --
        ;; see this file's header on what metacircularity costs.
        (:wat::core::if (:wat::core::not (:wat::core::= kind "list"))
          (:sicp::Val.Sym {:name kind})
        (:wat::core::let [h (:sicp::head-name exp)]
          (:wat::core::if (:wat::core::= h "quote")
            (:sicp::Val.Sym {:name (:wat::core::ast-name (:sicp::nth-form exp 1))})
            (:wat::core::if (:wat::core::= h "if")
              (:wat::core::if (:sicp::truthy? (:sicp::my-eval (:sicp::nth-form exp 1) env))
                (:sicp::my-eval (:sicp::nth-form exp 2) env)
                (:sicp::my-eval (:sicp::nth-form exp 3) env))
              (:wat::core::if (:wat::core::= h "lambda")
                (:sicp::Val.Clo {:params (:sicp::nth-form exp 1) :body (:sicp::nth-form exp 2) :env env})
                (:wat::core::if (:wat::core::= h "let")
                  (:sicp::my-eval (:sicp::nth-form exp 2)
                    (:sicp::bind-lets (:sicp::nth-form exp 1) env env))
                  ;; application
                  (:sicp::my-apply (:sicp::my-eval (:wat::core::first exp) env)
                    (:sicp::eval-args (:wat::core::rest exp) env
                      (:wat::core::Vector :- [:sicp::Val])))))))))))))

(:wat::core::defn :sicp::my-apply [f <- :sicp::Val args <- (:wat::core::Vector :- [:sicp::Val])] -> :sicp::Val
  (:wat::core::match f
    [:sicp::Val.Prim {:name name} (:sicp::apply-prim name args)]
    [:sicp::Val.Clo {:params params :body body :env cenv}
      (:sicp::my-eval body (:sicp::bind-params params args 0 cenv))]
    [:sicp::Val.Num {:n n} f]
    [:sicp::Val.Bool {:b b} f]
    [:sicp::Val.Sym {:name name} f]))

(:wat::core::defn :sicp::global-env [] -> :sicp::Env
  (:sicp::Env.Extend {:name "+" :v (:sicp::Val.Prim {:name "+"})
   :rest (:sicp::Env.Extend {:name "-" :v (:sicp::Val.Prim {:name "-"})
    :rest (:sicp::Env.Extend {:name "*" :v (:sicp::Val.Prim {:name "*"})
     :rest (:sicp::Env.Extend {:name "=" :v (:sicp::Val.Prim {:name "="})
      :rest (:sicp::Env.Extend {:name "<" :v (:sicp::Val.Prim {:name "<"})
       :rest (:sicp::Env.Extend {:name "true" :v (:sicp::Val.Bool {:b true})
        :rest (:sicp::Env.Extend {:name "false" :v (:sicp::Val.Bool {:b false})
         :rest (:sicp::Env.Empty {})})})})})})})}))

(:wat::core::defn :sicp::E [exp <- :wat::WatAST] -> :sicp::Val (:sicp::my-eval exp (:sicp::global-env)))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::show-val [v <- :sicp::Val] -> :wat::core::String
  (:wat::core::match v
    [:sicp::Val.Num {:n n} (:wat::i64::to-string n)]
    [:sicp::Val.Bool {:b b} (:wat::core::if b "#t" "#f")]
    [:sicp::Val.Sym {:name name} name]
    [:sicp::Val.Clo {:params p :body b :env e} "#<procedure>"]
    [:sicp::Val.Prim {:name name} "#<primitive>"]))

(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:sicp::check-chapter "oracle/sicp/ch41-metacircular.expected"
                        "sicp ch41 metacircular"
                        (:wat::core::Vector :- [:wat::core::String]
                          (:sicp::show-val (:sicp::E (:wat::core::quote 5)))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (quote hello))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (+ 1 2))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (* 3 (+ 2 2)))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (- 10 (* 2 3)))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (if (< 1 2) 10 20))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (if (< 2 1) 10 20))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (if true 1 2))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote ((lambda (x) (* x x)) 7))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote ((lambda (x y) (+ x y)) 3 4))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote ((lambda (x) ((lambda (y) (+ x y)) 10)) 5))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (let ((x 3) (y 4)) (+ x y)))))
                          (:sicp::show-val (:sicp::E (:wat::core::quote (let ((x 3)) (let ((y 4)) (* x y))))))
                          ;; the derivation, written out: the let above IS this combination
                          "((lambda (x y) (+ x y)) 3 4)"
                          (:sicp::b (:wat::core::= (:sicp::num-of (:sicp::E (:wat::core::quote (+ 1 2)))) 3))
                          (:sicp::b (:wat::core::= (:sicp::num-of (:sicp::E (:wat::core::quote ((lambda (x) (* x x)) 7)))) 49))
                          (:sicp::b (:wat::core::= (:sicp::num-of (:sicp::E (:wat::core::quote (let ((x 3) (y 4)) (+ x y))))) 7)))))
