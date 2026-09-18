;; Crafting Interpreters chapter 18 (types of values), in wat.
;;
;; Up to chapter 17 a Lox value was a C `double`. This chapter makes it a tagged union, which is
;; what turns a calculator into a dynamically typed language: `nil`, `true`, `false`, `!`, `==`,
;; the four comparisons -- and RUNTIME ERRORS, because `-true` is now a program the compiler
;; accepts and the VM must refuse.
;;
;; A tagged union is a `defenum`, so the data half ports in nine lines. What is worth checking is
;; everything AROUND it: the truthiness rule (Lox is Ruby's, not C's), equality across types,
;; the three operators Nystrom compiles as a desugaring rather than giving them opcodes -- and
;; the bug he says that desugaring has. He is right, and this file proves it rather than
;; repeating it.
;;
;; This chapter runs on `:loxv::`, a second namespace, with `:lox::` (chapters 14-17) left
;; untouched: C-098 and C-099 published measurements taken on that code, and re-aiming a
;; published experiment is not something this repository does. lib/v-value.wat says so at length.
;;
;; Run: wat lox/ch18-types-of-values.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c18::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c18::run [src <- :wat::core::String] -> :wat::core::String (:loxv::interpret src))

(:wat::core::defn :c18::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile src))))

(:wat::core::defn :c18::steps [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:loxv::run (:loxv::C/chunk (:loxv::compile src)))
    [:loxv::Out.Ok {:stack s :steps k} (:wat::i64::to-string k)]
    [:loxv::Out.Err {:msg m :line l :steps k} (:wat::i64::to-string k)]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [;; the chapter's own closing example
     book "!(5 - 4 > 3 * 2 == !nil)"]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "== " book " =="))
      (:wat::kernel::println (:wat::string::concat "  code   " (:c18::code book)))
      (:wat::kernel::println (:wat::string::concat "  value  " (:c18::run book)))
      (:wat::kernel::println "")
      (:wat::kernel::println "---- what the value representation must satisfy ----")
      (:wat::core::let
        [rs
         [(:c18::expect "the chapter's own example  " (:c18::run book) "true")

          ;; LITERALS get opcodes of their own, not constant-pool slots
          (:c18::expect "nil is an opcode           " (:c18::code "nil") "NIL RET")
          (:c18::expect "true is an opcode          " (:c18::code "true") "TRUE RET")
          (:c18::expect "false is an opcode         " (:c18::code "false") "FALSE RET")
          (:c18::expect "a number is a constant     " (:c18::code "1") "CONST/0 RET")
          (:c18::expect "nil prints as nil          " (:c18::run "nil") "nil")
          (:c18::expect "true prints as true        " (:c18::run "true") "true")

          ;; TRUTHINESS: Lox follows Ruby -- only nil and false are falsey
          (:c18::expect "!nil is true               " (:c18::run "!nil") "true")
          (:c18::expect "!false is true             " (:c18::run "!false") "true")
          (:c18::expect "!true is false             " (:c18::run "!true") "false")
          (:c18::expect "!0 is FALSE, not true      " (:c18::run "!0") "false")
          (:c18::expect "!!0 is true                " (:c18::run "!!0") "true")
          (:c18::expect "!1 is false                " (:c18::run "!1") "false")

          ;; EQUALITY compares tags first, so no value of one type equals any value of another
          (:c18::expect "1 == 1                     " (:c18::run "1 == 1") "true")
          (:c18::expect "1 == 2                     " (:c18::run "1 == 2") "false")
          (:c18::expect "nil == nil                 " (:c18::run "nil == nil") "true")
          (:c18::expect "true == true               " (:c18::run "true == true") "true")
          (:c18::expect "true == false              " (:c18::run "true == false") "false")
          (:c18::expect "nil == false is FALSE      " (:c18::run "nil == false") "false")
          (:c18::expect "1 == true is FALSE         " (:c18::run "1 == true") "false")
          (:c18::expect "0 == nil is FALSE          " (:c18::run "0 == nil") "false")
          (:c18::expect "1 != 2                     " (:c18::run "1 != 2") "true")

          ;; COMPARISON demands numbers; == does not
          (:c18::expect "1 < 2                      " (:c18::run "1 < 2") "true")
          (:c18::expect "2 <= 2                     " (:c18::run "2 <= 2") "true")
          (:c18::expect "3 >= 4                     " (:c18::run "3 >= 4") "false")
          (:c18::expect "1 < nil is a runtime error " (:c18::run "1 < nil")
            "[line 1] Runtime error: Operands must be numbers.")
          (:c18::expect "true - 1 too               " (:c18::run "true - 1")
            "[line 1] Runtime error: Operands must be numbers.")
          ;; `+` said the same thing when this chapter was written. Chapter 19 overloads it for
          ;; strings and lengthens the message, and there is ONE codebase, so this line records
          ;; what the code says now rather than what chapter 18 alone would have said. Nystrom
          ;; keeps a snapshot per chapter; a suite that runs every chapter against the current
          ;; code does not have that option, and pretending otherwise would mean freezing a
          ;; chapter's library the moment the next chapter touches it.
          (:c18::expect "and true + 1, after ch19   " (:c18::run "true + 1")
            "[line 1] Runtime error: Operands must be two numbers or two strings.")
          (:c18::expect "-true is the unary message " (:c18::run "-true")
            "[line 1] Runtime error: Operand must be a number.")
          (:c18::expect "-nil too                   " (:c18::run "-nil")
            "[line 1] Runtime error: Operand must be a number.")
          (:c18::expect "but nil == nil is fine     " (:c18::run "nil == nil") "true")
          (:c18::expect "the error carries its line " (:c18::run "1 +\n2 * true")
            "[line 2] Runtime error: Operands must be numbers.")

          ;; THE DESUGARING: !=, <= and >= have no opcodes. Nystrom says so, and says it is wrong
          ;; under IEEE 754. Both halves are checked here.
          (:c18::expect "!= is == then !            " (:c18::code "1 != 2") "CONST/0 CONST/1 EQ NOT RET")
          (:c18::expect "<= is > then !             " (:c18::code "1 <= 2") "CONST/0 CONST/1 GT NOT RET")
          (:c18::expect ">= is < then !             " (:c18::code "1 >= 2") "CONST/0 CONST/1 LT NOT RET")
          (:c18::expect "and < is one instruction   " (:c18::code "1 < 2") "CONST/0 CONST/1 LT RET")
          ;; NaN is not less than, equal to or greater than anything. So `NaN <= NaN` is FALSE by
          ;; IEEE 754 and TRUE under `!(NaN > NaN)`. wat's f64 is IEEE, so the bug ports intact.
          (:c18::expect "NaN > NaN is false (IEEE)  " (:c18::run "(0/0) > (0/0)") "false")
          (:c18::expect "NaN < NaN is false (IEEE)  " (:c18::run "(0/0) < (0/0)") "false")
          (:c18::expect "NaN == NaN is false (IEEE) " (:c18::run "(0/0) == (0/0)") "false")
          (:c18::expect "so NaN <= NaN should be    " "false" "false")
          (:c18::expect "and the desugaring says    " (:c18::run "(0/0) <= (0/0)") "true")
          (:c18::expect "NaN >= NaN, the same bug   " (:c18::run "(0/0) >= (0/0)") "true")
          (:c18::expect "NaN != NaN is true, right  " (:c18::run "(0/0) != (0/0)") "true")

          ;; PRECEDENCE, now that there is a full ladder to get wrong
          (:c18::expect "== binds looser than <     " (:c18::run "1 < 2 == true") "true")
          (:c18::expect "  and looser than +        " (:c18::run "1 + 1 == 2") "true")
          (:c18::expect "! binds tighter than ==    " (:c18::run "!true == false") "true")
          (:c18::expect "  which is not !(true==f)  " (:c18::run "!(true == false)") "true")
          (:c18::expect "-1 < 0                     " (:c18::run "-1 < 0") "true")

          ;; the VM stops AT the bad instruction, it does not run past it
          (:c18::expect "a failing program's steps  " (:c18::steps "-true") "2")
          (:c18::expect "  (CONST then NEGATE)      " (:c18::code "-true") "TRUE NEG RET")]]
        (:wat::core::do
          (:wat::kernel::println "")
          (:wat::kernel::println "---- what this chapter cost in wat ----")
          (:wat::kernel::println "The data half is nine lines: a tagged union is a defenum, and")
          (:wat::kernel::println "Nystrom's whole second half -- the IS_NUMBER / AS_NUMBER / NUMBER_VAL")
          (:wat::kernel::println "macros that make C's union safe to use -- has nothing to port, because")
          (:wat::kernel::println "a match arm that binds `n` has already done it and a missing arm is a")
          (:wat::kernel::println "compile error rather than a reinterpreted bit pattern.")
          (:wat::kernel::println "")
          (:wat::kernel::println "The half that cost something is the runtime error. Nystrom returns")
          (:wat::kernel::println "INTERPRET_RUNTIME_ERROR up through run(); wat has no early return and")
          (:wat::kernel::println "its only general catch spawns a thread (F-063), so every instruction")
          (:wat::kernel::println "answers Step.Next or Step.Fail and the loop matches on it. One match")
          (:wat::kernel::println "per instruction, in the hot loop C-098 measured.")
          (:wat::kernel::println "")
          (:wat::test::assert-eq
            (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                                 (:wat::core::+ a b)) 0 rs)
            0))))))
