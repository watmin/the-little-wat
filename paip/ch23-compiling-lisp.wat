;; PAIP chapter 23 (compiling Lisp), in wat.
;;
;; SICP §5.5 already compiled in this repository (C-081), and measured the payoff: the same
;; expression cost 11 machine steps interpreted and 8 compiled. What PAIP adds is the
;; **PEEPHOLE OPTIMIZER** -- a pass that rewrites short windows of the emitted code -- so the
;; measurement here is instruction COUNT before and after, plus the proof that the two programs
;; still compute the same answer.
;;
;;     (+ (* 2 3) (* x 1))   compiles to  7 instructions
;;                           optimises to 3 instructions
;;                           both answer  11
;;
;; Three rewrites do that: fold two constants under an arithmetic primitive, drop `+ 0`, drop
;; `* 1`. The first turns `(* 2 3)` into a constant at compile time; the second and third notice
;; that an identity is not an operation.
;;
;; **The wat observation is about what makes a peephole pass easy to write, and it is a compliment
;; rather than a complaint.** A window is `instruction, instruction, instruction`, and each rewrite
;; asks a question about the SHAPE of those three -- which is exactly what `match` over an enum is
;; for. The optimizer below cannot silently miss an instruction kind, because adding one to
;; `Instr` breaks every `match` that must learn about it. PAIP's version dispatches on `(car i)`
;; and would simply not fire. That is the same property C-078 praised in SICP §2.3 and C-085
;; showed the limit of in PAIP ch13 -- exhaustiveness catches missing cases, and a compiler pass is
;; almost entirely cases.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch23-compiling-lisp.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch23-compiling-lisp.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :paip::CExp :wat::enum::Pure
  :Const [n <- :wat::core::i64]
  :Var   [name <- :wat::core::String]
  :Prim  [op <- :wat::core::String  a <- :paip::CExp  b <- :paip::CExp]
  :If    [c <- :paip::CExp  t <- :paip::CExp  f <- :paip::CExp])

(:wat::core::defenum :paip::Ins :wat::enum::Pure
  :IConst  [n <- :wat::core::i64]
  :IVar    [name <- :wat::core::String]
  :IPrim   [op <- :wat::core::String]
  :IJFalse [k <- :wat::core::i64]
  :IJump   [k <- :wat::core::i64])

(:wat::core::typealias :paip::Code (:wat::core::Vector :- [:paip::Ins]))

(:wat::core::defn :paip::comp [e <- :paip::CExp] -> :paip::Code
  (:wat::core::match e
    [:paip::CExp.Const {:n n} (:wat::core::Vector :- [:paip::Ins] (:paip::Ins.IConst {:n n}))]
    [:paip::CExp.Var {:name name} (:wat::core::Vector :- [:paip::Ins] (:paip::Ins.IVar {:name name}))]
    [:paip::CExp.Prim {:op op :a a :b b}
      (:wat::core::concat (:paip::comp a)
        (:wat::core::concat (:paip::comp b)
          (:wat::core::Vector :- [:paip::Ins] (:paip::Ins.IPrim {:op op}))))]
    [:paip::CExp.If {:c c :t t :f f}
      (:wat::core::let [cc (:paip::comp c) tc (:paip::comp t) fc (:paip::comp f)]
        (:wat::core::concat cc
          (:wat::core::concat (:wat::core::Vector :- [:paip::Ins]
                                (:paip::Ins.IJFalse {:k (:wat::core::+ 1 (:wat::core::length tc))}))
            (:wat::core::concat tc
              (:wat::core::concat (:wat::core::Vector :- [:paip::Ins]
                                    (:paip::Ins.IJump {:k (:wat::core::length fc)})) fc)))))]))

;; ---- the peephole optimizer: three rewrites over a window of three
(:wat::core::defn :paip::const-of [i <- :paip::Ins] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match i
    [:paip::Ins.IConst {:n n} (:wat::core::Option.Some {:value n})]
    [:paip::Ins.IVar {:name name} (:wat::core::Option.None {})]
    [:paip::Ins.IPrim {:op op} (:wat::core::Option.None {})]
    [:paip::Ins.IJFalse {:k k} (:wat::core::Option.None {})]
    [:paip::Ins.IJump {:k k} (:wat::core::Option.None {})]))

(:wat::core::defn :paip::prim-of [i <- :paip::Ins] -> :wat::core::String
  (:wat::core::match i
    [:paip::Ins.IPrim {:op op} op]
    [:paip::Ins.IConst {:n n} ""]
    [:paip::Ins.IVar {:name name} ""]
    [:paip::Ins.IJFalse {:k k} ""]
    [:paip::Ins.IJump {:k k} ""]))

(:wat::core::defn :paip::arith? [op <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= op "+") (:wat::core::or (:wat::core::= op "-") (:wat::core::= op "*"))))

(:wat::core::defn :paip::fold-op [op <- :wat::core::String a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= op "+") (:wat::core::+ a b)
    (:wat::core::if (:wat::core::= op "-") (:wat::core::- a b) (:wat::core::* a b))))

(:wat::core::defn :paip::drop-n [c <- :paip::Code n <- :wat::core::i64 i <- :wat::core::i64 acc <- :paip::Code] -> :paip::Code
  (:wat::core::if (:wat::core::>= i (:wat::core::length c)) acc
    (:paip::drop-n c n (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::< i n) acc (:wat::core::conj acc (:wat::core::nth c i))))))

(:wat::core::defn :paip::peephole [code <- :paip::Code] -> :paip::Code
  (:wat::core::if (:wat::core::< (:wat::core::length code) 3) code
    (:wat::core::let [a (:wat::core::nth code 0) b (:wat::core::nth code 1) c (:wat::core::nth code 2)
                      rest (:paip::drop-n code 3 0 (:wat::core::Vector :- [:paip::Ins]))
                      op (:paip::prim-of c)]
      (:wat::core::match (:paip::const-of b)
        [:wat::core::Option.Some {:value bn}
          (:wat::core::match (:paip::const-of a)
            ;; two constants under an arithmetic primitive: fold at compile time
            [:wat::core::Option.Some {:value an}
              (:wat::core::if (:paip::arith? op)
                (:paip::peephole (:wat::core::concat
                                   (:wat::core::Vector :- [:paip::Ins]
                                     (:paip::Ins.IConst {:n (:paip::fold-op op an bn)})) rest))
                (:paip::keep code))]
            ;; `+ 0` and `* 1` are not operations
            [:wat::core::Option.None {}
              (:wat::core::if (:wat::core::or
                                (:wat::core::and (:wat::core::= bn 0) (:wat::core::= op "+"))
                                (:wat::core::and (:wat::core::= bn 1) (:wat::core::= op "*")))
                (:paip::peephole (:wat::core::concat (:wat::core::Vector :- [:paip::Ins] a) rest))
                (:paip::keep code))])]
        [:wat::core::Option.None {} (:paip::keep code)]))))

;; nothing fired at this position: keep the head and try again one instruction along
(:wat::core::defn :paip::keep [code <- :paip::Code] -> :paip::Code
  (:wat::core::concat (:wat::core::Vector :- [:paip::Ins] (:wat::core::nth code 0))
    (:paip::peephole (:paip::drop-n code 1 0 (:wat::core::Vector :- [:paip::Ins])))))

;; ---- the machine
(:wat::core::defn :paip::env-of [name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::if (:wat::core::= name "x") 5 (:wat::core::if (:wat::core::= name "y") 3 0)))

(:wat::core::defn :paip::run-prim [op <- :wat::core::String a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= op "+") (:wat::core::+ a b)
    (:wat::core::if (:wat::core::= op "-") (:wat::core::- a b)
      (:wat::core::if (:wat::core::= op "*") (:wat::core::* a b)
        (:wat::core::if (:wat::core::= op "<") (:wat::core::if (:wat::core::< a b) 1 0)
          (:wat::core::if (:wat::core::= a b) 1 0))))))

(:wat::core::typealias :paip::Stack (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :paip::pop-n [s <- :paip::Stack n <- :wat::core::i64] -> :paip::Stack
  (:paip::take-k s 0 (:wat::core::- (:wat::core::length s) n) (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :paip::take-k [s <- :paip::Stack i <- :wat::core::i64 n <- :wat::core::i64 acc <- :paip::Stack] -> :paip::Stack
  (:wat::core::if (:wat::core::>= i n) acc
    (:paip::take-k s (:wat::core::+ i 1) n (:wat::core::conj acc (:wat::core::nth s i)))))

(:wat::core::defn :paip::topk [s <- :paip::Stack k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::nth s (:wat::core::- (:wat::core::- (:wat::core::length s) 1) k)))

(:wat::core::defn :paip::run [code <- :paip::Code pc <- :wat::core::i64 stack <- :paip::Stack] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= pc (:wat::core::length code)) (:paip::topk stack 0)
    (:wat::core::match (:wat::core::nth code pc)
      [:paip::Ins.IConst {:n n} (:paip::run code (:wat::core::+ pc 1) (:wat::core::conj stack n))]
      [:paip::Ins.IVar {:name name}
        (:paip::run code (:wat::core::+ pc 1) (:wat::core::conj stack (:paip::env-of name)))]
      [:paip::Ins.IPrim {:op op}
        (:paip::run code (:wat::core::+ pc 1)
          (:wat::core::conj (:paip::pop-n stack 2)
            (:paip::run-prim op (:paip::topk stack 1) (:paip::topk stack 0))))]
      [:paip::Ins.IJFalse {:k k}
        (:wat::core::if (:wat::core::= (:paip::topk stack 0) 0)
          (:paip::run code (:wat::core::+ (:wat::core::+ pc 1) k) (:paip::pop-n stack 1))
          (:paip::run code (:wat::core::+ pc 1) (:paip::pop-n stack 1)))]
      [:paip::Ins.IJump {:k k} (:paip::run code (:wat::core::+ (:wat::core::+ pc 1) k) stack)])))

(:wat::core::defn :paip::exec [c <- :paip::Code] -> :wat::core::i64
  (:paip::run c 0 (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :paip::kk [n <- :wat::core::i64] -> :paip::CExp (:paip::CExp.Const {:n n}))
(:wat::core::defn :paip::vv [n <- :wat::core::String] -> :paip::CExp (:paip::CExp.Var {:name n}))
(:wat::core::defn :paip::pp [op <- :wat::core::String a <- :paip::CExp b <- :paip::CExp] -> :paip::CExp
  (:paip::CExp.Prim {:op op :a a :b b}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    c5 (:paip::kk 5)
                    add12 (:paip::pp "+" (:paip::kk 1) (:paip::kk 2))
                    mulxy (:paip::pp "*" (:paip::vv "x") (:paip::vv "y"))
                    iff (:paip::CExp.If {:c (:paip::pp "<" (:paip::vv "y") (:paip::vv "x"))
                                         :t (:paip::kk 10) :f (:paip::kk 20)})
                    plus0 (:paip::pp "+" (:paip::vv "x") (:paip::kk 0))
                    times1 (:paip::pp "*" (:paip::vv "x") (:paip::kk 1))
                    big (:paip::pp "+" (:paip::pp "*" (:paip::kk 2) (:paip::kk 3))
                                       (:paip::pp "*" (:paip::vv "x") (:paip::kk 1)))]
    (:paip::check-chapter "oracle/paip/ch23-compiling-lisp.expected"
                          "paip ch23 compiling lisp"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:wat::core::length (:paip::comp c5)))
                            (int (:paip::exec (:paip::comp c5)))
                            (int (:wat::core::length (:paip::comp add12)))
                            (int (:paip::exec (:paip::comp add12)))
                            (int (:paip::exec (:paip::comp mulxy)))
                            (int (:paip::exec (:paip::comp iff)))
                            ;; the optimizer folds constants
                            (int (:wat::core::length (:paip::peephole (:paip::comp add12))))
                            (int (:paip::exec (:paip::peephole (:paip::comp add12))))
                            ;; and removes identities
                            (int (:wat::core::length (:paip::comp plus0)))
                            (int (:wat::core::length (:paip::peephole (:paip::comp plus0))))
                            (int (:paip::exec (:paip::peephole (:paip::comp plus0))))
                            (int (:wat::core::length (:paip::peephole (:paip::comp times1))))
                            (int (:paip::exec (:paip::peephole (:paip::comp times1))))
                            ;; a bigger expression: same answer, fewer instructions
                            (int (:paip::exec (:paip::comp big)))
                            (int (:paip::exec (:paip::peephole (:paip::comp big))))
                            (:paip::b (:wat::core::= (:paip::exec (:paip::comp big))
                                                     (:paip::exec (:paip::peephole (:paip::comp big)))))
                            (int (:wat::core::length (:paip::comp big)))
                            (int (:wat::core::length (:paip::peephole (:paip::comp big))))
                            (:paip::b (:wat::core::< (:wat::core::length (:paip::peephole (:paip::comp big)))
                                                     (:wat::core::length (:paip::comp big))))))))
