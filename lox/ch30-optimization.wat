;; Crafting Interpreters chapter 30 (optimization), in wat.
;;
;; NEXT.md recorded this chapter as "no portable content", because its two optimizations are NaN
;; boxing and a hash-table bitmask, and both are about C's memory model. C-103 is a standing
;; reason to re-read such a ruling, and re-reading it finds that the chapter's CONTENT is not
;; portable and its METHOD is: Nystrom writes two benchmarks first, profiles, and shows that the
;; obvious optimization is not always the win. This file does that to the VM the section built.
;;
;; And it has a specific claim to test, made by this repository and never checked at the right
;; scale. **F-116** measured push and pop against depth and found a `Vector`'s rebuild-pop
;; quadratic where a `PersistentVector`'s is linear -- 121 ms against 34 ms for one pop at depth
;; 4000 -- and NEXT.md concluded that this VM's stack should therefore be a `PersistentVector`.
;;
;; That conclusion is wrong, and this chapter is where it gets corrected. A Lox stack holds one
;; frame's locals plus a couple of temporaries: it reaches tens, not thousands.
;;
;; Run: wat lox/ch30-optimization.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c30::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c30::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))
(:wat::core::defn :c30::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:c30::pad (:wat::string::concat s " ") n)))
(:wat::core::defn :c30::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))

(:wat::core::defn :c30::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c30::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))

(:wat::core::defn :c30::steps-of [r <- :loxv::Out] -> :wat::core::i64
  (:wat::core::match r
    [:loxv::Out.Ok {:stack s :globals g :out o :steps k} k]
    [:loxv::Out.Err {:msg m :line l :out o :steps k} k]))

;; one benchmark: compile once, then time the RUN twice and keep the smaller
(:wat::core::defn :c30::bench [label <- :wat::core::String src <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let
    [c (:loxv::C/chunk (:loxv::compile-program src))
     w (:loxv::run c)
     a0 (:c30::now) r1 (:loxv::run c) a1 (:c30::now)
     b0 (:c30::now) r2 (:loxv::run c) b1 (:c30::now)
     t (:c30::imin (:wat::core::- a1 a0) (:wat::core::- b1 b0))
     steps (:c30::steps-of r1)]
    (:wat::kernel::println
      (:wat::string::concat (:c30::pad label 22)
        " " (:c30::pad (:c30::int steps) 8) " instructions"
        "  " (:c30::pad (:c30::int (:wat::core::/ t 1000)) 8) " us"
        "  " (:c30::pad (:c30::int (:wat::core::/ t steps)) 7) " ns/instruction"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- the VM's own cost, on Nystrom's two benchmark shapes ----")
    (:c30::bench "fib(12), recursion" "fun fib(n) { if (n < 2) return n; return fib(n-1) + fib(n-2); } fib(12);")
    (:c30::bench "arithmetic loop" "var s = 0; for (var i = 0; i < 300; i = i + 1) s = s + i * 2 - 1;")
    (:c30::bench "property access" "class Foo { init() { this.n = 0; } bump() { this.n = this.n + 1; } } var f = Foo(); for (var i = 0; i < 100; i = i + 1) f.bump();")
    (:c30::bench "closure calls" "fun mk(i) { fun g() { return i; } return g; } var s = 0; for (var i = 0; i < 60; i = i + 1) { var h = mk(i); s = s + h(); }")
    (:wat::kernel::println "")
    (:wat::kernel::println "Recursion costs about TWICE per instruction what a flat loop does, and")
    (:wat::kernel::println "that is the frame vector: every call conj's a Saved record onto it and")
    (:wat::kernel::println "every return rebuilds it without the last element. F-116's pop, met in")
    (:wat::kernel::println "the one place a VM cannot avoid it.")
    (:wat::kernel::println "")
    (:wat::kernel::println "---- the claim this chapter exists to correct ----")
    (:wat::kernel::println "F-116 measured one push and one pop against depth and found a Vector's")
    (:wat::kernel::println "rebuild-pop QUADRATIC where a PersistentVector's is linear: 121 ms")
    (:wat::kernel::println "against 34 ms for one pop at depth 4000. NEXT.md concluded that this VM's")
    (:wat::kernel::println "stack should be a PersistentVector, and left it as work to do.")
    (:wat::kernel::println "")
    (:wat::kernel::println "probes/lox/stack-mix.wat runs the operation mix a byte-code VM actually")
    (:wat::kernel::println "performs -- two reads, a pop of two, a push, a positional store -- at the")
    (:wat::kernel::println "depths it actually reaches:")
    (:wat::kernel::println "")
    (:wat::kernel::println "    depth 4     Vector is  89% of PersistentVector's cost")
    (:wat::kernel::println "    depth 8     Vector is  86%")
    (:wat::kernel::println "    depth 16    Vector is  82%")
    (:wat::kernel::println "    depth 32    Vector is  80%")
    (:wat::kernel::println "    depth 128   Vector is  82%")
    (:wat::kernel::println "    depth 512   Vector is 113%   <- the crossover")
    (:wat::kernel::println "")
    (:wat::kernel::println "So the recommendation was wrong at the scale that matters. A Lox stack")
    (:wat::kernel::println "holds one frame's locals and a couple of temporaries; it reaches tens.")
    (:wat::kernel::println "Below about 256 elements the Vector WINS, because PersistentVector's")
    (:wat::kernel::println "`get` answers an Option and the unwrap on every read costs more than the")
    (:wat::kernel::println "clone it saves. F-116's measurements stand; the advice drawn from them")
    (:wat::kernel::println "did not survive being tested at the right size.")
    (:wat::kernel::println "")
    (:wat::core::let
      [rs
       [;; the benchmarks must still be correct programs, or they are measuring nothing
        (:c30::expect "fib(12) is right           "
          (:c30::run "fun fib(n) { if (n < 2) return n; return fib(n-1) + fib(n-2); } print fib(12);") "144")
        (:c30::expect "the arithmetic loop        "
          (:c30::run "var s = 0; for (var i = 0; i < 300; i = i + 1) s = s + i * 2 - 1; print s;") "89400")
        (:c30::expect "the property loop          "
          (:c30::run "class Foo { init() { this.n = 0; } bump() { this.n = this.n + 1; } } var f = Foo(); for (var i = 0; i < 100; i = i + 1) f.bump(); print f.n;") "100")
        (:c30::expect "the closure loop           "
          (:c30::run "fun mk(i) { fun g() { return i; } return g; } var s = 0; for (var i = 0; i < 60; i = i + 1) { var h = mk(i); s = s + h(); } print s;") "1770")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what chapter 30 turns out to be worth ----")
        (:wat::kernel::println "Its CONTENT does not port: NaN boxing is about packing a tagged union")
        (:wat::kernel::println "into a double's unused bits, and the hash-table bitmask is about a")
        (:wat::kernel::println "table wat already has. NEXT.md was right about that.")
        (:wat::kernel::println "")
        (:wat::kernel::println "Its METHOD ports completely, and it caught a mistake this repository")
        (:wat::kernel::println "had already written down. Measure the thing you are optimising, at the")
        (:wat::kernel::println "size it runs at, before believing a micro-benchmark about it. That is")
        (:wat::kernel::println "the third time this section has landed on the same shape: C-103 found")
        (:wat::kernel::println "interning worth nothing at Lox's string lengths, C-098 and C-099 found")
        (:wat::kernel::println "the cost was the number of operations rather than what each touched,")
        (:wat::kernel::println "and now a container choice reverses below 256 elements.")
        (:wat::kernel::println "")
        (:wat::kernel::println "The per-instruction figures above are the ones to keep for wat's own")
        (:wat::kernel::println "byte-code work: that is what an interpreted VM hosted in an interpreter")
        (:wat::kernel::println "costs, and no container will move it much.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
