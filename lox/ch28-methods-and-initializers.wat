;; Crafting Interpreters chapter 28 (methods and initializers), in wat.
;;
;; Methods, `this`, bound methods, and `init`. The chapter's insight -- and the thing that makes
;; clox fast -- is that a method needs almost no new machinery: it is a closure stored in the
;; class's table, and calling one puts the RECEIVER in local slot 0 so that `this` is an ordinary
;; local variable. Everything else (upvalue capture, arity checking, returns) is chapter 24 and 25
;; working unchanged.
;;
;; That ported exactly, and it is worth saying so plainly after chapters 25 and 27, where it did
;; not. `this` is a local; a closure inside a method captures it the way it captures any local
;; (checked below); a bound method carries its receiver id; and `init` differs from a method in
;; exactly two compiled details -- a bare `return` yields `this`, and `return <expr>` is a compile
;; error.
;;
;; Run: wat lox/ch28-methods-and-initializers.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c28::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c28::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))
(:wat::core::defn :c28::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile-program src))))

;; the compiled body of the first method in the first class
(:wat::core::defn :c28::body [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:wat::core::nth (:loxv::Chunk/constants (:loxv::C/chunk (:loxv::compile-program src))) 3)
    [:loxv::Val.Fn {:chunk fc :name nm :arity a :updescs u} (:loxv::code-sig fc)]
    [:loxv::Val.Closure {:chunk fc :name nm :arity a :cells cs} "(closure)"]
    [:loxv::Val.Nil {} "(not a function)"] [:loxv::Val.Bool {:b b} "(not a function)"]
    [:loxv::Val.Num {:n n} "(not a function)"] [:loxv::Val.Str {:s x} "(not a function)"]
    [:loxv::Val.Native {:name nm :arity a} "(not a function)"]
    [:loxv::Val.Class {:name nm :methods ms} "(not a function)"]
    [:loxv::Val.Instance {:id i} "(not a function)"]
    [:loxv::Val.Bound {:id i :method m} "(not a function)"]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- what methods and initializers must satisfy ----")
    (:wat::core::let
      [rs
       [;; METHODS
        (:c28::expect "a method runs              " (:c28::run "class Foo { bar() { return 7; } } print Foo().bar();") "7")
        (:c28::expect "with arguments             " (:c28::run "class Foo { add(a, b) { return a + b; } } print Foo().add(2, 3);") "5")
        (:c28::expect "several methods            "
          (:c28::run "class Foo { a() { return 1; } b() { return 2; } } var f = Foo(); print f.a() + f.b();") "3")
        (:c28::expect "a method with no return    " (:c28::run "class Foo { m() {} } print Foo().m();") "nil")
        (:c28::expect "a method is a value        " (:c28::run "class Foo { m() {} } print Foo().m;") "<fn m>")
        (:c28::expect "  which can be stored      "
          (:c28::run "class Foo { m() { return 4; } } var g = Foo().m; print g();") "4")
        (:c28::expect "  and keeps its receiver   "
          (:c28::run "class Foo { m() { return this.x; } } var f = Foo(); f.x = 8; var g = f.m; f.x = 9; print g();") "9")
        (:c28::expect "a method's arity is checked" (:c28::run "class Foo { m(a) {} } Foo().m();")
          "[line 1] Runtime error: Expected 1 arguments but got 0.")
        (:c28::expect "the emitted declaration    " (:c28::code "class Foo { m() {} }")
          "CLASS/0 DEFG/0 GETG/1 CLOS/3 METH/2 SETG/0 POP RET")

        ;; `this` IS A LOCAL, which is the chapter's whole trick
        (:c28::expect "this reads a field         "
          (:c28::run "class Foo { m() { return this.x; } } var f = Foo(); f.x = 9; print f.m();") "9")
        (:c28::expect "this writes one            "
          (:c28::run "class Foo { m() { this.x = 3; } } var f = Foo(); f.m(); print f.x;") "3")
        (:c28::expect "this calls another method  "
          (:c28::run "class Foo { a() { return this.b() + 1; } b() { return 1; } } print Foo().a();") "2")
        (:c28::expect "this is local slot 0       " (:c28::body "class Foo { m() { return this; } }") "GETL/0 RET NIL RET")
        ;; and because it is a local, a closure inside a method captures it like any other
        (:c28::expect "a closure captures this    "
          (:c28::run "class Foo { m() { fun g() { return this.x; } return g(); } } var f = Foo(); f.x = 6; print f.m();") "6")
        (:c28::expect "  and outlives the call    "
          (:c28::run "class Foo { m() { fun g() { return this.x; } return g; } } var f = Foo(); f.x = 6; var g = f.m(); print g();") "6")
        (:c28::expect "this outside a class       " (:c28::run "print this;")
          "[line 1] Error: Can't use 'this' outside of a class.")
        (:c28::expect "  even inside a function   " (:c28::run "fun f() { return this; }")
          "[line 1] Error: Can't use 'this' outside of a class.")

        ;; A FIELD SHADOWS A METHOD -- Lox's rule, and the reason both use `.`
        (:c28::expect "a field beats a method     "
          (:c28::run "class Foo { m() { return \"method\"; } } var f = Foo(); f.m = 1; print f.m;") "1")
        (:c28::expect "  and the method is gone   "
          (:c28::run "class Foo { m() { return 1; } } var f = Foo(); f.m = 2; print f.m();")
          "[line 1] Runtime error: Can only call functions and classes.")

        ;; INITIALIZERS
        (:c28::expect "init runs on construction  "
          (:c28::run "class Foo { init() { this.x = 1; } } print Foo().x;") "1")
        (:c28::expect "init takes arguments       "
          (:c28::run "class Foo { init(a, b) { this.s = a + b; } } print Foo(1, 2).s;") "3")
        (:c28::expect "init returns the instance  "
          (:c28::run "class Foo { init() { this.x = 5; } } var f = Foo(); print f.x;") "5")
        (:c28::expect "  implicitly               " (:c28::run "class Foo { init() {} } print Foo();") "<instance>")
        (:c28::expect "a bare return in init      "
          (:c28::run "class Foo { init() { this.x = 1; return; this.x = 2; } } print Foo().x;") "1")
        (:c28::expect "  still answers the instance"
          (:c28::run "class Foo { init() { return; } } print Foo();") "<instance>")
        (:c28::expect "init's arity is checked    " (:c28::run "class Foo { init(a) {} } Foo();")
          "[line 1] Runtime error: Expected 1 arguments but got 0.")
        (:c28::expect "  in the other direction   " (:c28::run "class Foo { init() {} } Foo(1);")
          "[line 1] Runtime error: Expected 0 arguments but got 1.")
        (:c28::expect "returning a value from init" (:c28::run "class Foo { init() { return 1; } }")
          "[line 1] Error: Can't return a value from an initializer.")
        (:c28::expect "init can be called again   "
          (:c28::run "class Foo { init() { this.x = 1; } } var f = Foo(); print f.init().x;") "1")
        ;; `init` is a method name, not a keyword -- so a class without one has no `init` property
        (:c28::expect "no init, no init property  " (:c28::run "class Foo {} print Foo().init;")
          "[line 1] Runtime error: Undefined property 'init'.")

        ;; THE COMPILED DIFFERENCE between init and any other method is exactly two details
        (:c28::expect "a method ends with NIL RET " (:c28::body "class Foo { m() {} }") "NIL RET")
        (:c28::expect "an init ends with GETL/0   " (:c28::body "class Foo { init() {} }") "GETL/0 RET")

        ;; AND EVERYTHING BEFORE IT STILL WORKS, with instances in play
        (:c28::expect "recursion through a method "
          (:c28::run "class Foo { f(n) { if (n < 2) return n; return this.f(n-1) + this.f(n-2); } } print Foo().f(10);") "55")
        (:c28::expect "a method in a loop         "
          (:c28::run "class Foo { init() { this.n = 0; } bump() { this.n = this.n + 1; } } var f = Foo(); for (var i = 0; i < 5; i = i + 1) f.bump(); print f.n;") "5")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what this chapter cost in wat ----")
        (:wat::kernel::println "Nothing, and that is worth saying plainly after chapters 25 and 27.")
        (:wat::kernel::println "")
        (:wat::kernel::println "The chapter's design is that a method needs almost no new machinery: it")
        (:wat::kernel::println "is a closure in the class's table, and calling one puts the receiver in")
        (:wat::kernel::println "local slot 0 so `this` is an ordinary local. Every consequence of that")
        (:wat::kernel::println "ports for free -- including the one worth checking, that a closure")
        (:wat::kernel::println "declared inside a method captures `this` like any other local and can")
        (:wat::kernel::println "outlive the call.")
        (:wat::kernel::println "")
        (:wat::kernel::println "The compiled difference between `init` and any other method is two")
        (:wat::kernel::println "details, and the two checks above are them: a method ends NIL RET and an")
        (:wat::kernel::println "initializer ends GETL/0 RET, and `return <expr>` inside one is a compile")
        (:wat::kernel::println "error. `init` is a method NAME, not a keyword, which is why a class")
        (:wat::kernel::println "without one has no `init` property at all.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
