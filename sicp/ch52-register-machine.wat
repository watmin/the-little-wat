;; SICP §5.1-5.2 (designing register machines, and simulating them), in wat.
;;
;; §5.1 designs machines on paper; §5.2 makes the design executable. Simulating is the only way to
;; state the chapter's central claim -- that a RECURSIVE procedure needs a stack and an ITERATIVE
;; one does not -- as a number rather than a diagram. So the stack high-water mark is reported for
;; both factorials, and it is 0 against n-1.
;;
;; This is also the rehearsal for NEXT.md §12's byte-code VM, and it arrives already carrying a
;; measurement: **F-105**. The machine below is `step : Machine -> Machine` driven by a loop, which
;; is the registerized shape, and F-105 measured that shape at ~1.9x slower than mutually
;; tail-calling procedures, because `step` must ALLOCATE the state it returns. Every instruction
;; here pays that. It is the right shape anyway -- the state is inspectable, which is how the
;; instruction count and the high-water mark below can be read out at all -- but the byte-code work
;; should know the price before it picks.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch52-register-machine.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch52-register-machine.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sicp::Regs (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64]))
(:wat::core::typealias :sicp::Stack (:wat::core::Vector :- [:wat::core::i64]))

;; an operand: a constant, a register, or an operation over operands
(:wat::core::defenum :sicp::Opnd :wat::enum::Pure
  :Const [n <- :wat::core::i64]
  :Reg   [name <- :wat::core::String]
  :Op    [name <- :wat::core::String  a <- :sicp::Opnd  b <- :sicp::Opnd])

(:wat::core::defenum :sicp::Inst :wat::enum::Pure
  :Label   [name <- :wat::core::String]
  :Assign  [reg <- :wat::core::String  from <- :sicp::Opnd]
  :Test    [cond <- :sicp::Opnd]
  :Branch  [label <- :wat::core::String]
  :Goto    [label <- :wat::core::String]
  :Save    [reg <- :wat::core::String]
  :Restore [reg <- :wat::core::String]
  :Done    [])

(:wat::core::typealias :sicp::Prog (:wat::core::Vector :- [:sicp::Inst]))

;; the whole machine state, so that `step` is a function of it
(:wat::core::defstruct :sicp::Machine
  [regs  <- :sicp::Regs
   stack <- :sicp::Stack
   pc    <- :wat::core::i64
   flag  <- :wat::core::bool
   steps <- :wat::core::i64
   hw    <- :wat::core::i64])

(:wat::core::defn :sicp::new-machine [] -> :sicp::Machine
  (:sicp::Machine :regs (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64])
                  :stack (:wat::core::Vector :- [:wat::core::i64])
                  :pc 0 :flag false :steps 0 :hw 0))

(:wat::core::defn :sicp::get-reg [m <- :sicp::Machine name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::map::get (:sicp::Machine/regs m) name)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} 0]))

(:wat::core::defn :sicp::set-reg [m <- :sicp::Machine name <- :wat::core::String v <- :wat::core::i64] -> :sicp::Machine
  (:sicp::Machine :regs (:wat::map::assoc (:sicp::Machine/regs m) name v)
                  :stack (:sicp::Machine/stack m) :pc (:sicp::Machine/pc m)
                  :flag (:sicp::Machine/flag m) :steps (:sicp::Machine/steps m)
                  :hw (:sicp::Machine/hw m)))

(:wat::core::defn :sicp::apply-op [name <- :wat::core::String a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= name "+") (:wat::core::+ a b)
    (:wat::core::if (:wat::core::= name "-") (:wat::core::- a b)
      (:wat::core::if (:wat::core::= name "*") (:wat::core::* a b)
        (:wat::core::if (:wat::core::= name "rem") (:wat::i64::rem a b)
          (:wat::core::if (:wat::core::= name "=") (:wat::core::if (:wat::core::= a b) 1 0)
            (:wat::core::if (:wat::core::= name "<") (:wat::core::if (:wat::core::< a b) 1 0) 0)))))))

(:wat::core::defn :sicp::eval-opnd [m <- :sicp::Machine x <- :sicp::Opnd] -> :wat::core::i64
  (:wat::core::match x
    [:sicp::Opnd.Const {:n n} n]
    [:sicp::Opnd.Reg {:name name} (:sicp::get-reg m name)]
    [:sicp::Opnd.Op {:name name :a a :b b}
      (:sicp::apply-op name (:sicp::eval-opnd m a) (:sicp::eval-opnd m b))]))

(:wat::core::defn :sicp::label-index [p <- :sicp::Prog name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length p)) -1
    (:wat::core::match (:wat::core::nth p i)
      [:sicp::Inst.Label {:name n}
        (:wat::core::if (:wat::core::= n name) i (:sicp::label-index p name (:wat::core::+ i 1)))]
      [:sicp::Inst.Assign {:reg r :from f} (:sicp::label-index p name (:wat::core::+ i 1))]
      [:sicp::Inst.Test {:cond c} (:sicp::label-index p name (:wat::core::+ i 1))]
      [:sicp::Inst.Branch {:label l} (:sicp::label-index p name (:wat::core::+ i 1))]
      [:sicp::Inst.Goto {:label l} (:sicp::label-index p name (:wat::core::+ i 1))]
      [:sicp::Inst.Save {:reg r} (:sicp::label-index p name (:wat::core::+ i 1))]
      [:sicp::Inst.Restore {:reg r} (:sicp::label-index p name (:wat::core::+ i 1))]
      [:sicp::Inst.Done {} (:sicp::label-index p name (:wat::core::+ i 1))])))

(:wat::core::defn :sicp::with [m <- :sicp::Machine regs <- :sicp::Regs stack <- :sicp::Stack
                               pc <- :wat::core::i64 flag <- :wat::core::bool hw <- :wat::core::i64] -> :sicp::Machine
  (:sicp::Machine :regs regs :stack stack :pc pc :flag flag
                  :steps (:wat::core::+ (:sicp::Machine/steps m) 1) :hw hw))

(:wat::core::defn :sicp::imax [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))

;; Popping the stack has to be written out. `:wat::core::take` answers a STREAM, not a Vector --
;; F-088 -- so `(take stack (- n 1))` type-checks nowhere useful and there is no way back to a
;; Vector. A register machine pops on almost every instruction, so this is not an edge case.
(:wat::core::defn :sicp::take-vec
  [s <- :sicp::Stack i <- :wat::core::i64 n <- :wat::core::i64 acc <- :sicp::Stack] -> :sicp::Stack
  (:wat::core::if (:wat::core::>= i n) acc
    (:sicp::take-vec s (:wat::core::+ i 1) n (:wat::core::conj acc (:wat::core::nth s i)))))

(:wat::core::defn :sicp::pop [s <- :sicp::Stack] -> :sicp::Stack
  (:sicp::take-vec s 0 (:wat::core::- (:wat::core::length s) 1)
    (:wat::core::Vector :- [:wat::core::i64])))

;; one instruction. This is the registerized shape F-105 prices: `step` must allocate the Machine
;; it returns, on every instruction.
(:wat::core::defn :sicp::step [m <- :sicp::Machine p <- :sicp::Prog] -> :sicp::Machine
  (:wat::core::let [inst (:wat::core::nth p (:sicp::Machine/pc m))
                    next (:wat::core::+ (:sicp::Machine/pc m) 1)
                    regs (:sicp::Machine/regs m)
                    stack (:sicp::Machine/stack m)
                    flag (:sicp::Machine/flag m)
                    hw (:sicp::Machine/hw m)]
    (:wat::core::match inst
      [:sicp::Inst.Label {:name n} (:sicp::with m regs stack next flag hw)]
      [:sicp::Inst.Assign {:reg r :from f}
        (:sicp::with m (:wat::map::assoc regs r (:sicp::eval-opnd m f)) stack next flag hw)]
      [:sicp::Inst.Test {:cond c}
        (:sicp::with m regs stack next (:wat::core::= 1 (:sicp::eval-opnd m c)) hw)]
      [:sicp::Inst.Branch {:label l}
        (:wat::core::if flag
          (:sicp::with m regs stack (:sicp::label-index p l 0) flag hw)
          (:sicp::with m regs stack next flag hw))]
      [:sicp::Inst.Goto {:label l}
        (:sicp::with m regs stack (:sicp::label-index p l 0) flag hw)]
      [:sicp::Inst.Save {:reg r}
        (:wat::core::let [s2 (:wat::core::conj stack (:sicp::get-reg m r))]
          (:sicp::with m regs s2 next flag (:sicp::imax hw (:wat::core::length s2))))]
      [:sicp::Inst.Restore {:reg r}
        (:wat::core::let [n (:wat::core::length stack)
                          v (:wat::core::nth stack (:wat::core::- n 1))]
          (:sicp::with m (:wat::map::assoc regs r v)
            (:sicp::pop stack) next flag hw))]
      [:sicp::Inst.Done {} (:sicp::with m regs stack next flag hw)])))

(:wat::core::defn :sicp::done? [m <- :sicp::Machine p <- :sicp::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= (:sicp::Machine/pc m) (:wat::core::length p)) true
    (:wat::core::match (:wat::core::nth p (:sicp::Machine/pc m))
      [:sicp::Inst.Done {} true]
      [:sicp::Inst.Label {:name n} false]
      [:sicp::Inst.Assign {:reg r :from f} false]
      [:sicp::Inst.Test {:cond c} false]
      [:sicp::Inst.Branch {:label l} false]
      [:sicp::Inst.Goto {:label l} false]
      [:sicp::Inst.Save {:reg r} false]
      [:sicp::Inst.Restore {:reg r} false])))

;; the driver: tail-recursive, so the host stack stays flat however long the program runs
(:wat::core::defn :sicp::run [m <- :sicp::Machine p <- :sicp::Prog] -> :sicp::Machine
  (:wat::core::if (:sicp::done? m p) m (:sicp::run (:sicp::step m p) p)))

;; ---- shorthand for writing controllers
(:wat::core::defn :sicp::r [n <- :wat::core::String] -> :sicp::Opnd (:sicp::Opnd.Reg {:name n}))
(:wat::core::defn :sicp::c [n <- :wat::core::i64] -> :sicp::Opnd (:sicp::Opnd.Const {:n n}))
(:wat::core::defn :sicp::op2 [n <- :wat::core::String a <- :sicp::Opnd b <- :sicp::Opnd] -> :sicp::Opnd
  (:sicp::Opnd.Op {:name n :a a :b b}))

;; ---- machine 1: Euclid's gcd. Iterative: no stack at all.
(:wat::core::defn :sicp::gcd-prog [] -> :sicp::Prog
  (:wat::core::Vector :- [:sicp::Inst]
    (:sicp::Inst.Label {:name "test-b"})
    (:sicp::Inst.Test {:cond (:sicp::op2 "=" (:sicp::r "b") (:sicp::c 0))})
    (:sicp::Inst.Branch {:label "gcd-done"})
    (:sicp::Inst.Assign {:reg "t" :from (:sicp::op2 "rem" (:sicp::r "a") (:sicp::r "b"))})
    (:sicp::Inst.Assign {:reg "a" :from (:sicp::r "b")})
    (:sicp::Inst.Assign {:reg "b" :from (:sicp::r "t")})
    (:sicp::Inst.Goto {:label "test-b"})
    (:sicp::Inst.Label {:name "gcd-done"})
    (:sicp::Inst.Done {})))

(:wat::core::defn :sicp::run-gcd [a <- :wat::core::i64 b <- :wat::core::i64] -> :sicp::Machine
  (:sicp::run (:sicp::set-reg (:sicp::set-reg (:sicp::new-machine) "a" a) "b" b) (:sicp::gcd-prog)))

;; ---- machine 2: iterative factorial. Still no stack.
(:wat::core::defn :sicp::fact-iter-prog [] -> :sicp::Prog
  (:wat::core::Vector :- [:sicp::Inst]
    (:sicp::Inst.Label {:name "loop"})
    (:sicp::Inst.Test {:cond (:sicp::op2 "<" (:sicp::r "n") (:sicp::r "counter"))})
    (:sicp::Inst.Branch {:label "fact-done"})
    (:sicp::Inst.Assign {:reg "product" :from (:sicp::op2 "*" (:sicp::r "counter") (:sicp::r "product"))})
    (:sicp::Inst.Assign {:reg "counter" :from (:sicp::op2 "+" (:sicp::r "counter") (:sicp::c 1))})
    (:sicp::Inst.Goto {:label "loop"})
    (:sicp::Inst.Label {:name "fact-done"})
    (:sicp::Inst.Done {})))

(:wat::core::defn :sicp::run-fact-iter [n <- :wat::core::i64] -> :sicp::Machine
  (:sicp::run (:sicp::set-reg (:sicp::set-reg (:sicp::set-reg (:sicp::new-machine) "n" n) "product" 1) "counter" 1)
    (:sicp::fact-iter-prog)))

;; ---- machine 3: RECURSIVE factorial. This one needs the stack, and that is the point.
(:wat::core::defn :sicp::fact-rec-prog [] -> :sicp::Prog
  (:wat::core::Vector :- [:sicp::Inst]
    (:sicp::Inst.Label {:name "fact-loop"})
    (:sicp::Inst.Test {:cond (:sicp::op2 "=" (:sicp::r "n") (:sicp::c 1))})
    (:sicp::Inst.Branch {:label "base"})
    (:sicp::Inst.Save {:reg "n"})
    (:sicp::Inst.Assign {:reg "n" :from (:sicp::op2 "-" (:sicp::r "n") (:sicp::c 1))})
    (:sicp::Inst.Goto {:label "fact-loop"})
    (:sicp::Inst.Label {:name "base"})
    (:sicp::Inst.Assign {:reg "val" :from (:sicp::c 1)})
    (:sicp::Inst.Label {:name "unwind"})
    (:sicp::Inst.Test {:cond (:sicp::op2 "=" (:sicp::r "depth") (:sicp::c 0))})
    (:sicp::Inst.Branch {:label "fin"})
    (:sicp::Inst.Restore {:reg "n"})
    (:sicp::Inst.Assign {:reg "val" :from (:sicp::op2 "*" (:sicp::r "n") (:sicp::r "val"))})
    (:sicp::Inst.Assign {:reg "depth" :from (:sicp::op2 "-" (:sicp::r "depth") (:sicp::c 1))})
    (:sicp::Inst.Goto {:label "unwind"})
    (:sicp::Inst.Label {:name "fin"})
    (:sicp::Inst.Done {})))

(:wat::core::defn :sicp::run-fact-rec [n <- :wat::core::i64] -> :sicp::Machine
  (:sicp::run (:sicp::set-reg (:sicp::set-reg (:sicp::new-machine) "n" n) "depth" (:wat::core::- n 1))
    (:sicp::fact-rec-prog)))

(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))]
    (:sicp::check-chapter "oracle/sicp/ch52-register-machine.expected"
                          "sicp ch52 register machine"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:sicp::get-reg (:sicp::run-gcd 206 40) "a"))
                            (int (:sicp::get-reg (:sicp::run-gcd 1071 462) "a"))
                            (int (:sicp::Machine/hw (:sicp::run-gcd 206 40)))
                            (int (:sicp::get-reg (:sicp::run-fact-iter 5) "product"))
                            (int (:sicp::get-reg (:sicp::run-fact-iter 10) "product"))
                            (int (:sicp::Machine/hw (:sicp::run-fact-iter 10)))
                            (int (:sicp::get-reg (:sicp::run-fact-rec 5) "val"))
                            (int (:sicp::get-reg (:sicp::run-fact-rec 10) "val"))
                            (int (:sicp::Machine/hw (:sicp::run-fact-rec 10)))
                            (int (:sicp::Machine/hw (:sicp::run-fact-rec 5)))
                            (:sicp::b (:wat::core::= 0 (:sicp::Machine/hw (:sicp::run-fact-iter 10))))
                            (:sicp::b (:wat::core::= (:sicp::get-reg (:sicp::run-fact-rec 10) "val")
                                                     (:sicp::get-reg (:sicp::run-fact-iter 10) "product")))
                            (int (:sicp::Machine/steps (:sicp::run-gcd 206 40)))
                            (int (:sicp::Machine/steps (:sicp::run-fact-iter 5)))))))
