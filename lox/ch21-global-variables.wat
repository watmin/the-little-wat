;; Crafting Interpreters chapter 21 (global variables), in wat.
;;
;; The chapter that turns an expression evaluator into a language: statements, `print`, `var`
;; declarations, a global table, assignment as an expression, and `synchronize()` so one bad
;; statement does not poison the rest of the file.
;;
;; Three things here are worth checking rather than assuming, and all three are Nystrom's own
;; emphases:
;;   1. An expression statement POPS. That one instruction is the whole difference between
;;      `print 1;` and `1;`, and it is what keeps a long program's stack from growing.
;;   2. Assignment is an EXPRESSION, so it leaves its value behind -- `print a = 2;` prints 2.
;;   3. `canAssign`. A prefix rule may only take a following `=` if it was reached at or below
;;      assignment precedence, which is what makes `a * b = c` a compile error rather than a
;;      silent parse of `a * (b = c)`. Nystrom calls this the subtlest bug in the chapter.
;;
;; On the wat side: the VM now has state beyond its stack -- a table of globals and an output --
;; so `Step.Next` carries three things forward instead of one, and `Out` gained two fields. That
;; second part had a cost this repository has recorded as friction and can now price: a variant
;; pattern must name EVERY field, so adding `:globals` and `:out` to `Out` broke a match in
;; ch18-types-of-values.wat that wanted neither of them.
;;
;; Run: wat lox/ch21-global-variables.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c21::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c21::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
(:wat::core::defn :c21::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))
(:wat::core::defn :c21::errs [src <- :wat::core::String] -> :wat::core::String
  (:c21::int (:loxv::program-errors src)))

(:wat::core::defn :c21::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile-program src))))

;; what the stack looks like when the program ends -- Nystrom's invariant is that it is empty
(:wat::core::defn :c21::stack-left [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:loxv::run (:loxv::C/chunk (:loxv::compile-program src)))
    [:loxv::Out.Ok {:stack s :globals g :out o :steps k} (:c21::int (:wat::core::length s))]
    [:loxv::Out.Err {:msg m :line l :out o :steps k} "(runtime error)"]))

(:wat::core::defn :c21::global [src <- :wat::core::String name <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:loxv::run (:loxv::C/chunk (:loxv::compile-program src)))
    [:loxv::Out.Ok {:stack s :globals g :out o :steps k}
      (:wat::core::match (:wat::core::get g name)
        [:wat::core::Option.Some {:value v} (:loxv::show v)]
        [:wat::core::Option.None {} "(undefined)"])]
    [:loxv::Out.Err {:msg m :line l :out o :steps k} "(runtime error)"]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "== var beverage = \"cafe au lait\"; var breakfast = \"beignets with \" + beverage; print breakfast; ==")
    (:wat::kernel::println
      (:wat::string::concat "  => "
        (:c21::run "var beverage = \"cafe au lait\"; var breakfast = \"beignets with \" + beverage; print breakfast;")))
    (:wat::kernel::println "")
    (:wat::kernel::println "---- what statements and globals must satisfy ----")
    (:wat::core::let
      [rs
       [(:c21::expect "the chapter's own example  "
          (:c21::run "var beverage = \"cafe au lait\"; var breakfast = \"beignets with \" + beverage; print breakfast;")
          "beignets with cafe au lait")

        ;; PRINT and EXPRESSION STATEMENTS
        (:c21::expect "print emits PRINT          " (:c21::code "print 1;") "CONST/0 PRINT RET")
        (:c21::expect "a bare expression POPs     " (:c21::code "1;") "CONST/0 POP RET")
        (:c21::expect "several prints, in order   " (:c21::run "print 1; print 2; print 3;") "1|2|3")
        (:c21::expect "a program may print nothing" (:c21::run "1 + 2;") "")
        (:c21::expect "and the stack ends empty   " (:c21::stack-left "1+2; 3+4; print 5;") "0")
        (:c21::expect "  after prints too         " (:c21::stack-left "print 1; print 2;") "0")
        (:c21::expect "  and after declarations   " (:c21::stack-left "var a = 1; var b = 2;") "0")

        ;; VAR DECLARATIONS
        (:c21::expect "var with an initializer    " (:c21::run "var a = 7; print a;") "7")
        (:c21::expect "var without one is nil     " (:c21::run "var a; print a;") "nil")
        (:c21::expect "the name is constant 0     " (:c21::code "var a = 1;") "CONST/1 DEFG/0 RET")
        (:c21::expect "  (name first, then value) " (:c21::code "var a;") "NIL DEFG/0 RET")
        (:c21::expect "redefining is allowed      " (:c21::run "var a = 1; var a = 2; print a;") "2")
        (:c21::expect "and the table holds it     " (:c21::global "var a = 1; var b = 2;" "b") "2")
        (:c21::expect "an undeclared name is not  " (:c21::global "var a = 1;" "b") "(undefined)")

        ;; ASSIGNMENT IS AN EXPRESSION
        (:c21::expect "assignment updates         " (:c21::run "var a = 1; a = 2; print a;") "2")
        (:c21::expect "and evaluates to its value " (:c21::run "var a = 1; print a = 2;") "2")
        (:c21::expect "  leaving the variable set " (:c21::global "var a = 1; print a = 2;" "a") "2")
        (:c21::expect "chained assignment         " (:c21::run "var a; var b; a = b = 3; print a;") "3")
        (:c21::expect "assignment does NOT define " (:c21::run "x = 1;")
          "[line 1] Runtime error: Undefined variable 'x'.")
        (:c21::expect "reading an undefined name  " (:c21::run "print x;")
          "[line 1] Runtime error: Undefined variable 'x'.")
        (:c21::expect "  and it says which        " (:c21::run "var a = 1; print a + zzz;")
          "[line 1] Runtime error: Undefined variable 'zzz'.")

        ;; canAssign -- the subtlest bug in the chapter
        (:c21::expect "a * b = c is refused       " (:c21::run "var a; var b; var c; a * b = c;")
          "[line 1] Error: Invalid assignment target.")
        (:c21::expect "a + b = c too              " (:c21::run "var a; var b; var c; a + b = c;")
          "[line 1] Error: Invalid assignment target.")
        (:c21::expect "!a = b too                 " (:c21::run "var a; var b; !a = b;")
          "[line 1] Error: Invalid assignment target.")
        (:c21::expect "1 = 2 too                  " (:c21::run "1 = 2;")
          "[line 1] Error: Invalid assignment target.")
        (:c21::expect "but a = b is fine          " (:c21::run "var a; var b = 5; a = b; print a;") "5")
        (:c21::expect "and (a) = b is NOT         " (:c21::run "var a; var b; (a) = b;")
          "[line 1] Error: Invalid assignment target.")

        ;; MISSING SEMICOLONS
        (:c21::expect "print without a semicolon  " (:c21::run "print 1")
          "[line 1] Error: Expect ';' after value.")
        (:c21::expect "an expression without one  " (:c21::run "1 + 2")
          "[line 1] Error: Expect ';' after expression.")
        (:c21::expect "var without one            " (:c21::run "var a = 1")
          "[line 1] Error: Expect ';' after variable declaration.")
        (:c21::expect "var without a name         " (:c21::run "var = 1;")
          "[line 1] Error: Expect variable name.")

        ;; SYNCHRONIZE: one error per bad statement, and the good ones still compile
        (:c21::expect "two bad statements, 2 errs " (:c21::errs "print; print;") "2")
        (:c21::expect "one bad statement, 1 err   " (:c21::errs "print; print 1;") "1")
        (:c21::expect "a good program, 0 errors   " (:c21::errs "var a = 1; print a;") "0")
        (:c21::expect "three bad ones, 3 errors   " (:c21::errs "print; print; print;") "3")
        ;; without synchronize this would cascade: the parser would still be in panic mode at the
        ;; second statement and would swallow its error, or would not find a statement boundary
        (:c21::expect "recovery reaches the end   " (:c21::errs "var = 1; var b = 2; print;") "2")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what this chapter cost in wat ----")
        (:wat::kernel::println "The VM now has state beyond its stack -- a globals table and an")
        (:wat::kernel::println "output -- and both are values, so every instruction carries all three")
        (:wat::kernel::println "forward. Nystrom mutates vm.globals and calls printf. The exchange is")
        (:wat::kernel::println "not obviously bad: `print` becoming a conj onto a vector is why this")
        (:wat::kernel::println "file can check what a program PRINTED rather than what it left on the")
        (:wat::kernel::println "stack, which is the thing a language test actually wants.")
        (:wat::kernel::println "")
        (:wat::kernel::println "The cost landed elsewhere. A variant pattern must name EVERY field, so")
        (:wat::kernel::println "adding :globals and :out to Out broke a match in ch18 that wanted")
        (:wat::kernel::println "neither -- a chapter about tagged unions, edited by a chapter about")
        (:wat::kernel::println "global variables. FINDINGS records this as friction; chapters 22 to 29")
        (:wat::kernel::println "each extend VM state again, so it will keep being paid.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
