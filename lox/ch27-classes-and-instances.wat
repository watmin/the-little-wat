;; Crafting Interpreters chapter 27 (classes and instances), in wat.
;;
;; Two new object types -- a class, and an instance with a field table -- and three instructions.
;; Nystrom's chapter is short because the hard parts (methods, `this`, inheritance) come later.
;; The hard part HERE is one wat does not have a spelling for:
;;
;;   `var a = f; a.x = 2; print f.x;`   must print 2
;;
;; That is REFERENCE SEMANTICS: two names for one mutable object. A wat value cannot provide it --
;; assignment copies, and there is no way for two values to share a mutable location. So an
;; instance became an ID into a VM-owned table, exactly as chapter 25's upvalue became a cell id.
;; **That is the second time in three chapters that identity-with-mutation forced the same
;; indirection**, and the two together are the honest summary of what wat's value model costs a
;; language implementation: nothing you cannot build, and a table you have to build.
;;
;; A CLASS, by contrast, is immutable once declared, so it is an ordinary value. Its methods are
;; added while it sits on the stack -- OP_METHOD rebuilds the value in its slot -- and the
;; finished class is stored back into its binding at the end of the declaration. Nothing can
;; observe the class before then, so the visible behaviour matches Nystrom's in-place mutation.
;;
;; Run: wat lox/ch27-classes-and-instances.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c27::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c27::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
(:wat::core::defn :c27::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))
(:wat::core::defn :c27::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile-program src))))
(:wat::core::defn :c27::objs [src <- :wat::core::String] -> :wat::core::String
  (:c27::int (:loxv::live-objs (:loxv::Run/objs
    (:loxv::run-full (:loxv::C/chunk (:loxv::compile-program src)))) 0 0)))
(:wat::core::defn :c27::objs-nogc [src <- :wat::core::String] -> :wat::core::String
  (:c27::int (:loxv::live-objs (:loxv::Run/objs
    (:loxv::run-nogc (:loxv::C/chunk (:loxv::compile-program src)))) 0 0)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- what classes and instances must satisfy ----")
    (:wat::core::let
      [rs
       [;; A CLASS IS A VALUE
        (:c27::expect "a class prints its name    " (:c27::run "class Foo {} print Foo;") "Foo")
        (:c27::expect "and is truthy              " (:c27::run "class Foo {} if (Foo) print \"yes\";") "yes")
        (:c27::expect "the emitted declaration    " (:c27::code "class Foo {}")
          "CLASS/0 DEFG/0 GETG/1 SETG/0 POP RET")
        (:c27::expect "a class is not a number    " (:c27::run "class Foo {} print Foo == 1;") "false")
        (:c27::expect "a local class works too    "
          (:c27::run "fun f() { class Foo {} return Foo; } print f();") "Foo")

        ;; INSTANTIATION
        (:c27::expect "calling a class            " (:c27::run "class Foo {} print Foo();") "<instance>")
        (:c27::expect "an instance is truthy      " (:c27::run "class Foo {} if (Foo()) print \"yes\";") "yes")
        (:c27::expect "and is not its class       " (:c27::run "class Foo {} print Foo() == Foo;") "false")
        (:c27::expect "two instances differ       " (:c27::run "class Foo {} print Foo() == Foo();") "false")
        (:c27::expect "one equals itself          " (:c27::run "class Foo {} var f = Foo(); print f == f;") "true")
        (:c27::expect "arguments without an init  " (:c27::run "class Foo {} Foo(1);")
          "[line 1] Runtime error: Expected 0 arguments but got 1.")

        ;; FIELDS
        (:c27::expect "set then get               " (:c27::run "class Foo {} var f = Foo(); f.x = 1; print f.x;") "1")
        (:c27::expect "setting is an expression   " (:c27::run "class Foo {} var f = Foo(); print f.x = 7;") "7")
        (:c27::expect "a field can be overwritten " (:c27::run "class Foo {} var f = Foo(); f.x = 1; f.x = 2; print f.x;") "2")
        (:c27::expect "two fields                 " (:c27::run "class Foo {} var f = Foo(); f.x = 1; f.y = 2; print f.x + f.y;") "3")
        (:c27::expect "a field can hold anything  " (:c27::run "class Foo {} var f = Foo(); f.x = Foo(); f.x.y = 5; print f.x.y;") "5")
        (:c27::expect "chained access             " (:c27::run "class Foo {} var a = Foo(); var b = Foo(); a.n = b; b.v = 3; print a.n.v;") "3")
        (:c27::expect "a field holding a function "
          (:c27::run "class Foo {} fun g() { return 4; } var f = Foo(); f.m = g; print f.m();") "4")

        ;; **REFERENCE SEMANTICS** -- the property that forced the object table
        (:c27::expect "two names, one object      "
          (:c27::run "class Foo {} var f = Foo(); var g = f; g.x = 2; print f.x;") "2")
        (:c27::expect "and the other way round    "
          (:c27::run "class Foo {} var f = Foo(); var g = f; f.x = 3; print g.x;") "3")
        (:c27::expect "through a function         "
          (:c27::run "class Foo {} fun set(o) { o.x = 9; } var f = Foo(); set(f); print f.x;") "9")
        (:c27::expect "and a returned instance    "
          (:c27::run "class Foo {} fun mk() { var o = Foo(); o.x = 1; return o; } var f = mk(); f.x = 2; print f.x;") "2")
        (:c27::expect "stored in a field          "
          (:c27::run "class Foo {} var a = Foo(); var b = Foo(); a.n = b; a.n.v = 1; print b.v;") "1")

        ;; ERRORS
        (:c27::expect "an undefined property      " (:c27::run "class Foo {} print Foo().nope;")
          "[line 1] Runtime error: Undefined property 'nope'.")
        (:c27::expect "a property of a number     " (:c27::run "var x = 1; print x.y;")
          "[line 1] Runtime error: Only instances have properties.")
        (:c27::expect "of a string                " (:c27::run "print \"a\".y;")
          "[line 1] Runtime error: Only instances have properties.")
        (:c27::expect "of nil                     " (:c27::run "nil.y = 1;")
          "[line 1] Runtime error: Only instances have properties.")
        (:c27::expect "of a class                 " (:c27::run "class Foo {} print Foo.y;")
          "[line 1] Runtime error: Only instances have properties.")
        (:c27::expect "a missing property name    " (:c27::run "class Foo {} Foo().;")
          "[line 1] Error: Expect property name after '.'.")
        (:c27::expect "a missing class name       " (:c27::run "class {}")
          "[line 1] Error: Expect class name.")
        (:c27::expect "a missing brace            " (:c27::run "class Foo")
          "[line 1] Error: Expect '{' before class body.")
        ;; canAssign, in its third setting: a property is an lvalue, an expression is not
        (:c27::expect "a.b + 1 = c is refused     " (:c27::run "class Foo {} var f = Foo(); f.x + 1 = 2;")
          "[line 1] Error: Invalid assignment target.")

        ;; AND THE COLLECTOR KNOWS ABOUT INSTANCES. Chapter 26's mark-sweep was extended in the
        ;; same move that added the object table, so an unreachable instance is reclaimed.
        (:c27::expect "30 instances, no collector " (:c27::objs-nogc
          "class Foo {} for (var i = 0; i < 30; i = i + 1) { var t = Foo(); }") "30")
        (:c27::expect "30 instances, with one     " (:c27::objs
          "class Foo {} fun mk() { var o = Foo(); fun k() { return o; } return 0; } for (var i = 0; i < 30; i = i + 1) { var t = mk(); }") "1")
        (:c27::expect "a kept instance survives   "
          (:c27::run "class Foo {} var keep = Foo(); keep.x = 5; fun mk() { var o = Foo(); fun k() { return o; } return 0; } for (var i = 0; i < 30; i = i + 1) { var t = mk(); } print keep.x;") "5")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what this chapter cost in wat ----")
        (:wat::kernel::println "One line of Lox is the whole story: `var a = f; a.x = 2; print f.x;`")
        (:wat::kernel::println "must print 2. That is two names for one mutable object, and a wat value")
        (:wat::kernel::println "cannot be that -- assignment copies, and nothing can share a mutable")
        (:wat::kernel::println "location. So an instance is an ID into a table the VM owns.")
        (:wat::kernel::println "")
        (:wat::kernel::println "This is the SECOND time in three chapters the same thing happened:")
        (:wat::kernel::println "chapter 25's upvalue is a cell id for the same reason. Together they")
        (:wat::kernel::println "are the honest summary of what wat's value model costs an interpreter --")
        (:wat::kernel::println "nothing it cannot build, and a heap it has to build.")
        (:wat::kernel::println "")
        (:wat::kernel::println "The consolation is that the heap then had to be COLLECTED, and chapter")
        (:wat::kernel::println "26's collector was already there. The last three checks above are the")
        (:wat::kernel::println "same before-and-after that chapter used: thirty instances without it,")
        (:wat::kernel::println "one with it, and a kept instance still answering 5.")
        (:wat::kernel::println "")
        (:wat::kernel::println "A CLASS needed none of this. It is immutable once declared, so it is an")
        (:wat::kernel::println "ordinary value that OP_METHOD rebuilds in its stack slot -- and because")
        (:wat::kernel::println "nothing can observe a class until its declaration ends, that is")
        (:wat::kernel::println "indistinguishable from Nystrom's mutation in place.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
