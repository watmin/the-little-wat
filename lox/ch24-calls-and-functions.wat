;; Crafting Interpreters chapter 24 (calls and functions), in wat.
;;
;; The centre of Part II. A function becomes a VALUE with its own chunk; the compiler becomes a
;; stack of compilers, one per function being compiled; the VM grows call frames, each with its
;; own instruction pointer and its own window into the shared value stack; and arity, callability
;; and stack depth become runtime errors. Native functions arrive too.
;;
;; Three wat-shaped decisions are worth stating, because each one was a question before it was an
;; answer:
;;
;;   1. **A function value holds a chunk, and a chunk's constant pool holds values.** That is a
;;      `defenum` recursive through a `defrecord`, which wat accepts -- checked before it was
;;      relied on, not assumed.
;;   2. **A native is a NAME, not a closure.** Nystrom stores a C function pointer in the value.
;;      A closure cannot live in a `:wat::enum::Pure` (F-114), so `Val.Native` carries a name and
;;      the VM dispatches on it -- which is what a table of function pointers is, spelled as a
;;      match. Three natives are installed: `clock`, and `double`/`answer` so that a native's
;;      RESULT can be checked and not only its type.
;;   3. **The current frame rides in the loop's arguments; only enclosing frames are a vector.**
;;      C-098 measured what a record per instruction costs, so `ip` is a loop argument and a
;;      frame record is allocated per CALL. F-104's rebuild is then paid per RETURN rather than
;;      per instruction -- the difference between a tax and a disaster.
;;
;; And F-019 was met twice in the ordinary course of writing this, both times where the finding
;; says it will be: a bare `(:loxv::Val.Native {…})` has the VARIANT's type and a `HashMap` of
;; `Val` refuses it. A helper whose declared return type is the enum widens it. That is P-006.
;;
;; Run: wat lox/ch24-calls-and-functions.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c24::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c24::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
(:wat::core::defn :c24::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))
(:wat::core::defn :c24::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile-program src))))

(:wat::core::defn :c24::stack-left [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:loxv::run (:loxv::C/chunk (:loxv::compile-program src)))
    [:loxv::Out.Ok {:stack s :globals g :out o :steps k} (:c24::int (:wat::core::length s))]
    [:loxv::Out.Err {:msg m :line l :out o :steps k} "(runtime error)"]))

;; the code of the FUNCTION in constant slot 0, not of the enclosing script
(:wat::core::defn :c24::fn-code [src <- :wat::core::String slot <- :wat::core::i64] -> :wat::core::String
  (:wat::core::match (:wat::core::nth (:loxv::Chunk/constants (:loxv::C/chunk (:loxv::compile-program src))) slot)
    [:loxv::Val.Fn {:chunk c :name nm :arity a} (:loxv::code-sig c)]
    [:loxv::Val.Nil {} "(not a function)"] [:loxv::Val.Bool {:b b} "(not a function)"]
    [:loxv::Val.Num {:n n} "(not a function)"] [:loxv::Val.Str {:s x} "(not a function)"]
    [:loxv::Val.Native {:name nm :arity a} "(not a function)"]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- what functions must satisfy ----")
    (:wat::core::let
      [rs
       [;; DECLARING AND CALLING
        (:c24::expect "a function runs            " (:c24::run "fun f() { print 1; } f();") "1")
        (:c24::expect "arguments arrive           " (:c24::run "fun add(a, b) { return a + b; } print add(2, 3);") "5")
        (:c24::expect "a return value comes back  " (:c24::run "fun f() { return 7; } print f();") "7")
        (:c24::expect "no return means nil        " (:c24::run "fun f() {} print f();") "nil")
        (:c24::expect "a bare return means nil    " (:c24::run "fun f() { return; } print f();") "nil")
        (:c24::expect "a function is a value      " (:c24::run "fun f() {} print f;") "<fn f>")
        (:c24::expect "and can be passed          "
          (:c24::run "fun twice(g) { return g(g(1)); } fun inc(n) { return n + 1; } print twice(inc);") "3")
        (:c24::expect "and returned               "
          (:c24::run "fun mk() { fun inner() { return 9; } return inner; } var h = mk(); print h();") "9")
        (:c24::expect "calls chain                "
          (:c24::run "fun mk() { fun inner() { return 9; } return inner; } print mk()();") "9")

        ;; RECURSION -- the reason a function name is marked initialized BEFORE its body
        (:c24::expect "fib(10)                    "
          (:c24::run "fun fib(n) { if (n < 2) return n; return fib(n-1) + fib(n-2); } print fib(10);") "55")
        (:c24::expect "factorial                  "
          (:c24::run "fun f(n) { if (n <= 1) return 1; return n * f(n - 1); } print f(6);") "720")
        (:c24::expect "mutual recursion           "
          (:c24::run "fun even(n) { if (n == 0) return true; return odd(n - 1); } fun odd(n) { if (n == 0) return false; return even(n - 1); } print even(10);")
          "true")
        ;; THE CHAPTER'S CAPABILITY BOUNDARY, and my first version of this line got it wrong.
        ;; A local function CAN be called from the scope that declared it -- `inner` below is a
        ;; local of `outer`, and `outer` resolves it as a local:
        (:c24::expect "a local function is callable"
          (:c24::run "fun outer() { fun inner() { return 5; } return inner() + 1; } print outer();") "6")
        ;; but it CANNOT refer to itself, because the reference is inside ITS OWN body, where the
        ;; name is a local of the ENCLOSING function. `resolveLocal` only looks at the current
        ;; compiler; `resolveUpvalue` is chapter 25. So this is a global lookup that fails --
        ;; which is exactly what clox does at this point in the book, and what chapter 25 fixes.
        (:c24::expect "but cannot recurse yet     "
          (:c24::run "fun outer() { fun down(n) { if (n == 0) return 0; return down(n - 1); } return down(5); } print outer();")
          "[line 1] Runtime error: Undefined variable 'down'.")
        (:c24::expect "  nor read an outer local  "
          (:c24::run "fun outer() { var a = 1; fun get() { return a; } return get(); } print outer();")
          "[line 1] Runtime error: Undefined variable 'a'.")

        ;; FRAMES: locals are frame-relative, so the same body works at any depth
        (:c24::expect "each call has its own local"
          (:c24::run "fun f(n) { var m = n * 2; if (n > 0) print f(n - 1); return m; } print f(2);") "0|2|4")
        (:c24::expect "a parameter shadows a global"
          (:c24::run "var a = 1; fun f(a) { return a; } print f(9); print a;") "9|1")
        (:c24::expect "and the stack unwinds      " (:c24::stack-left "fun f(a,b) { return a+b; } f(1,2); f(3,4);") "0")

        ;; ARITY AND CALLABILITY
        (:c24::expect "too few arguments          " (:c24::run "fun f(a) {} f();")
          "[line 1] Runtime error: Expected 1 arguments but got 0.")
        (:c24::expect "too many                   " (:c24::run "fun f() {} f(1);")
          "[line 1] Runtime error: Expected 0 arguments but got 1.")
        (:c24::expect "calling a number           " (:c24::run "var x = 1; x();")
          "[line 1] Runtime error: Can only call functions and classes.")
        (:c24::expect "calling a string           " (:c24::run "\"a\"();")
          "[line 1] Runtime error: Can only call functions and classes.")
        (:c24::expect "calling nil                " (:c24::run "nil();")
          "[line 1] Runtime error: Can only call functions and classes.")
        (:c24::expect "unbounded recursion        " (:c24::run "fun f() { return f(); } f();")
          "[line 1] Runtime error: Stack overflow.")

        ;; NATIVES
        (:c24::expect "a native with no arguments " (:c24::run "print answer();") "42")
        (:c24::expect "a native with one          " (:c24::run "print double(21);") "42")
        (:c24::expect "a native is a value        " (:c24::run "print clock;") "<native fn>")
        (:c24::expect "clock answers a number     "
          (:c24::run "var t = clock(); print t == t;") "true")
        (:c24::expect "a native checks arity too  " (:c24::run "double();")
          "[line 1] Runtime error: Expected 1 arguments but got 0.")
        (:c24::expect "and its operand type       " (:c24::run "double(\"x\");")
          "[line 1] Runtime error: Operand must be a number.")
        (:c24::expect "a native can be passed     "
          (:c24::run "fun apply(g, x) { return g(x); } print apply(double, 4);") "8")

        ;; COMPILE ERRORS THIS CHAPTER ADDS
        (:c24::expect "return at the top level    " (:c24::run "return 1;")
          "[line 1] Error: Can't return from top-level code.")
        (:c24::expect "a function with no name    " (:c24::run "fun () {}")
          "[line 1] Error: Expect function name.")
        (:c24::expect "a missing parameter name   " (:c24::run "fun f(1) {}")
          "[line 1] Error: Expect parameter name.")
        (:c24::expect "a missing body             " (:c24::run "fun f()")
          "[line 1] Error: Expect '{' before function body.")
        (:c24::expect "a missing close paren      " (:c24::run "fun f() {} f(1;")
          "[line 1] Error: Expect ')' after arguments.")

        ;; THE EMITTED CODE. A function declaration is a CONSTANT plus a define; the body lives
        ;; in its own chunk, which is why the script's code says nothing about it.
        (:c24::expect "a declaration is a constant" (:c24::code "fun f() {}") "CONST/1 DEFG/0 RET")
        (:c24::expect "the body is its own chunk  " (:c24::fn-code "fun f() { return 7; }" 1)
          "CONST/0 RET NIL RET")
        (:c24::expect "a call is CALL/n           " (:c24::code "fun f(a,b) {} f(1,2);")
          "CONST/1 DEFG/0 GETG/2 CONST/3 CONST/4 CALL/2 POP RET")
        (:c24::expect "a parameter is local slot 0" (:c24::fn-code "fun f(a) { return a; }" 1)
          "GETL/0 RET NIL RET")

        ;; EQUALITY: Nystrom compares object IDENTITY; `=` on a wat enum is structural, so two
        ;; functions with the same name and the same body would compare equal where clox says no.
        ;; Lox cannot express that case (a name may be declared once per scope), so the
        ;; divergence is unreachable from the language -- but it is real, and it is recorded.
        (:c24::expect "a function equals itself   " (:c24::run "fun f() {} print f == f;") "true")
        (:c24::expect "and differs from another   " (:c24::run "fun f() {} fun g() {} print f == g;") "false")
        (:c24::expect "a function is truthy       " (:c24::run "fun f() {} if (f) print \"yes\";") "yes")
        (:c24::expect "and is not a number        " (:c24::run "fun f() {} print f == 1;") "false")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what this chapter cost in wat ----")
        (:wat::kernel::println "Less than chapters 22 and 23 did, and for a reason worth keeping: a")
        (:wat::kernel::println "call frame is allocated per CALL, not per instruction. The current")
        (:wat::kernel::println "frame's chunk, ip and base ride in the loop's arguments -- C-098's")
        (:wat::kernel::println "threaded shape -- and only enclosing frames go in a vector, so F-104's")
        (:wat::kernel::println "rebuild is paid on return rather than on every step.")
        (:wat::kernel::println "")
        (:wat::kernel::println "The one place wat said no was the native function. Nystrom stores a C")
        (:wat::kernel::println "function pointer IN the value; a closure cannot live in a Pure enum")
        (:wat::kernel::println "(F-114), so a native is a name and the VM dispatches on it. That is not")
        (:wat::kernel::println "a workaround so much as the same table written as a match -- and unlike")
        (:wat::kernel::println "the C, a native that is not installed is a diagnosable error rather")
        (:wat::kernel::println "than a jump through a null pointer.")
        (:wat::kernel::println "")
        (:wat::kernel::println "One real divergence, recorded because it is unreachable rather than")
        (:wat::kernel::println "absent: clox compares functions by OBJECT IDENTITY and `=` on a wat enum")
        (:wat::kernel::println "is structural, so two functions with the same name and body would be")
        (:wat::kernel::println "equal here. Lox has no way to make two such functions, so no program")
        (:wat::kernel::println "can tell -- until chapter 25 gives closures their own captured state.")
        (:wat::kernel::println "")
        (:wat::kernel::println "One expectation here was wrong on the first run, and the fix was to the")
        (:wat::kernel::println "expectation: a local function cannot yet refer to itself, because the")
        (:wat::kernel::println "reference lives inside its own body where the name is a local of the")
        (:wat::kernel::println "ENCLOSING compiler. resolveLocal does not look there; resolveUpvalue is")
        (:wat::kernel::println "chapter 25. Two checks now pin that boundary, so chapter 25 will have to")
        (:wat::kernel::println "move them rather than quietly widen.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
