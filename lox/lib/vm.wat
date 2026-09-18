;; lox/lib/vm.wat — Crafting Interpreters chapter 15: the virtual machine.
;;
;; A stack machine: push constants, pop operands, push results, and a dispatch loop that walks the
;; code array. Nystrom's `run()` is a `for(;;)` with a `switch` on the next byte.
;;
;; ┌─ THE EXPERIMENT THIS FILE EXISTS FOR ──────────────────────────────────────────────────────┐
;; │ **F-105** measured `step : State -> State` at ~1.9x the cost of mutually tail-calling        │
;; │ procedures, on EOPL's toy machine, because `step` must ALLOCATE the state it returns.        │
;; │ NEXT.md §12 exists partly to find out whether that carries to a real byte-code VM, so the    │
;; │ loop is written BOTH ways here and the two must agree on every result:                       │
;; │                                                                                              │
;; │   REGISTERIZED  `step : VmState -> VmState` plus a driver. One record allocated per          │
;; │                 instruction. The shape a VM is usually drawn as, and the shape SICP §5.2     │
;; │                 and §5.4 already use (C-081).                                                │
;; │   THREADED      one tail-recursive loop carrying `ip` and the stack as separate arguments.   │
;; │                 No record per instruction. Uglier, and what C would compile to anyway.       │
;; │                                                                                              │
;; │ `lox/ch15-virtual-machine.wat` runs both on the same chunk and prices them.                  │
;; └──────────────────────────────────────────────────────────────────────────────────────────────┘
;;
;; The stack pops by rebuilding, because neither vector type has a positional update or a
;; drop-last that answers a vector (F-104, F-088 -- `:wat::core::take` answers a Stream). A stack
;; machine pops on almost every instruction, so this is the same tax C-081's register machine paid.

(:wat::load-file! "chunk.wat")

(:wat::core::typealias :lox::Stack (:wat::core::Vector :- [:wat::core::f64]))

(:wat::core::defn :lox::take-k [s <- :lox::Stack i <- :wat::core::i64 n <- :wat::core::i64 acc <- :lox::Stack] -> :lox::Stack
  (:wat::core::if (:wat::core::>= i n) acc
    (:lox::take-k s (:wat::core::+ i 1) n (:wat::core::conj acc (:wat::core::nth s i)))))

(:wat::core::defn :lox::pop-n [s <- :lox::Stack n <- :wat::core::i64] -> :lox::Stack
  (:lox::take-k s 0 (:wat::core::- (:wat::core::length s) n) (:wat::core::Vector :- [:wat::core::f64])))

(:wat::core::defn :lox::peek-n [s <- :lox::Stack k <- :wat::core::i64] -> :wat::core::f64
  (:wat::core::nth s (:wat::core::- (:wat::core::- (:wat::core::length s) 1) k)))

;; apply one instruction to a stack -- shared by both loops, so only the PLUMBING differs
(:wat::core::defn :lox::exec [op <- :lox::Op c <- :lox::Chunk s <- :lox::Stack] -> :lox::Stack
  (:wat::core::match op
    [:lox::Op.Constant {:slot k}
      (:wat::core::conj s (:wat::core::nth (:lox::Chunk/constants c) k))]
    [:lox::Op.Add {}
      (:wat::core::conj (:lox::pop-n s 2) (:wat::core::+ (:lox::peek-n s 1) (:lox::peek-n s 0)))]
    [:lox::Op.Subtract {}
      (:wat::core::conj (:lox::pop-n s 2) (:wat::core::- (:lox::peek-n s 1) (:lox::peek-n s 0)))]
    [:lox::Op.Multiply {}
      (:wat::core::conj (:lox::pop-n s 2) (:wat::core::* (:lox::peek-n s 1) (:lox::peek-n s 0)))]
    [:lox::Op.Divide {}
      (:wat::core::conj (:lox::pop-n s 2) (:wat::core::/ (:lox::peek-n s 1) (:lox::peek-n s 0)))]
    [:lox::Op.Negate {}
      (:wat::core::conj (:lox::pop-n s 1) (:wat::core::- 0.0 (:lox::peek-n s 0)))]
    [:lox::Op.Return {} s]))

(:wat::core::defn :lox::halts? [op <- :lox::Op] -> :wat::core::bool
  (:wat::core::match op
    [:lox::Op.Return {} true]
    [:lox::Op.Constant {:slot k} false]
    [:lox::Op.Add {} false] [:lox::Op.Subtract {} false]
    [:lox::Op.Multiply {} false] [:lox::Op.Divide {} false]
    [:lox::Op.Negate {} false]))

;; ---- SHAPE 1: registerized. `step` returns a new state, and must allocate one to do it.
(:wat::core::defrecord :lox::VmState [ip <- :wat::core::i64  stack <- :lox::Stack  steps <- :wat::core::i64])

(:wat::core::defn :lox::step [c <- :lox::Chunk st <- :lox::VmState] -> :lox::VmState
  (:wat::core::let [op (:wat::core::nth (:lox::Chunk/code c) (:lox::VmState/ip st))]
    (:lox::VmState :ip (:wat::core::+ (:lox::VmState/ip st) 1)
                   :stack (:lox::exec op c (:lox::VmState/stack st))
                   :steps (:wat::core::+ (:lox::VmState/steps st) 1))))

(:wat::core::defn :lox::drive [c <- :lox::Chunk st <- :lox::VmState] -> :lox::VmState
  (:wat::core::if (:wat::core::>= (:lox::VmState/ip st) (:lox::count c)) st
    (:wat::core::if (:lox::halts? (:wat::core::nth (:lox::Chunk/code c) (:lox::VmState/ip st)))
      (:lox::VmState :ip (:wat::core::+ (:lox::VmState/ip st) 1)
                     :stack (:lox::VmState/stack st)
                     :steps (:wat::core::+ (:lox::VmState/steps st) 1))
      (:lox::drive c (:lox::step c st)))))

(:wat::core::defn :lox::run-registerized [c <- :lox::Chunk] -> :lox::VmState
  (:lox::drive c (:lox::VmState :ip 0 :stack (:wat::core::Vector :- [:wat::core::f64]) :steps 0)))

;; ---- SHAPE 2: threaded. One tail-recursive loop, no record per instruction.
(:wat::core::defn :lox::run-threaded
  [c <- :lox::Chunk ip <- :wat::core::i64 s <- :lox::Stack steps <- :wat::core::i64] -> :lox::VmState
  (:wat::core::if (:wat::core::>= ip (:lox::count c))
    (:lox::VmState :ip ip :stack s :steps steps)
    (:wat::core::let [op (:wat::core::nth (:lox::Chunk/code c) ip)]
      (:wat::core::if (:lox::halts? op)
        (:lox::VmState :ip (:wat::core::+ ip 1) :stack s :steps (:wat::core::+ steps 1))
        (:lox::run-threaded c (:wat::core::+ ip 1) (:lox::exec op c s) (:wat::core::+ steps 1))))))

(:wat::core::defn :lox::run-direct [c <- :lox::Chunk] -> :lox::VmState
  (:lox::run-threaded c 0 (:wat::core::Vector :- [:wat::core::f64]) 0))

;; ---- SHAPE 3: threaded, with the chunk's arrays HOISTED OUT of the loop.
;; BASELINE.md prices a `defrecord` accessor at 6130 ns -- eight times a user function call. The
;; two loops above read `Chunk/code` on every instruction and `Chunk/constants` on every constant,
;; so a dispatch loop pays that per instruction. This shape reads them once.
(:wat::core::defn :lox::exec-flat [op <- :lox::Op ks <- :lox::Consts s <- :lox::Stack] -> :lox::Stack
  (:wat::core::match op
    [:lox::Op.Constant {:slot k} (:wat::core::conj s (:wat::core::nth ks k))]
    [:lox::Op.Add {}
      (:wat::core::conj (:lox::pop-n s 2) (:wat::core::+ (:lox::peek-n s 1) (:lox::peek-n s 0)))]
    [:lox::Op.Subtract {}
      (:wat::core::conj (:lox::pop-n s 2) (:wat::core::- (:lox::peek-n s 1) (:lox::peek-n s 0)))]
    [:lox::Op.Multiply {}
      (:wat::core::conj (:lox::pop-n s 2) (:wat::core::* (:lox::peek-n s 1) (:lox::peek-n s 0)))]
    [:lox::Op.Divide {}
      (:wat::core::conj (:lox::pop-n s 2) (:wat::core::/ (:lox::peek-n s 1) (:lox::peek-n s 0)))]
    [:lox::Op.Negate {}
      (:wat::core::conj (:lox::pop-n s 1) (:wat::core::- 0.0 (:lox::peek-n s 0)))]
    [:lox::Op.Return {} s]))

(:wat::core::defn :lox::run-hoisted-loop
  [code <- :lox::Code ks <- :lox::Consts n <- :wat::core::i64
   ip <- :wat::core::i64 s <- :lox::Stack steps <- :wat::core::i64] -> :lox::VmState
  (:wat::core::if (:wat::core::>= ip n) (:lox::VmState :ip ip :stack s :steps steps)
    (:wat::core::let [op (:wat::core::nth code ip)]
      (:wat::core::if (:lox::halts? op)
        (:lox::VmState :ip (:wat::core::+ ip 1) :stack s :steps (:wat::core::+ steps 1))
        (:lox::run-hoisted-loop code ks n (:wat::core::+ ip 1)
          (:lox::exec-flat op ks s) (:wat::core::+ steps 1))))))

(:wat::core::defn :lox::run-hoisted [c <- :lox::Chunk] -> :lox::VmState
  (:lox::run-hoisted-loop (:lox::Chunk/code c) (:lox::Chunk/constants c) (:lox::count c)
    0 (:wat::core::Vector :- [:wat::core::f64]) 0))

(:wat::core::defn :lox::result [st <- :lox::VmState] -> :wat::core::f64
  (:wat::core::let [s (:lox::VmState/stack st)]
    (:wat::core::if (:wat::core::empty? s) 0.0 (:lox::peek-n s 0))))
