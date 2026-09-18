;; Crafting Interpreters chapter 26 (garbage collection), in wat.
;;
;; NEXT.md recorded this chapter as "partly covered": SICP §5.3 (C-081) already built stop-and-copy
;; with broken hearts, and Nystrom's mark-sweep is a different algorithm worth building. What that
;; note could not say, because chapter 25 had not been written yet, is that there would be a REAL
;; LEAK to collect rather than a simulated heap to model.
;;
;; wat owns its heap, so Nystrom's objects -- strings, functions, closures -- are not ours to free.
;; But chapter 25's cell table IS ours: `capture` allocates a cell every time a closure captures a
;; variable, and until this chapter nothing ever released one. A loop that makes closures grew the
;; table without bound, and the control at the bottom of this file shows it: thirty iterations,
;; thirty cells, none of them reachable.
;;
;; So this is a mark-sweep collector over a real leak. The roots are the roots clox has -- the
;; value stack, the globals, and every frame's captured cells -- and marking is transitive,
;; because a closed cell can hold a closure that captured cells of its own. The one structural
;; difference is that a table cannot forget an index: a swept slot becomes `Cell.Free` and is
;; reused, which is a free list spelled as a scan.
;;
;; Every claim below is checked against `run-nogc`, the same VM with the collector's threshold put
;; out of reach. A GC chapter without that control is a chapter about an opinion.
;;
;; Run: wat lox/ch26-garbage-collection.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c26::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c26::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
(:wat::core::defn :c26::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))

(:wat::core::defn :c26::chunk [src <- :wat::core::String] -> :loxv::Chunk
  (:loxv::C/chunk (:loxv::compile-program src)))

;; the cell table's SIZE with the collector on, and with it out of reach
(:wat::core::defn :c26::table [src <- :wat::core::String] -> :wat::core::String
  (:c26::int (:wat::core::length (:loxv::Run/cells (:loxv::run-full (:c26::chunk src))))))

(:wat::core::defn :c26::table-nogc [src <- :wat::core::String] -> :wat::core::String
  (:c26::int (:wat::core::length (:loxv::Run/cells (:loxv::run-nogc (:c26::chunk src))))))

(:wat::core::defn :c26::live [src <- :wat::core::String] -> :wat::core::String
  (:c26::int (:loxv::live-cells (:loxv::Run/cells (:loxv::run-full (:c26::chunk src))) 0 0)))

(:wat::core::defn :c26::live-nogc [src <- :wat::core::String] -> :wat::core::String
  (:c26::int (:loxv::live-cells (:loxv::Run/cells (:loxv::run-nogc (:c26::chunk src))) 0 0)))

(:wat::core::defn :c26::gcs [src <- :wat::core::String] -> :wat::core::String
  (:c26::int (:loxv::Run/collections (:loxv::run-full (:c26::chunk src)))))

;; the programs the chapter measures: one closure per iteration, none of them kept
(:wat::core::defn :c26::garbage [] -> :wat::core::String
  "for (var i = 0; i < 30; i = i + 1) { var x = i; fun f() { return x; } }")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- what the collector must satisfy ----")
    (:wat::core::let
      [rs
       [;; THE LEAK, AND THE CONTROL. Same program, same VM, threshold moved.
        (:c26::expect "30 closures, no collector  " (:c26::table-nogc (:c26::garbage)) "30")
        (:c26::expect "  all of them still 'live' " (:c26::live-nogc (:c26::garbage)) "30")
        (:c26::expect "30 closures, with collector" (:c26::table (:c26::garbage)) "8")
        (:c26::expect "  and one cell live at end " (:c26::live (:c26::garbage)) "1")
        (:c26::expect "  having collected 22 times" (:c26::gcs (:c26::garbage)) "22")
        ;; the table stops growing, which is the whole claim: 40 iterations, same 8 slots
        (:c26::expect "40 closures, same table    "
          (:c26::table "fun mk(i) { fun g() { return i; } return g; } for (var j = 0; j < 40; j = j + 1) { var t = mk(j); }") "8")
        (:c26::expect "  where without it, 40     "
          (:c26::table-nogc "fun mk(i) { fun g() { return i; } return g; } for (var j = 0; j < 40; j = j + 1) { var t = mk(j); }") "40")

        ;; EVERY ROOT. A closure is kept in each of the four places the VM can hold one, and must
        ;; still answer correctly after twenty collections have run underneath it.
        (:c26::expect "a GLOBAL root survives     "
          (:c26::run "fun mk(i) { fun g() { return i; } return g; } var keep = mk(7); for (var j = 0; j < 20; j = j + 1) { var t = mk(j); } print keep();") "7")
        (:c26::expect "a STACK root survives      "
          (:c26::run "fun mk(i) { fun g() { return i; } return g; } { var keep = mk(9); for (var j = 0; j < 20; j = j + 1) { var t = mk(j); } print keep(); }") "9")
        (:c26::expect "a SUSPENDED FRAME's root   "
          (:c26::run "fun mk(i) { fun g() { return i; } return g; } fun outer() { var keep = mk(3); for (var j = 0; j < 20; j = j + 1) { var t = mk(j); } return keep(); } print outer();") "3")
        ;; TRANSITIVE: `o` captured `inner`, and `inner` captured `n`. Marking `o`'s cell is not
        ;; enough -- the closure INSIDE that cell has cells of its own. This is clox's grey stack.
        (:c26::expect "a cell reached through one "
          (:c26::run "fun mk() { var n = 5; fun inner() { return n; } fun outer() { return inner; } return outer; } var o = mk(); fun junk(i) { fun g() { return i; } return g; } for (var j = 0; j < 20; j = j + 1) { var t = junk(j); } print o()();") "5")

        ;; STATE IS PRESERVED ACROSS COLLECTIONS: a counter keeps counting
        (:c26::expect "a counter counts through it"
          (:c26::run "fun mk() { var n = 0; fun inc() { n = n + 1; return n; } return inc; } var c = mk(); fun junk(i) { fun g() { return i; } return g; } for (var j = 0; j < 20; j = j + 1) { var t = junk(j); } print c(); print c();")
          "1|2")
        (:c26::expect "and sharing survives too   "
          (:c26::run "fun mk() { var n = 0; fun up() { n = n + 1; } fun get() { return n; } return get; } var g = mk(); fun junk(i) { fun h() { return i; } return h; } for (var j = 0; j < 20; j = j + 1) { var t = junk(j); } print g();")
          "0")

        ;; SLOTS ARE REUSED, not appended: the table's SIZE is the high-water mark, and a program
        ;; that keeps three closures alive across collections still fits in the same eight slots
        (:c26::expect "three kept, table still 8  "
          (:c26::table "fun mk(i) { fun g() { return i; } return g; } var a = mk(1); var b = mk(2); var c = mk(3); for (var j = 0; j < 20; j = j + 1) { var t = mk(j); }") "8")
        (:c26::expect "  with 4 live at the end   "
          (:c26::live "fun mk(i) { fun g() { return i; } return g; } var a = mk(1); var b = mk(2); var c = mk(3); for (var j = 0; j < 20; j = j + 1) { var t = mk(j); }") "4")
        (:c26::expect "  and all three answer     "
          (:c26::run "fun mk(i) { fun g() { return i; } return g; } var a = mk(1); var b = mk(2); var c = mk(3); for (var j = 0; j < 20; j = j + 1) { var t = mk(j); } print a(); print b(); print c();")
          "1|2|3")

        ;; A PROGRAM WITH NOTHING TO COLLECT never collects
        (:c26::expect "no closures, no cells      " (:c26::table "var a = 1; print a;") "0")
        (:c26::expect "  and no collections       " (:c26::gcs "var a = 1; print a;") "0")
        (:c26::expect "a closure that captures    " (:c26::table "fun o() { var x = 1; fun i() { return x; } return i; } var f = o(); print f();") "1")
        (:c26::expect "a function capturing none  " (:c26::table "fun f() { return 1; } print f();") "0")

        ;; AND THE VM STILL WORKS. Every previous chapter's semantics, under a running collector.
        (:c26::expect "recursion                  "
          (:c26::run "fun fib(n) { if (n < 2) return n; return fib(n-1) + fib(n-2); } print fib(12);") "144")
        (:c26::expect "closures                   "
          (:c26::run "fun mk() { var n = 0; fun inc() { n = n + 1; return n; } return inc; } var c = mk(); print c(); print c(); print c();") "1|2|3")
        (:c26::expect "arity errors               " (:c26::run "fun f(a) {} f();")
          "[line 1] Runtime error: Expected 1 arguments but got 0.")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what this chapter is, and is not ----")
        (:wat::kernel::println "It is NOT a model. wat owns its heap, so Nystrom's objects are not ours")
        (:wat::kernel::println "to free -- but chapter 25's cell table is, and until this chapter it")
        (:wat::kernel::println "leaked: one cell per capture, released never. The control above is the")
        (:wat::kernel::println "proof, and it is the number a reader should keep: thirty iterations,")
        (:wat::kernel::println "THIRTY cells with the collector out of reach and EIGHT with it running.")
        (:wat::kernel::println "")
        (:wat::kernel::println "Two things the C does that this does not need. Nystrom keeps the open")
        (:wat::kernel::println "upvalues in a list sorted by stack slot, so closing a frame's upvalues")
        (:wat::kernel::println "can stop early; a table is scanned instead. And his sweep unlinks and")
        (:wat::kernel::println "frees; a table cannot forget an index, so a swept slot is marked free")
        (:wat::kernel::println "and reused -- which is why the table above STOPS at eight rather than")
        (:wat::kernel::println "growing and shrinking.")
        (:wat::kernel::println "")
        (:wat::kernel::println "The part that ports exactly is the part that matters: roots, transitive")
        (:wat::kernel::println "marking, and a sweep. A closed cell can hold a closure with cells of its")
        (:wat::kernel::println "own, so marking runs to a fixpoint -- clox's grey stack, and the check")
        (:wat::kernel::println "above that reads 5 through two levels is what tests it.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
