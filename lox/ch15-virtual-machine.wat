;; Crafting Interpreters chapter 15 (a virtual machine), in wat.
;;
;; The chapter runs chapter 14's chunk: -((1.2 + 3.4) / 5.6), which is -0.8214285714285714.
;;
;; **And it answers the question NEXT.md §12 was queued for.** F-105 measured `step : State ->
;; State` at ~1.9x the cost of mutually tail-calling procedures on EOPL's toy machine, because
;; `step` must allocate the state it returns. Does that carry to a real byte-code VM? Both loops
;; are in lib/vm.wat, they share `exec` so only the plumbing differs, and they are priced below on
;; the same chunk.
;;
;; Run: wat lox/ch15-virtual-machine.wat

(:wat::load-file! "lib/vm.wat")

(:wat::core::defn :c15::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))

;; the book's chunk: -((1.2 + 3.4) / 5.6)
(:wat::core::defn :c15::chunk [] -> :lox::Chunk
  (:wat::core::let [c0 (:lox::add-constant (:lox::new-chunk) 1.2)
                    c1 (:lox::write c0 (:lox::Op.Constant {:slot (:lox::constant-slot c0)}) 123)
                    c2 (:lox::add-constant c1 3.4)
                    c3 (:lox::write c2 (:lox::Op.Constant {:slot (:lox::constant-slot c2)}) 123)
                    c4 (:lox::write c3 (:lox::Op.Add {}) 123)
                    c5 (:lox::add-constant c4 5.6)
                    c6 (:lox::write c5 (:lox::Op.Constant {:slot (:lox::constant-slot c5)}) 123)
                    c7 (:lox::write c6 (:lox::Op.Divide {}) 123)
                    c8 (:lox::write c7 (:lox::Op.Negate {}) 123)]
    (:lox::write c8 (:lox::Op.Return {}) 124)))

;; a longer chunk, so the per-instruction cost is what is being measured rather than startup
(:wat::core::defn :c15::grow [c <- :lox::Chunk k <- :wat::core::i64] -> :lox::Chunk
  (:wat::core::if (:wat::core::<= k 0) (:lox::write c (:lox::Op.Return {}) 1)
    (:wat::core::let [a (:lox::add-constant c 1.0)
                      b (:lox::write a (:lox::Op.Constant {:slot (:lox::constant-slot a)}) 1)]
      (:c15::grow (:lox::write b (:lox::Op.Add {}) 1) (:wat::core::- k 1)))))

(:wat::core::defn :c15::bench-chunk [n <- :wat::core::i64] -> :lox::Chunk
  (:wat::core::let [c0 (:lox::add-constant (:lox::new-chunk) 0.0)]
    (:c15::grow (:lox::write c0 (:lox::Op.Constant {:slot (:lox::constant-slot c0)}) 1) n)))

(:wat::core::defn :c15::best-reg [c <- :lox::Chunk reps <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= reps 0) best
    (:wat::core::let [t0 (:c15::now)
                      st (:lox::run-registerized c)
                      dt (:wat::core::- (:c15::now) t0)]
      (:c15::best-reg c (:wat::core::- reps 1) (:wat::core::if (:wat::core::< dt best) dt best)))))

(:wat::core::defn :c15::best-dir [c <- :lox::Chunk reps <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= reps 0) best
    (:wat::core::let [t0 (:c15::now)
                      st (:lox::run-direct c)
                      dt (:wat::core::- (:c15::now) t0)]
      (:c15::best-dir c (:wat::core::- reps 1) (:wat::core::if (:wat::core::< dt best) dt best)))))

(:wat::core::defn :c15::best-hoi [c <- :lox::Chunk reps <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= reps 0) best
    (:wat::core::let [t0 (:c15::now)
                      st (:lox::run-hoisted c)
                      dt (:wat::core::- (:c15::now) t0)]
      (:c15::best-hoi c (:wat::core::- reps 1) (:wat::core::if (:wat::core::< dt best) dt best)))))

(:wat::core::defn :c15::say [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :c15::ok [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "PASS" "FAIL"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [c (:c15::chunk)
     reg (:lox::run-registerized c)
     dir (:lox::run-direct c)
     big 999999999999
     bench (:c15::bench-chunk 2000)
     ;; the ORDER CONTROL matters here -- F-105's first draft was confounded by it, so the
     ;; registerized arm runs first in one pair and second in the other
     r1 (:c15::best-reg bench 5 big)
     d1 (:c15::best-dir bench 5 big)
     d2 (:c15::best-dir bench 5 big)
     r2 (:c15::best-reg bench 5 big)
     hoi (:c15::best-hoi bench 5 big)
     hoisted (:lox::run-hoisted c)]
    (:wat::core::do
      (:wat::kernel::println "---- chapter 15: the book's chunk, run ----")
      (:c15::say "registerized result       " (:wat::f64::to-string (:lox::result reg)))
      (:c15::say "threaded result           " (:wat::f64::to-string (:lox::result dir)))
      (:c15::say "the two agree             "
        (:c15::ok (:wat::core::= (:lox::result reg) (:lox::result dir))))
      (:c15::say "and it is -((1.2+3.4)/5.6)"
        (:c15::ok (:wat::core::< (:wat::f64::abs (:wat::core::- (:lox::result reg) -0.8214285714285714)) 0.000001)))
      (:c15::say "instructions executed     "
        (:wat::string::concat (:wat::i64::to-string (:lox::VmState/steps reg)) " / "
          (:wat::i64::to-string (:lox::VmState/steps dir)) "   "
          (:c15::ok (:wat::core::= (:lox::VmState/steps reg) (:lox::VmState/steps dir)))))

      (:wat::kernel::println "---- F-105 on a real byte-code loop: 4002 instructions, min of 5 ----")
      (:c15::say "registerized FIRST        " (:wat::string::concat (:wat::i64::to-string (:wat::core::/ r1 1000)) " us"))
      (:c15::say "threaded     second       " (:wat::string::concat (:wat::i64::to-string (:wat::core::/ d1 1000)) " us"))
      (:c15::say "threaded     FIRST        " (:wat::string::concat (:wat::i64::to-string (:wat::core::/ d2 1000)) " us"))
      (:c15::say "registerized second       " (:wat::string::concat (:wat::i64::to-string (:wat::core::/ r2 1000)) " us"))
      (:c15::say "hoisted: same loop, chunk read ONCE"
        (:wat::string::concat (:wat::i64::to-string (:wat::core::/ hoi 1000)) " us   "
          (:c15::ok (:wat::core::= (:lox::result hoisted) (:lox::result reg)))))
      (:c15::say "hoisted against threaded  "
        (:wat::string::concat (:wat::i64::to-string (:wat::core::/ (:wat::core::* hoi 100) d2)) "%"))
      (:c15::say "ratio, both orderings     "
        (:wat::string::concat (:wat::i64::to-string (:wat::core::/ (:wat::core::* r1 100) d1)) "%  and  "
          (:wat::i64::to-string (:wat::core::/ (:wat::core::* r2 100) d2)) "%   (100% = the same)"))
      (:c15::say "registerized against hoisted"
        (:wat::string::concat (:wat::i64::to-string (:wat::core::/ (:wat::core::* r1 100) hoi))
          "%   -- the two costs compound"))
      (:wat::kernel::println "---- what a byte-code VM in wat should take from this ----")
      (:wat::kernel::println "  1. `step : State -> State` costs well over 2x here (the ratios")
      (:wat::kernel::println "     are printed above, in both orderings), where F-105 measured")
      (:wat::kernel::println "     1.9x on EOPL's toy machine. A record allocated per instruction")
      (:wat::kernel::println "     is the single most expensive decision in the loop.")
      (:wat::kernel::println "  2. Reading the chunk's fields INSIDE the loop costs roughly another")
      (:wat::kernel::println "     third. BASELINE.md prices a defrecord accessor at 6130 ns --")
      (:wat::kernel::println "     eight times a user function call -- and a dispatch loop pays it")
      (:wat::kernel::println "     per instruction unless the arrays are hoisted out first.")
      (:wat::kernel::println "  3. The two costs COMPOUND, to between three and four times, on the")
      (:wat::kernel::println "     same 4002 instructions computing the same answer. Every ratio")
      (:wat::kernel::println "     above is a min of 5 runs, and both orderings are shown because")
      (:wat::kernel::println "     F-105's first draft was confounded by running one arm first."))))
