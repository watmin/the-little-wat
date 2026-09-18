;; Crafting Interpreters chapter 25 (closures), in wat.
;;
;; The chapter where a function stops being code and becomes code PLUS captured state. And it is
;; the chapter where this port had a real problem to solve rather than a translation to perform.
;;
;; **Nystrom's upvalue is a pointer into the stack.** `ObjUpvalue` holds a `Value* location`;
;; while the variable is alive the pointer aliases its stack slot, so a write through the closure
;; and a write through the local are the same write. When the frame goes away the upvalue is
;; "closed": the value is copied into the object and the pointer redirected at it. Two closures
;; over one variable share it because they hold the same `ObjUpvalue*`.
;;
;; **wat has no way to share a mutable location.** There is no pointer, no reference cell, and no
;; positional update (F-104) that two values could both see. So the pointer becomes an INDEX into
;; a table the VM owns:
;;
;;   `Cell.OnStack idx`   the variable is still live; the cell is an alias for stack slot `idx`
;;   `Cell.Closed v`      the frame is gone; the cell owns the value
;;
;; A closure holds cell IDS. Two closures over one variable hold the same id, so they see each
;; other's writes -- which is the property the whole chapter exists to provide, and it is checked
;; below rather than asserted. That is not a workaround: it is Nystrom's design with the pointer
;; NAMED instead of dereferenced, which is what every implementation does that cannot alias.
;;
;; What it costs is one indirection per upvalue access and a positional write into the cell table
;; when a cell is closed -- F-104 again, paid per scope exit rather than per instruction.
;;
;; Run: wat lox/ch25-closures.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c25::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c25::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
(:wat::core::defn :c25::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))
(:wat::core::defn :c25::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile-program src))))

;; the chunk of the function value in constant slot `i` of `c`
(:wat::core::defn :c25::fn-chunk [c <- :loxv::Chunk i <- :wat::core::i64] -> :loxv::Chunk
  (:wat::core::match (:wat::core::nth (:loxv::Chunk/constants c) i)
    [:loxv::Val.Fn {:chunk fc :name nm :arity a :updescs u} fc]
    [:loxv::Val.Closure {:chunk fc :name nm :arity a :cells u} fc]
    [:loxv::Val.Nil {} c] [:loxv::Val.Bool {:b b} c] [:loxv::Val.Num {:n n} c]
    [:loxv::Val.Str {:s x} c] [:loxv::Val.Native {:name nm :arity a} c]
    [:loxv::Val.Class {:name nm :methods ms} c] [:loxv::Val.Instance {:id i} c]
    [:loxv::Val.Bound {:id i :method m} c]))

;; what the function value in constant slot `i` of `c` captures, and from where
(:wat::core::defn :c25::ups-of [c <- :loxv::Chunk i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::match (:wat::core::nth (:loxv::Chunk/constants c) i)
    [:loxv::Val.Fn {:chunk fc :name nm :arity a :updescs u}
      (:wat::string::trim
        (:wat::core::foldl
          (:wat::core::fn [acc <- :wat::core::String d <- :loxv::UpDesc] -> :wat::core::String
            (:wat::string::concat acc " "
              (:wat::core::if (:loxv::UpDesc/is-local d) "local/" "up/")
              (:wat::i64::to-string (:loxv::UpDesc/index d))))
          "" u))]
    [:loxv::Val.Closure {:chunk fc :name nm :arity a :cells u} "(already a closure)"]
    [:loxv::Val.Nil {} "(not a function)"] [:loxv::Val.Bool {:b b} "(not a function)"]
    [:loxv::Val.Num {:n n} "(not a function)"] [:loxv::Val.Str {:s x} "(not a function)"]
    [:loxv::Val.Native {:name nm :arity a} "(not a function)"]
    [:loxv::Val.Class {:name nm :methods ms} "(not a function)"]
    [:loxv::Val.Instance {:id i} "(not a function)"]
    [:loxv::Val.Bound {:id i :method m} "(not a function)"]))

;; the first constant of `c` that is a function. Slot numbers move as literals are added, and a
;; test that has to count them is a test about the wrong thing.
(:wat::core::defn :c25::is-fn? [c <- :loxv::Chunk i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::match (:wat::core::nth (:loxv::Chunk/constants c) i)
    [:loxv::Val.Fn {:chunk fc :name nm :arity a :updescs u} true]
    [:loxv::Val.Closure {:chunk fc :name nm :arity a :cells u} true]
    [:loxv::Val.Nil {} false] [:loxv::Val.Bool {:b b} false] [:loxv::Val.Num {:n n} false]
    [:loxv::Val.Str {:s x} false] [:loxv::Val.Native {:name nm :arity a} false]
    [:loxv::Val.Class {:name nm :methods ms} false] [:loxv::Val.Instance {:id i} false]
    [:loxv::Val.Bound {:id i :method m} false]))

(:wat::core::defn :c25::fn-slot [c <- :loxv::Chunk i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length (:loxv::Chunk/constants c))) -1)
    ((:c25::is-fn? c i) i)
    (:else (:c25::fn-slot c (:wat::core::+ i 1)))))

(:wat::core::defn :c25::fn-at [c <- :loxv::Chunk] -> :loxv::Chunk
  (:c25::fn-chunk c (:c25::fn-slot c 0)))

(:wat::core::defn :c25::script [src <- :wat::core::String] -> :loxv::Chunk
  (:loxv::C/chunk (:loxv::compile-program src)))

;; every program below declares one top-level function, so its value is script constant 1 and
;; its own first function constant is slot 1 of that
(:wat::core::defn :c25::outer-code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:c25::fn-at (:c25::script src))))

(:wat::core::defn :c25::inner-code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:c25::fn-at (:c25::fn-at (:c25::script src)))))

(:wat::core::defn :c25::inner-ups [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [o (:c25::fn-at (:c25::script src))]
    (:c25::ups-of o (:c25::fn-slot o 0))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- what closures must satisfy ----")
    (:wat::core::let
      [rs
       [;; THE BOOK'S OWN EXAMPLE, both halves: called inside the scope, and called after it
        (:c25::expect "an inner function reads x  "
          (:c25::run "fun outer() { var x = \"outside\"; fun inner() { print x; } inner(); } outer();") "outside")
        (:c25::expect "and still reads it after   "
          (:c25::run "fun outer() { var x = \"outside\"; fun inner() { print x; } return inner; } var c = outer(); c();")
          "outside")
        ;; the second line is the one that needs CLOSING: `x`'s stack slot is gone by then

        ;; SHARED MUTABLE STATE -- the property the chapter exists for
        (:c25::expect "a counter keeps its count  "
          (:c25::run "fun mk() { var n = 0; fun inc() { n = n + 1; return n; } return inc; } var c = mk(); print c(); print c(); print c();")
          "1|2|3")
        (:c25::expect "two closures SHARE one var "
          (:c25::run "fun mk() { var n = 0; fun up() { n = n + 1; } fun get() { return n; } up(); up(); return get; } print mk()();")
          "2")
        (:c25::expect "  even after the scope ends"
          (:c25::run "fun mk() { var n = 0; fun up() { n = n + 1; } fun get() { return n; } return up; } var u = mk(); u();")
          "")
        (:c25::expect "two CALLS do not share     "
          (:c25::run "fun mk() { var n = 0; fun inc() { n = n + 1; return n; } return inc; } var a = mk(); var b = mk(); print a(); print a(); print b();")
          "1|2|1")
        (:c25::expect "a write through the closure"
          (:c25::run "fun mk() { var n = 1; fun set() { n = 99; } fun get() { return n; } set(); return get; } print mk()();")
          "99")
        (:c25::expect "  is seen by the LOCAL too "
          (:c25::run "fun outer() { var n = 1; fun set() { n = 99; } set(); return n; } print outer();")
          "99")

        ;; CAPTURE THROUGH LEVELS -- resolveUpvalue recursing, and add-upvalue on each level
        (:c25::expect "two levels up              "
          (:c25::run "fun a() { var x = 1; fun b() { fun c() { return x; } return c(); } return b(); } print a();") "1")
        (:c25::expect "three levels up            "
          (:c25::run "fun a() { var x = 5; fun b() { fun c() { fun d() { return x; } return d(); } return c(); } return b(); } print a();") "5")
        (:c25::expect "and surviving all of them  "
          (:c25::run "fun a() { var x = 7; fun b() { fun c() { return x; } return c; } return b(); } print a()();") "7")
        (:c25::expect "a parameter is capturable  "
          (:c25::run "fun mk(i) { fun get() { return i; } return get; } print mk(1)(); print mk(2)();") "1|2")

        ;; WHAT CHAPTER 24 COULD NOT DO. These two lines are in ch24's file as well, where they
        ;; record the before; here they are the after.
        (:c25::expect "a local function recurses  "
          (:c25::run "fun outer() { fun down(n) { if (n == 0) return 0; return down(n - 1); } return down(5); } print outer();") "0")
        (:c25::expect "  and reads an outer local "
          (:c25::run "fun outer() { var a = 1; fun get() { return a; } return get(); } print outer();") "1")

        ;; THE COMPILER'S SIDE: what it decided to capture, and from where. Each program
        ;; declares one top-level function, so the outer function is script constant 1 and the
        ;; inner one is constant 1 of THAT chunk.
        (:c25::expect "one local captured         "
          (:c25::inner-ups "fun o() { var x = 1; fun i() { return x; } }") "local/0")
        (:c25::expect "  deduplicated to one slot "
          (:c25::inner-ups "fun o() { var x = 1; fun i() { return x + x; } }") "local/0")
        (:c25::expect "two locals captured        "
          (:c25::inner-ups "fun o() { var x = 1; var y = 2; fun i() { return x + y; } }") "local/0 local/1")
        (:c25::expect "a global is NOT captured   "
          (:c25::inner-ups "var g = 1; fun o() { fun i() { return g; } }") "")
        (:c25::expect "a parameter is a local     "
          (:c25::inner-ups "fun o(p) { fun i() { return p; } }") "local/0")

        ;; THE EMITTED CODE
        (:c25::expect "a function literal is CLOS " (:c25::code "fun f() {}") "CLOS/1 DEFG/0 RET")
        (:c25::expect "an upvalue read is GETU    "
          (:c25::inner-code "fun o() { var x = 1; fun i() { return x; } }") "GETU/0 RET NIL RET")
        (:c25::expect "and a write is SETU        "
          (:c25::inner-code "fun o() { var x = 1; fun i() { x = 2; } }") "CONST/0 SETU/0 POP NIL RET")
        ;; a function's OWN locals are never popped: the frame is discarded whole, and anything
        ;; captured out of it is closed at RETURN. Nystrom's endCompiler does not endScope either.
        (:c25::expect "a function body pops nothing"
          (:c25::outer-code "fun o() { var x = 1; fun i() { return x; } }") "CONST/0 CLOS/1 NIL RET")
        (:c25::expect "  even with no capture     "
          (:c25::outer-code "fun o() { var x = 1; }") "CONST/0 NIL RET")
        ;; a BLOCK inside a function does end, and that is where CLOSE_UPVALUE appears -- one per
        ;; captured local, POP for the rest, innermost first
        (:c25::expect "a captured local CLOSEs    "
          (:c25::outer-code "fun o() { { var x = 1; fun i() { return x; } } }")
          "CONST/0 CLOS/1 POP CLOSEU NIL RET")
        (:c25::expect "an uncaptured one POPs     "
          (:c25::outer-code "fun o() { { var x = 1; } }") "CONST/0 POP NIL RET")

        ;; IDENTITY. Chapter 24 recorded a divergence that no Lox program could reach: clox
        ;; compares functions by object identity and `=` on a wat enum is structural. A closure
        ;; carries its captured cell IDS, so two closures from two calls now differ -- and the
        ;; divergence closes itself.
        (:c25::expect "two closures differ        "
          (:c25::run "fun mk() { var n = 0; fun f() { return n; } return f; } print mk() == mk();") "false")
        (:c25::expect "and one equals itself      "
          (:c25::run "fun mk() { var n = 0; fun f() { return n; } return f; } var a = mk(); print a == a;") "true")
        (:c25::expect "a closure is truthy        "
          (:c25::run "fun mk() { fun f() {} return f; } if (mk()) print \"yes\";") "yes")
        (:c25::expect "and prints as its name     "
          (:c25::run "fun mk() { fun inner() {} return inner; } print mk();") "<fn inner>")

        ;; AND THE THINGS THAT MUST STILL HOLD
        (:c25::expect "arity is still checked     "
          (:c25::run "fun mk() { fun f(a) {} return f; } mk()();")
          "[line 1] Runtime error: Expected 1 arguments but got 0.")
        (:c25::expect "recursion still works      "
          (:c25::run "fun fib(n) { if (n < 2) return n; return fib(n-1) + fib(n-2); } print fib(12);") "144")
        (:c25::expect "and a native is still one  " (:c25::run "print double(4);") "8")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what this chapter cost in wat ----")
        (:wat::kernel::println "This is the one chapter in Part II where the book's design could not be")
        (:wat::kernel::println "translated line for line. An upvalue is a POINTER INTO THE STACK, and")
        (:wat::kernel::println "wat has no way for two values to share a mutable location -- no")
        (:wat::kernel::println "reference cell, no positional update either of them could see.")
        (:wat::kernel::println "")
        (:wat::kernel::println "So the pointer became an index into a table the VM owns, and an upvalue")
        (:wat::kernel::println "became a cell id. Everything the chapter promises then follows and is")
        (:wat::kernel::println "checked above: a closure outliving its scope, two closures sharing one")
        (:wat::kernel::println "variable, two calls NOT sharing, a write through a closure seen by the")
        (:wat::kernel::println "local, capture through three levels.")
        (:wat::kernel::println "")
        (:wat::kernel::println "That is worth stating as a positive result. `Value*` is not a language")
        (:wat::kernel::println "feature wat is missing; it is C's spelling of an indirection, and naming")
        (:wat::kernel::println "the indirection costs one table and one extra read. The parts of the C")
        (:wat::kernel::println "that DID vanish -- the open-upvalue list kept sorted by stack slot, and")
        (:wat::kernel::println "freeing the objects -- were both about the pointer, not about Lox.")
        (:wat::kernel::println "")
        (:wat::kernel::println "One thing closed itself: chapter 24 recorded that clox compares functions")
        (:wat::kernel::println "by identity where `=` here is structural, and that no Lox program could")
        (:wat::kernel::println "tell. A closure carries its cell ids, so two closures from two calls now")
        (:wat::kernel::println "differ, and the divergence is gone.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
