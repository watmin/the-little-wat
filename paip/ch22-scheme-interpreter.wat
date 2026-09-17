;; PAIP chapter 22 (Scheme: an interpreter), in wat.
;;
;; The chapter's reason for existing is `call/cc`, and this is the third time this repository has
;; watched the same thing happen: **wat does not have a feature, and an interpreter written in wat
;; hands that feature to the language it interprets.**
;;
;;   R-003  wat has no first-class continuations. A captured "rest of the computation" returns to
;;          its caller; the Seasoned Schemer's `letcc` had to go through `Result/try` (C-013).
;;   C-064  EOPL ch5's THREADS gave the interpreted language a MUTEX its host cannot express.
;;   here   the interpreted Scheme gets `call/cc`, complete, because the interpreter is written in
;;          continuation-passing style and a continuation is therefore just a value it holds.
;;
;; The measurement that shows it is real rather than decorative:
;;
;;     (+ 1 (call/cc (lambda (k) (* 100 (k 10)))))   =>  11
;;
;; The `(* 100 …)` never runs. The escape abandons the continuation it was in, which is exactly
;; what a `Result/try` escape cannot do from an arbitrary position, and what makes call/cc more
;; than an early return. And the classic short-circuit product of 4·3·2·1 with a zero in the middle
;; answers **0** where the same recursion without the escape answers **24**.
;;
;; guile has call/cc of its own and the oracle deliberately does not use it: both implementations
;; build it from their own explicit continuations, so the two are doing the same work.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch22-scheme-interpreter.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch22-scheme-interpreter.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Names (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defenum :paip::SExp :wat::enum::Pure
  :Lit    [n <- :wat::core::i64]
  :Var    [name <- :wat::core::String]
  :If     [c <- :paip::SExp  t <- :paip::SExp  f <- :paip::SExp]
  :Lam    [params <- :paip::Names  body <- :paip::SExp]
  :App    [f <- :paip::SExp  args <- (:wat::core::Vector :- [:paip::SExp])]
  :CallCC [f <- :paip::SExp])

;; a captured continuation is an ordinary VALUE holding a function -- which is the whole trick.
;;
;; **And it forces the carrier.** `SVal` cannot be a Pure enum, because a FUNCTION is impure:
;;   "containment rule: Pure enum :paip::SVal may only hold pure variant fields -- variant Cont
;;    field k has impure type [:paip::SVal :-> :paip::SVal], which cannot be reconstructed from
;;    EDN bytes across an address-space boundary"
;; This is the seventh time in this repository that the aggregate KIND rather than the field types
;; decided a program's shape, and the FIRST where the impure thing is a closure rather than a live
;; handle. The consequence is worth stating: **a value domain that includes continuations can never
;; cross a service boundary.** An interpreter offering call/cc is, by that fact alone, confined to
;; one address space. `SEnv` follows it Impure, because an environment holds values.
(:wat::core::defenum :paip::SVal :wat::enum::Impure
  :Num  [n <- :wat::core::i64]
  :Bool [b <- :wat::core::bool]
  :Clo  [params <- :paip::Names  body <- :paip::SExp  env <- :paip::SEnv]
  :Prim [name <- :wat::core::String]
  :Cont [k <- [:paip::SVal :-> :paip::SVal]])

(:wat::core::defenum :paip::SEnv :wat::enum::Impure
  :Empty  []
  :Extend [name <- :wat::core::String  v <- :paip::SVal  rest <- :paip::SEnv])

(:wat::core::typealias :paip::K [:paip::SVal :-> :paip::SVal])
(:wat::core::typealias :paip::Vals (:wat::core::Vector :- [:paip::SVal]))

(:wat::core::defn :paip::slook [name <- :wat::core::String env <- :paip::SEnv] -> :paip::SVal
  (:wat::core::match env
    [:paip::SEnv.Empty {} (:paip::SVal.Num {:n 0})]
    [:paip::SEnv.Extend {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:paip::slook name rest))]))

(:wat::core::defn :paip::snum [v <- :paip::SVal] -> :wat::core::i64
  (:wat::core::match v
    [:paip::SVal.Num {:n n} n]
    [:paip::SVal.Bool {:b b} 0]
    [:paip::SVal.Clo {:params p :body b :env e} 0]
    [:paip::SVal.Prim {:name n} 0]
    [:paip::SVal.Cont {:k k} 0]))

(:wat::core::defn :paip::strue? [v <- :paip::SVal] -> :wat::core::bool
  (:wat::core::match v
    [:paip::SVal.Bool {:b b} b]
    [:paip::SVal.Num {:n n} true]
    [:paip::SVal.Clo {:params p :body b :env e} true]
    [:paip::SVal.Prim {:name n} true]
    [:paip::SVal.Cont {:k k} true]))

(:wat::core::defn :paip::sprim [name <- :wat::core::String args <- :paip::Vals] -> :paip::SVal
  (:wat::core::let [a (:paip::snum (:wat::core::nth args 0))
                    b (:wat::core::if (:wat::core::> (:wat::core::length args) 1)
                        (:paip::snum (:wat::core::nth args 1)) 0)]
    (:wat::core::if (:wat::core::= name "+") (:paip::SVal.Num {:n (:wat::core::+ a b)})
      (:wat::core::if (:wat::core::= name "-") (:paip::SVal.Num {:n (:wat::core::- a b)})
        (:wat::core::if (:wat::core::= name "*") (:paip::SVal.Num {:n (:wat::core::* a b)})
          (:wat::core::if (:wat::core::= name "=") (:paip::SVal.Bool {:b (:wat::core::= a b)})
            (:wat::core::if (:wat::core::= name "zero?") (:paip::SVal.Bool {:b (:wat::core::= a 0)})
              (:paip::SVal.Num {:n 0}))))))))

(:wat::core::defn :paip::bind-all [ps <- :paip::Names args <- :paip::Vals i <- :wat::core::i64 env <- :paip::SEnv] -> :paip::SEnv
  (:wat::core::if (:wat::core::>= i (:wat::core::length ps)) env
    (:paip::bind-all ps args (:wat::core::+ i 1)
      (:paip::SEnv.Extend {:name (:wat::core::nth ps i) :v (:wat::core::nth args i) :rest env}))))

(:wat::core::defn :paip::apply-proc [f <- :paip::SVal args <- :paip::Vals k <- :paip::K] -> :paip::SVal
  (:wat::core::match f
    [:paip::SVal.Prim {:name name} (k (:paip::sprim name args))]
    [:paip::SVal.Clo {:params ps :body body :env cenv}
      (:paip::ev body (:paip::bind-all ps args 0 cenv) k)]
    ;; applying a CONTINUATION abandons the current one -- the whole of the feature, in one line
    [:paip::SVal.Cont {:k saved} (saved (:wat::core::nth args 0))]
    [:paip::SVal.Num {:n n} (k f)]
    [:paip::SVal.Bool {:b b} (k f)]))

(:wat::core::defn :paip::ev-args
  [es <- (:wat::core::Vector :- [:paip::SExp]) env <- :paip::SEnv i <- :wat::core::i64
   acc <- :paip::Vals kk <- [:paip::Vals :-> :paip::SVal]] -> :paip::SVal
  (:wat::core::if (:wat::core::>= i (:wat::core::length es)) (kk acc)
    (:paip::ev (:wat::core::nth es i) env
      (:wat::core::fn [v <- :paip::SVal] -> :paip::SVal
        (:paip::ev-args es env (:wat::core::+ i 1) (:wat::core::conj acc v) kk)))))

(:wat::core::defn :paip::ev [e <- :paip::SExp env <- :paip::SEnv k <- :paip::K] -> :paip::SVal
  (:wat::core::match e
    [:paip::SExp.Lit {:n n} (k (:paip::SVal.Num {:n n}))]
    [:paip::SExp.Var {:name name} (k (:paip::slook name env))]
    [:paip::SExp.Lam {:params ps :body body} (k (:paip::SVal.Clo {:params ps :body body :env env}))]
    [:paip::SExp.If {:c c :t t :f f}
      (:paip::ev c env (:wat::core::fn [cv <- :paip::SVal] -> :paip::SVal
                         (:wat::core::if (:paip::strue? cv) (:paip::ev t env k) (:paip::ev f env k))))]
    ;; call/cc: hand the CURRENT continuation to the argument, packaged as a value
    [:paip::SExp.CallCC {:f f}
      (:paip::ev f env (:wat::core::fn [fv <- :paip::SVal] -> :paip::SVal
                         (:paip::apply-proc fv (:wat::core::Vector :- [:paip::SVal]
                                                 (:paip::SVal.Cont {:k k})) k)))]
    [:paip::SExp.App {:f f :args args}
      (:paip::ev f env (:wat::core::fn [fv <- :paip::SVal] -> :paip::SVal
                         (:paip::ev-args args env 0 (:wat::core::Vector :- [:paip::SVal])
                           (:wat::core::fn [avs <- :paip::Vals] -> :paip::SVal
                             (:paip::apply-proc fv avs k)))))]))

(:wat::core::defn :paip::global [] -> :paip::SEnv
  (:paip::SEnv.Extend {:name "+" :v (:paip::SVal.Prim {:name "+"})
   :rest (:paip::SEnv.Extend {:name "-" :v (:paip::SVal.Prim {:name "-"})
    :rest (:paip::SEnv.Extend {:name "*" :v (:paip::SVal.Prim {:name "*"})
     :rest (:paip::SEnv.Extend {:name "=" :v (:paip::SVal.Prim {:name "="})
      :rest (:paip::SEnv.Extend {:name "zero?" :v (:paip::SVal.Prim {:name "zero?"})
       :rest (:paip::SEnv.Empty {})})})})})}))

(:wat::core::defn :paip::E [e <- :paip::SExp] -> :wat::core::i64
  (:paip::snum (:paip::ev e (:paip::global)
                 (:wat::core::fn [v <- :paip::SVal] -> :paip::SVal v))))

;; ---- shorthand
(:wat::core::defn :paip::li [n <- :wat::core::i64] -> :paip::SExp (:paip::SExp.Lit {:n n}))
(:wat::core::defn :paip::vr [n <- :wat::core::String] -> :paip::SExp (:paip::SExp.Var {:name n}))
(:wat::core::defn :paip::p1 [n <- :wat::core::String] -> :paip::Names
  (:wat::core::Vector :- [:wat::core::String] n))
(:wat::core::defn :paip::p2 [a <- :wat::core::String b <- :wat::core::String] -> :paip::Names
  (:wat::core::Vector :- [:wat::core::String] a b))
(:wat::core::defn :paip::ap1 [f <- :paip::SExp a <- :paip::SExp] -> :paip::SExp
  (:paip::SExp.App {:f f :args (:wat::core::Vector :- [:paip::SExp] a)}))
(:wat::core::defn :paip::ap2 [f <- :paip::SExp a <- :paip::SExp b <- :paip::SExp] -> :paip::SExp
  (:paip::SExp.App {:f f :args (:wat::core::Vector :- [:paip::SExp] a b)}))
(:wat::core::defn :paip::op [n <- :wat::core::String a <- :paip::SExp b <- :paip::SExp] -> :paip::SExp
  (:paip::ap2 (:paip::vr n) a b))
(:wat::core::defn :paip::lam1 [p <- :wat::core::String body <- :paip::SExp] -> :paip::SExp
  (:paip::SExp.Lam {:params (:paip::p1 p) :body body}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    ;; (lambda (f n) (if (zero? n) (return 0) (* n (f f (- n 1)))))
                    escaping-body (:paip::SExp.If
                                    {:c (:paip::ap1 (:paip::vr "zero?") (:paip::vr "n"))
                                     :t (:paip::ap1 (:paip::vr "return") (:paip::li 0))
                                     :f (:paip::op "*" (:paip::vr "n")
                                          (:paip::ap2 (:paip::vr "f") (:paip::vr "f")
                                            (:paip::op "-" (:paip::vr "n") (:paip::li 1))))})
                    plain-body (:paip::SExp.If
                                 {:c (:paip::ap1 (:paip::vr "zero?") (:paip::vr "n"))
                                  :t (:paip::li 1)
                                  :f (:paip::op "*" (:paip::vr "n")
                                       (:paip::ap2 (:paip::vr "f") (:paip::vr "f")
                                         (:paip::op "-" (:paip::vr "n") (:paip::li 1))))})
                    driver (:wat::core::fn [body <- :paip::SExp] -> :paip::SExp
                             (:paip::ap1
                               (:paip::lam1 "f" (:paip::ap2 (:paip::vr "f") (:paip::vr "f") (:paip::li 4)))
                               (:paip::SExp.Lam {:params (:paip::p2 "f" "n") :body body})))]
    (:paip::check-chapter "oracle/paip/ch22-scheme-interpreter.expected"
                          "paip ch22 scheme interpreter"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:paip::E (:paip::li 5)))
                            (int (:paip::E (:paip::op "+" (:paip::li 1) (:paip::li 2))))
                            (int (:paip::E (:paip::SExp.If {:c (:paip::op "=" (:paip::li 1) (:paip::li 1))
                                                            :t (:paip::li 10) :f (:paip::li 20)})))
                            (int (:paip::E (:paip::ap1 (:paip::lam1 "x" (:paip::op "*" (:paip::vr "x") (:paip::vr "x")))
                                             (:paip::li 7))))
                            ;; call/cc, NOT used
                            (int (:paip::E (:paip::SExp.CallCC {:f (:paip::lam1 "k" (:paip::li 42))})))
                            (int (:paip::E (:paip::op "+" (:paip::li 1)
                                             (:paip::SExp.CallCC {:f (:paip::lam1 "k" (:paip::li 10))}))))
                            ;; call/cc, USED: an escape
                            (int (:paip::E (:paip::SExp.CallCC
                                             {:f (:paip::lam1 "k" (:paip::ap1 (:paip::vr "k") (:paip::li 42)))})))
                            (int (:paip::E (:paip::op "+" (:paip::li 1)
                                             (:paip::SExp.CallCC
                                               {:f (:paip::lam1 "k" (:paip::ap1 (:paip::vr "k") (:paip::li 10)))}))))
                            ;; the (* 100 ...) never runs
                            (int (:paip::E (:paip::op "+" (:paip::li 1)
                                             (:paip::SExp.CallCC
                                               {:f (:paip::lam1 "k" (:paip::op "*" (:paip::li 100)
                                                      (:paip::ap1 (:paip::vr "k") (:paip::li 10))))}))))
                            (int (:paip::E (:paip::op "+" (:paip::li 1)
                                             (:paip::op "+" (:paip::li 2)
                                               (:paip::SExp.CallCC
                                                 {:f (:paip::lam1 "k" (:paip::ap1 (:paip::vr "k") (:paip::li 30)))})))))
                            ;; the classic short-circuit, and the same recursion without it
                            (int (:paip::E (:paip::SExp.CallCC {:f (:paip::lam1 "return" (driver escaping-body))})))
                            (int (:paip::E (driver plain-body)))
                            ;; a continuation is a first-class VALUE: pass it to an ordinary procedure
                            (int (:paip::E (:paip::op "+" (:paip::li 1)
                                             (:paip::SExp.CallCC
                                               {:f (:paip::lam1 "k"
                                                     (:paip::ap1 (:paip::lam1 "c"
                                                                   (:paip::ap1 (:paip::vr "c") (:paip::li 5)))
                                                       (:paip::vr "k")))}))))))))
