;; SICP §5.4-5.5 (the explicit-control evaluator, and the compiler), in wat.
;;
;; §5.4 turns the metacircular evaluator into a register machine: the recursion that used to be the
;; HOST'S becomes an explicit continuation and an explicit stack. §5.5 then COMPILES an expression
;; into a straight-line instruction sequence, so the interpreter's dispatch happens ONCE, at
;; compile time, instead of on every evaluation.
;;
;; The chapter's payoff is a number, and this is it: the same expression, run both ways.
;;
;;     interpreted (explicit control)   11 machine steps
;;     compiled                          8 machine steps, from 3 top-level instructions
;;
;; and the two agree on 42. That is the whole argument for compilation, stated as a count.
;;
;; Why this file matters beyond SICP: it is the closest thing in this repository to NEXT.md §12's
;; byte-code VM, and it arrives with the same warning C-081 attached to §5.2 -- the machine is a
;; step function over an explicit state, which **F-105** measured at ~1.9x the cost of mutually
;; tail-calling procedures, because the step must allocate the state it returns. The counts above
;; are machine-INDEPENDENT (they are steps, not nanoseconds), which is the discipline C-065 had to
;; be rewritten to follow; the 1.9x is what those steps cost in wat specifically.
;;
;; The continuation here is a LIST OF TASKS rather than a chain of frames -- the same
;; defunctionalisation EOPL ch5 does (C-061), arrived at from SICP's side. Once control is data,
;; "how deep did this go" is a length rather than a mystery.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch54-explicit-control.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch54-explicit-control.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :sicp::EExp :wat::enum::Pure
  :Const  [n <- :wat::core::i64]
  :Var    [name <- :wat::core::String]
  :If     [c <- :sicp::EExp  t <- :sicp::EExp  f <- :sicp::EExp]
  :Lambda [param <- :wat::core::String  body <- :sicp::EExp]
  :Prim   [op <- :wat::core::String  a <- :sicp::EExp  b <- :sicp::EExp]
  :App    [f <- :sicp::EExp  a <- :sicp::EExp])

;; ---- §5.5's instruction set, declared first because a closure value can hold either shape
(:wat::core::defenum :sicp::Instr :wat::enum::Pure
  :Push        [n <- :wat::core::i64]
  :Lookup      [name <- :wat::core::String]
  :PrimI       [op <- :wat::core::String]
  :Close       [param <- :wat::core::String  code <- (:wat::core::Vector :- [:sicp::Instr])]
  :Call        []
  :JumpIfFalse [k <- :wat::core::i64]
  :Jump        [k <- :wat::core::i64])

(:wat::core::typealias :sicp::Code (:wat::core::Vector :- [:sicp::Instr]))

(:wat::core::defenum :sicp::EVal :wat::enum::Pure
  :Num  [n <- :wat::core::i64]
  :Bool [b <- :wat::core::bool]
  :Clo  [param <- :wat::core::String  body <- :sicp::EExp  env <- :sicp::EEnv]
  :CodeV [param <- :wat::core::String  code <- :sicp::Code  env <- :sicp::EEnv])

(:wat::core::defenum :sicp::EEnv :wat::enum::Pure
  :Empty  []
  :Extend [name <- :wat::core::String  v <- :sicp::EVal  rest <- :sicp::EEnv])

(:wat::core::defn :sicp::elookup [name <- :wat::core::String env <- :sicp::EEnv] -> :sicp::EVal
  (:wat::core::match env
    [:sicp::EEnv.Empty {} (:sicp::EVal.Num {:n 0})]
    [:sicp::EEnv.Extend {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:sicp::elookup name rest))]))

(:wat::core::defn :sicp::enum-of [v <- :sicp::EVal] -> :wat::core::i64
  (:wat::core::match v
    [:sicp::EVal.Num {:n n} n]
    [:sicp::EVal.Bool {:b b} 0]
    [:sicp::EVal.Clo {:param p :body b :env e} 0]
    [:sicp::EVal.CodeV {:param p :code c :env e} 0]))

(:wat::core::defn :sicp::efalse? [v <- :sicp::EVal] -> :wat::core::bool
  (:wat::core::match v
    [:sicp::EVal.Bool {:b b} (:wat::core::not b)]
    [:sicp::EVal.Num {:n n} false]
    [:sicp::EVal.Clo {:param p :body b :env e} false]
    [:sicp::EVal.CodeV {:param p :code c :env e} false]))

(:wat::core::defn :sicp::eprim [op <- :wat::core::String a <- :sicp::EVal b <- :sicp::EVal] -> :sicp::EVal
  (:wat::core::let [x (:sicp::enum-of a) y (:sicp::enum-of b)]
    (:wat::core::if (:wat::core::= op "+") (:sicp::EVal.Num {:n (:wat::core::+ x y)})
      (:wat::core::if (:wat::core::= op "-") (:sicp::EVal.Num {:n (:wat::core::- x y)})
        (:wat::core::if (:wat::core::= op "*") (:sicp::EVal.Num {:n (:wat::core::* x y)})
          (:wat::core::if (:wat::core::= op "=") (:sicp::EVal.Bool {:b (:wat::core::= x y)})
            (:wat::core::if (:wat::core::= op "<") (:sicp::EVal.Bool {:b (:wat::core::< x y)})
              (:sicp::EVal.Num {:n 0}))))))))

;; ---- §5.4: control as DATA. A task list stands in for the continue register and the stack.
(:wat::core::defenum :sicp::Task :wat::enum::Pure
  :EvalT [e <- :sicp::EExp  env <- :sicp::EEnv]
  :IfK   [t <- :sicp::EExp  f <- :sicp::EExp  env <- :sicp::EEnv]
  :PrimK [op <- :wat::core::String]
  :AppK  [])

(:wat::core::typealias :sicp::Tasks (:wat::core::Vector :- [:sicp::Task]))
(:wat::core::typealias :sicp::Vals (:wat::core::Vector :- [:sicp::EVal]))

(:wat::core::defenum :sicp::EcAns :wat::enum::Pure
  :EA [v <- :sicp::EVal  steps <- :wat::core::i64])

;; the task list is consumed from the FRONT, so `cons`-ing onto it is pushing work
(:wat::core::defn :sicp::cons-tasks [xs <- :sicp::Tasks rest <- :sicp::Tasks] -> :sicp::Tasks
  (:wat::core::concat xs rest))

(:wat::core::defn :sicp::rest-of [v <- :sicp::Tasks] -> :sicp::Tasks
  (:sicp::drop-tasks v 1 (:wat::core::Vector :- [:sicp::Task])))

(:wat::core::defn :sicp::drop-tasks [v <- :sicp::Tasks i <- :wat::core::i64 acc <- :sicp::Tasks] -> :sicp::Tasks
  (:wat::core::if (:wat::core::>= i (:wat::core::length v)) acc
    (:sicp::drop-tasks v (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth v i)))))

(:wat::core::defn :sicp::pop-vals [v <- :sicp::Vals k <- :wat::core::i64] -> :sicp::Vals
  (:sicp::take-vals v 0 (:wat::core::- (:wat::core::length v) k) (:wat::core::Vector :- [:sicp::EVal])))

(:wat::core::defn :sicp::take-vals [v <- :sicp::Vals i <- :wat::core::i64 n <- :wat::core::i64 acc <- :sicp::Vals] -> :sicp::Vals
  (:wat::core::if (:wat::core::>= i n) acc
    (:sicp::take-vals v (:wat::core::+ i 1) n (:wat::core::conj acc (:wat::core::nth v i)))))

(:wat::core::defn :sicp::top [v <- :sicp::Vals k <- :wat::core::i64] -> :sicp::EVal
  (:wat::core::nth v (:wat::core::- (:wat::core::- (:wat::core::length v) 1) k)))

(:wat::core::defn :sicp::ec-loop [todo <- :sicp::Tasks vals <- :sicp::Vals steps <- :wat::core::i64] -> :sicp::EcAns
  (:wat::core::if (:wat::core::empty? todo)
    (:sicp::EcAns.EA {:v (:sicp::top vals 0) :steps steps})
    (:wat::core::let [task (:wat::core::nth todo 0)
                      rest (:sicp::rest-of todo)
                      n (:wat::core::+ steps 1)]
      (:wat::core::match task
        [:sicp::Task.EvalT {:e e :env env}
          (:wat::core::match e
            [:sicp::EExp.Const {:n k} (:sicp::ec-loop rest (:wat::core::conj vals (:sicp::EVal.Num {:n k})) n)]
            [:sicp::EExp.Var {:name name} (:sicp::ec-loop rest (:wat::core::conj vals (:sicp::elookup name env)) n)]
            [:sicp::EExp.Lambda {:param p :body b}
              (:sicp::ec-loop rest (:wat::core::conj vals (:sicp::EVal.Clo {:param p :body b :env env})) n)]
            [:sicp::EExp.If {:c c :t t :f f}
              (:sicp::ec-loop (:sicp::cons-tasks
                                (:wat::core::Vector :- [:sicp::Task]
                                  (:sicp::Task.EvalT {:e c :env env})
                                  (:sicp::Task.IfK {:t t :f f :env env})) rest) vals n)]
            [:sicp::EExp.Prim {:op op :a a :b b}
              (:sicp::ec-loop (:sicp::cons-tasks
                                (:wat::core::Vector :- [:sicp::Task]
                                  (:sicp::Task.EvalT {:e a :env env})
                                  (:sicp::Task.EvalT {:e b :env env})
                                  (:sicp::Task.PrimK {:op op})) rest) vals n)]
            [:sicp::EExp.App {:f f :a a}
              (:sicp::ec-loop (:sicp::cons-tasks
                                (:wat::core::Vector :- [:sicp::Task]
                                  (:sicp::Task.EvalT {:e f :env env})
                                  (:sicp::Task.EvalT {:e a :env env})
                                  (:sicp::Task.AppK {})) rest) vals n)])]
        [:sicp::Task.IfK {:t t :f f :env env}
          (:wat::core::let [c (:sicp::top vals 0)]
            (:sicp::ec-loop (:sicp::cons-tasks
                              (:wat::core::Vector :- [:sicp::Task]
                                (:sicp::Task.EvalT {:e (:wat::core::if (:sicp::efalse? c) f t) :env env})) rest)
              (:sicp::pop-vals vals 1) n))]
        [:sicp::Task.PrimK {:op op}
          (:wat::core::let [b (:sicp::top vals 0) a (:sicp::top vals 1)]
            (:sicp::ec-loop rest (:wat::core::conj (:sicp::pop-vals vals 2) (:sicp::eprim op a b)) n))]
        [:sicp::Task.AppK {}
          (:wat::core::let [arg (:sicp::top vals 0) f (:sicp::top vals 1)]
            (:wat::core::match f
              [:sicp::EVal.Clo {:param p :body body :env cenv}
                (:sicp::ec-loop (:sicp::cons-tasks
                                  (:wat::core::Vector :- [:sicp::Task]
                                    (:sicp::Task.EvalT {:e body :env (:sicp::EEnv.Extend {:name p :v arg :rest cenv})}))
                                  rest)
                  (:sicp::pop-vals vals 2) n)]
              [:sicp::EVal.Num {:n k} (:sicp::ec-loop rest (:sicp::pop-vals vals 1) n)]
              [:sicp::EVal.Bool {:b bb} (:sicp::ec-loop rest (:sicp::pop-vals vals 1) n)]
              [:sicp::EVal.CodeV {:param p :code c :env e} (:sicp::ec-loop rest (:sicp::pop-vals vals 1) n)]))]))))

(:wat::core::defn :sicp::ec-eval [e <- :sicp::EExp] -> :sicp::EcAns
  (:sicp::ec-loop (:wat::core::Vector :- [:sicp::Task] (:sicp::Task.EvalT {:e e :env (:sicp::EEnv.Empty {})}))
    (:wat::core::Vector :- [:sicp::EVal]) 0))

;; ---- §5.5: the compiler. One pass, emitting a flat instruction list.
(:wat::core::defn :sicp::compile-exp [e <- :sicp::EExp] -> :sicp::Code
  (:wat::core::match e
    [:sicp::EExp.Const {:n k} (:wat::core::Vector :- [:sicp::Instr] (:sicp::Instr.Push {:n k}))]
    [:sicp::EExp.Var {:name name} (:wat::core::Vector :- [:sicp::Instr] (:sicp::Instr.Lookup {:name name}))]
    [:sicp::EExp.Prim {:op op :a a :b b}
      (:wat::core::concat (:sicp::compile-exp a)
        (:wat::core::concat (:sicp::compile-exp b)
          (:wat::core::Vector :- [:sicp::Instr] (:sicp::Instr.PrimI {:op op}))))]
    [:sicp::EExp.Lambda {:param p :body b}
      (:wat::core::Vector :- [:sicp::Instr] (:sicp::Instr.Close {:param p :code (:sicp::compile-exp b)}))]
    [:sicp::EExp.App {:f f :a a}
      (:wat::core::concat (:sicp::compile-exp f)
        (:wat::core::concat (:sicp::compile-exp a)
          (:wat::core::Vector :- [:sicp::Instr] (:sicp::Instr.Call {}))))]
    [:sicp::EExp.If {:c c :t t :f f}
      (:wat::core::let [cc (:sicp::compile-exp c) tc (:sicp::compile-exp t) fc (:sicp::compile-exp f)]
        (:wat::core::concat cc
          (:wat::core::concat (:wat::core::Vector :- [:sicp::Instr]
                                (:sicp::Instr.JumpIfFalse {:k (:wat::core::+ 1 (:wat::core::length tc))}))
            (:wat::core::concat tc
              (:wat::core::concat (:wat::core::Vector :- [:sicp::Instr]
                                    (:sicp::Instr.Jump {:k (:wat::core::length fc)})) fc)))))]))

;; ---- and a tiny stack machine for the compiled code
(:wat::core::defn :sicp::vm [code <- :sicp::Code env <- :sicp::EEnv pc <- :wat::core::i64
                             stack <- :sicp::Vals steps <- :wat::core::i64] -> :sicp::EcAns
  (:wat::core::if (:wat::core::>= pc (:wat::core::length code))
    (:sicp::EcAns.EA {:v (:sicp::top stack 0) :steps steps})
    (:wat::core::let [i (:wat::core::nth code pc)
                      n (:wat::core::+ steps 1)]
      (:wat::core::match i
        [:sicp::Instr.Push {:n k}
          (:sicp::vm code env (:wat::core::+ pc 1) (:wat::core::conj stack (:sicp::EVal.Num {:n k})) n)]
        [:sicp::Instr.Lookup {:name name}
          (:sicp::vm code env (:wat::core::+ pc 1) (:wat::core::conj stack (:sicp::elookup name env)) n)]
        [:sicp::Instr.PrimI {:op op}
          (:sicp::vm code env (:wat::core::+ pc 1)
            (:wat::core::conj (:sicp::pop-vals stack 2) (:sicp::eprim op (:sicp::top stack 1) (:sicp::top stack 0))) n)]
        [:sicp::Instr.Close {:param p :code c}
          (:sicp::vm code env (:wat::core::+ pc 1)
            (:wat::core::conj stack (:sicp::EVal.CodeV {:param p :code c :env env})) n)]
        [:sicp::Instr.Call {}
          (:wat::core::let [arg (:sicp::top stack 0) f (:sicp::top stack 1)]
            (:wat::core::match f
              [:sicp::EVal.CodeV {:param p :code c :env cenv}
                (:wat::core::match (:sicp::vm c (:sicp::EEnv.Extend {:name p :v arg :rest cenv}) 0
                                     (:wat::core::Vector :- [:sicp::EVal]) 0)
                  [:sicp::EcAns.EA {:v rv :steps rs}
                    (:sicp::vm code env (:wat::core::+ pc 1)
                      (:wat::core::conj (:sicp::pop-vals stack 2) rv) (:wat::core::+ n rs))])]
              [:sicp::EVal.Num {:n k} (:sicp::vm code env (:wat::core::+ pc 1) (:sicp::pop-vals stack 1) n)]
              [:sicp::EVal.Bool {:b bb} (:sicp::vm code env (:wat::core::+ pc 1) (:sicp::pop-vals stack 1) n)]
              [:sicp::EVal.Clo {:param p :body b :env e}
                (:sicp::vm code env (:wat::core::+ pc 1) (:sicp::pop-vals stack 1) n)]))]
        [:sicp::Instr.JumpIfFalse {:k k}
          (:wat::core::if (:sicp::efalse? (:sicp::top stack 0))
            (:sicp::vm code env (:wat::core::+ (:wat::core::+ pc 1) k) (:sicp::pop-vals stack 1) n)
            (:sicp::vm code env (:wat::core::+ pc 1) (:sicp::pop-vals stack 1) n))]
        [:sicp::Instr.Jump {:k k}
          (:sicp::vm code env (:wat::core::+ (:wat::core::+ pc 1) k) stack n)]))))

(:wat::core::defn :sicp::run-compiled [e <- :sicp::EExp] -> :sicp::EcAns
  (:sicp::vm (:sicp::compile-exp e) (:sicp::EEnv.Empty {}) 0 (:wat::core::Vector :- [:sicp::EVal]) 0))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::show-eval [a <- :sicp::EcAns] -> :wat::core::String
  (:wat::core::match a
    [:sicp::EcAns.EA {:v v :steps s}
      (:wat::core::match v
        [:sicp::EVal.Num {:n n} (:wat::i64::to-string n)]
        [:sicp::EVal.Bool {:b b} (:wat::core::if b "#t" "#f")]
        [:sicp::EVal.Clo {:param p :body bd :env e} "#<procedure>"]
        [:sicp::EVal.CodeV {:param p :code c :env e} "#<compiled>"])]))

(:wat::core::defn :sicp::steps-of [a <- :sicp::EcAns] -> :wat::core::i64
  (:wat::core::match a [:sicp::EcAns.EA {:v v :steps s} s]))

(:wat::core::defn :sicp::val-of [a <- :sicp::EcAns] -> :wat::core::i64
  (:wat::core::match a [:sicp::EcAns.EA {:v v :steps s} (:sicp::enum-of v)]))

(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::k [n <- :wat::core::i64] -> :sicp::EExp (:sicp::EExp.Const {:n n}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    e1 (:sicp::k 5)
                    e2 (:sicp::EExp.Prim {:op "+" :a (:sicp::k 1) :b (:sicp::k 2)})
                    e3 (:sicp::EExp.Prim {:op "*" :a (:sicp::k 3)
                                          :b (:sicp::EExp.Prim {:op "+" :a (:sicp::k 2) :b (:sicp::k 2)})})
                    e4 (:sicp::EExp.If {:c (:sicp::EExp.Prim {:op "<" :a (:sicp::k 1) :b (:sicp::k 2)})
                                        :t (:sicp::k 10) :f (:sicp::k 20)})
                    e5 (:sicp::EExp.If {:c (:sicp::EExp.Prim {:op "<" :a (:sicp::k 2) :b (:sicp::k 1)})
                                        :t (:sicp::k 10) :f (:sicp::k 20)})
                    e6 (:sicp::EExp.App {:f (:sicp::EExp.Lambda {:param "x"
                                              :body (:sicp::EExp.Prim {:op "*" :a (:sicp::EExp.Var {:name "x"})
                                                                       :b (:sicp::EExp.Var {:name "x"})})})
                                         :a (:sicp::k 7)})
                    e7 (:sicp::EExp.App {:f (:sicp::EExp.Lambda {:param "x"
                                              :body (:sicp::EExp.App {:f (:sicp::EExp.Lambda {:param "y"
                                                       :body (:sicp::EExp.Prim {:op "+" :a (:sicp::EExp.Var {:name "x"})
                                                                                :b (:sicp::EExp.Var {:name "y"})})})
                                                                      :a (:sicp::k 10)})})
                                         :a (:sicp::k 5)})
                    ;; the benchmark: (lambda (x) (* x (+ x 1))) applied to 6
                    bench (:sicp::EExp.App {:f (:sicp::EExp.Lambda {:param "x"
                                                 :body (:sicp::EExp.Prim {:op "*" :a (:sicp::EExp.Var {:name "x"})
                                                          :b (:sicp::EExp.Prim {:op "+" :a (:sicp::EExp.Var {:name "x"})
                                                                                :b (:sicp::k 1)})})})
                                            :a (:sicp::k 6)})]
    (:sicp::check-chapter "oracle/sicp/ch54-explicit-control.expected"
                          "sicp ch54 explicit control"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::show-eval (:sicp::ec-eval e1))
                            (:sicp::show-eval (:sicp::ec-eval e2))
                            (:sicp::show-eval (:sicp::ec-eval e3))
                            (:sicp::show-eval (:sicp::ec-eval e4))
                            (:sicp::show-eval (:sicp::ec-eval e5))
                            (:sicp::show-eval (:sicp::ec-eval e6))
                            (:sicp::show-eval (:sicp::ec-eval e7))
                            (:sicp::show-eval (:sicp::run-compiled e1))
                            (:sicp::show-eval (:sicp::run-compiled e2))
                            (:sicp::show-eval (:sicp::run-compiled e3))
                            (:sicp::show-eval (:sicp::run-compiled e4))
                            (:sicp::show-eval (:sicp::run-compiled e5))
                            (:sicp::show-eval (:sicp::run-compiled e6))
                            (:sicp::show-eval (:sicp::ec-eval bench))
                            (:sicp::show-eval (:sicp::run-compiled bench))
                            (:sicp::b (:wat::core::= (:sicp::val-of (:sicp::ec-eval bench))
                                                     (:sicp::val-of (:sicp::run-compiled bench))))
                            (int (:sicp::steps-of (:sicp::ec-eval bench)))
                            (int (:sicp::steps-of (:sicp::run-compiled bench)))
                            (:sicp::b (:wat::core::< (:sicp::steps-of (:sicp::run-compiled bench))
                                                     (:sicp::steps-of (:sicp::ec-eval bench))))
                            (int (:wat::core::length (:sicp::compile-exp bench)))))))
