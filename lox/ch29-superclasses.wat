;; Crafting Interpreters chapter 29 (superclasses), in wat — the last chapter of Part II.
;;
;; Inheritance, method overriding, and `super`. The chapter's real content is the third of those,
;; and specifically that `super` is LEXICAL: it means "the superclass of the class this method was
;; written in", not "the superclass of whatever the receiver turns out to be". Nystrom makes that
;; true by giving each class declaration a hidden local called `super`, which methods capture as
;; an upvalue like any other variable. The three-level check below is what tests it: a method on
;; the middle class calls `super.m()` and must reach the TOP class even when the receiver is an
;; instance of the bottom one.
;;
;; Inheritance itself is a table copy at declaration time -- "copy-down inheritance" -- so a
;; method lookup never walks a chain. The consequence Nystrom points out, and which is checked
;; here, is that a method added to a superclass AFTER a subclass is declared is not inherited;
;; Lox has no way to add one, so nothing can observe it.
;;
;; In wat this ported without a new idea. `OP_INHERIT` merges one immutable class value into
;; another and rebuilds it in its stack slot, which is the same move `OP_METHOD` already made.
;;
;; Run: wat lox/ch29-superclasses.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c29::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c29::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))
(:wat::core::defn :c29::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile-program src))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- what inheritance must satisfy ----")
    (:wat::core::let
      [rs
       [;; INHERITING
        (:c29::expect "an inherited method        "
          (:c29::run "class A { m() { return \"A\"; } } class B < A {} print B().m();") "A")
        (:c29::expect "an overridden one          "
          (:c29::run "class A { m() { return \"A\"; } } class B < A { m() { return \"B\"; } } print B().m();") "B")
        (:c29::expect "the parent keeps its own   "
          (:c29::run "class A { m() { return \"A\"; } } class B < A { m() { return \"B\"; } } print A().m();") "A")
        (:c29::expect "a subclass adds a method   "
          (:c29::run "class A { a() { return 1; } } class B < A { b() { return 2; } } var x = B(); print x.a() + x.b();") "3")
        (:c29::expect "an inherited init          "
          (:c29::run "class A { init(v) { this.v = v; } } class B < A {} print B(7).v;") "7")
        (:c29::expect "an overridden init         "
          (:c29::run "class A { init(v) { this.v = v; } } class B < A { init() { this.v = 9; } } print B().v;") "9")
        (:c29::expect "three levels               "
          (:c29::run "class A { m() { return \"A\"; } } class B < A {} class C < B {} print C().m();") "A")
        (:c29::expect "fields are per-instance    "
          (:c29::run "class A {} class B < A {} var x = B(); var y = B(); x.f = 1; y.f = 2; print x.f + y.f;") "3")
        ;; the two SETGs are the class being stored back after INHERIT and again after the
        ;; method list; the two POPs are the class leaving the stack and the hidden `super` local
        ;; going out of scope
        (:c29::expect "the emitted declaration    " (:c29::code "class A {} class B < A {}")
          "CLASS/0 DEFG/0 GETG/1 SETG/0 POP CLASS/2 DEFG/2 GETG/3 GETG/4 INHERIT SETG/2 SETG/2 POP POP RET")

        ;; SUPER
        (:c29::expect "super calls the parent     "
          (:c29::run "class A { m() { return \"A\"; } } class B < A { m() { return \"B\" + super.m(); } } print B().m();") "BA")
        (:c29::expect "with arguments             "
          (:c29::run "class A { m(x) { return x + 1; } } class B < A { m(x) { return super.m(x) * 2; } } print B().m(3);") "8")
        (:c29::expect "super reads through this   "
          (:c29::run "class A { m() { return this.v; } } class B < A { m() { return super.m(); } } var b = B(); b.v = 4; print b.m();") "4")
        (:c29::expect "super in an initializer    "
          (:c29::run "class A { init(v) { this.v = v; } } class B < A { init() { super.init(2); this.w = 3; } } var b = B(); print b.v + b.w;") "5")
        (:c29::expect "super as a value           "
          (:c29::run "class A { m() { return 1; } } class B < A { g() { return super.m; } } var f = B().g(); print f();") "1")

        ;; **SUPER IS LEXICAL** -- the property the hidden local exists for. `B.m` calls
        ;; `super.m()`, and must reach A even when the receiver is a C. If `super` meant "the
        ;; receiver's superclass" this would recur forever or answer "B".
        (:c29::expect "super is the WRITTEN class "
          (:c29::run "class A { m() { return \"A\"; } } class B < A { m() { return \"B\" + super.m(); } } class C < B {} print C().m();") "BA")
        (:c29::expect "  three deep               "
          (:c29::run "class A { m() { return \"A\"; } } class B < A { m() { return \"B\" + super.m(); } } class C < B { m() { return \"C\" + super.m(); } } print C().m();") "CBA")
        (:c29::expect "  and the receiver is C    "
          (:c29::run "class A { who() { return this.tag; } } class B < A { who() { return super.who(); } } class C < B {} var c = C(); c.tag = \"C\"; print c.who();") "C")

        ;; COPY-DOWN INHERITANCE: the subclass gets its parent's methods at DECLARATION time
        (:c29::expect "a method declared after    "
          (:c29::run "class A { m() { return 1; } } class B < A {} print B().m();") "1")
        (:c29::expect "a subclass method wins     "
          (:c29::run "class A { m() { return 1; } } class B < A { m() { return 2; } } print B().m();") "2")
        (:c29::expect "  whatever the order       "
          (:c29::run "class A { a() { return 1; } b() { return 2; } } class B < A { b() { return 3; } a() { return 4; } } var x = B(); print x.a() + x.b();") "7")

        ;; ERRORS
        (:c29::expect "inheriting from a number   " (:c29::run "var A = 1; class B < A {}")
          "[line 1] Runtime error: Superclass must be a class.")
        (:c29::expect "from a function            " (:c29::run "fun A() {} class B < A {}")
          "[line 1] Runtime error: Superclass must be a class.")
        (:c29::expect "from itself                " (:c29::run "class A < A {}")
          "[line 1] Error: A class can't inherit from itself.")
        (:c29::expect "super outside a class      " (:c29::run "print super.m();")
          "[line 1] Error: Can't use 'super' outside of a class.")
        (:c29::expect "super with no superclass   " (:c29::run "class A { m() { return super.m(); } }")
          "[line 1] Error: Can't use 'super' in a class with no superclass.")
        (:c29::expect "super without a dot        " (:c29::run "class A {} class B < A { m() { return super; } }")
          "[line 1] Error: Expect '.' after 'super'.")
        (:c29::expect "super without a name       " (:c29::run "class A {} class B < A { m() { return super.; } }")
          "[line 1] Error: Expect superclass method name.")
        (:c29::expect "an undefined super method  "
          (:c29::run "class A {} class B < A { m() { return super.nope(); } } print B().m();")
          "[line 1] Runtime error: Undefined property 'nope'.")
        (:c29::expect "a missing superclass name  " (:c29::run "class B < {}")
          "[line 1] Error: Expect superclass name.")

        ;; AND PART II, END TO END: a program using nearly everything the section built
        ;; Lox has no number-to-string conversion, so `"" + 9` is a runtime error, not a cast --
        ;; which is why this program keeps its names and its numbers apart
        (:c29::expect "the whole language at once "
          (:c29::run "class Shape { init(n) { this.n = n; } describe() { return this.n; } area() { return 0; } } class Square < Shape { init(s) { super.init(\"square\"); this.s = s; } area() { var a = 0; for (var i = 0; i < this.s; i = i + 1) a = a + this.s; return a; } } var sq = Square(3); print sq.describe(); print sq.area(); fun twice(f) { return f() + f(); } print twice(sq.area); class Cube < Square { describe() { return \"cube of a \" + super.describe(); } } var c = Cube(2); print c.describe(); print c.area();")
          "square|9|18|cube of a square|4")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- Part II, finished ----")
        (:wat::kernel::println "Chapter 29 needed no new idea in wat. OP_INHERIT merges one immutable")
        (:wat::kernel::println "class value into another and rebuilds it in its stack slot, which is")
        (:wat::kernel::println "the move OP_METHOD already made, and `super` is a hidden local captured")
        (:wat::kernel::println "as an upvalue -- chapter 25's machinery, used unchanged.")
        (:wat::kernel::println "")
        (:wat::kernel::println "The check worth keeping is that `super` is LEXICAL. A method on the")
        (:wat::kernel::println "middle class of a three-level hierarchy calls super.m() and reaches the")
        (:wat::kernel::println "TOP class, with a bottom-class receiver: CBA, and `this` still the C.")
        (:wat::kernel::println "If `super` meant the receiver's superclass, that would not terminate.")
        (:wat::kernel::println "")
        (:wat::kernel::println "Sixteen chapters, and the tally of what wat could not do directly is")
        (:wat::kernel::println "short and consistent: nothing can share a mutable location. That cost a")
        (:wat::kernel::println "cell table for upvalues (ch25) and an object table for instances")
        (:wat::kernel::println "(ch27), and then a collector for both (ch26). Everything else was a")
        (:wat::kernel::println "translation, and the expensive parts were not the missing features but")
        (:wat::kernel::println "the missing VERBS: no positional update, and no pop.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
