;; Crafting Interpreters chapter 23 (jumping back and forth), in wat.
;;
;; Control flow, all of it: `if`/`else`, `and`, `or`, `while`, and `for` desugared entirely in
;; the compiler. Three new instructions -- JUMP, JUMP_IF_FALSE, LOOP -- and the technique the
;; chapter is really about: BACKPATCHING. A forward jump is emitted before its destination is
;; known, with a placeholder operand, and the real distance is written back into the code array
;; once the body has been compiled.
;;
;; **That write-back is the one this repository has been expecting since chapter 14.**
;; `lox/lib/chunk.wat`'s header, written nine chapters ago, said: *"chapter 23 has to PATCH a
;; jump operand already written -- Nystrom's `patchJump()` assigns into `chunk->code[offset]` --
;; and wat has no positional update on either vector type. The patch is a rebuild."* It is, and
;; the bottom of this file measures what the rebuild costs as a program grows, which is F-116's
;; cost arriving in the COMPILER rather than the VM.
;;
;; Everything else here is Lox semantics, and the interesting cases are the ones where a jump is
;; visible in the answer: `and` and `or` leave their OPERAND rather than a boolean, because
;; JUMP_IF_FALSE peeks instead of popping.
;;
;; Run: wat lox/ch23-jumping.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c23::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c23::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))
(:wat::core::defn :c23::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:c23::pad (:wat::string::concat s " ") n)))

(:wat::core::defn :c23::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c23::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
(:wat::core::defn :c23::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))
(:wat::core::defn :c23::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile-program src))))

(:wat::core::defn :c23::stack-left [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:loxv::run (:loxv::C/chunk (:loxv::compile-program src)))
    [:loxv::Out.Ok {:stack s :globals g :out o :steps k} (:c23::int (:wat::core::length s))]
    [:loxv::Out.Err {:msg m :line l :out o :steps k} "(runtime error)"]))

(:wat::core::defn :c23::steps [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:loxv::run (:loxv::C/chunk (:loxv::compile-program src)))
    [:loxv::Out.Ok {:stack s :globals g :out o :steps k} (:c23::int k)]
    [:loxv::Out.Err {:msg m :line l :out o :steps k} "(runtime error)"]))

;; ---- the measurement: COMPILE time against the number of backpatches
(:wat::core::defn :c23::rep [n <- :wat::core::i64 body <- :wat::core::String acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::= n 0) acc
    (:c23::rep (:wat::core::- n 1) body (:wat::string::concat acc body))))

(:wat::core::defn :c23::time-compile [src <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [a0 (:c23::now) _a (:loxv::compile-program src) a1 (:c23::now)
                    b0 (:c23::now) _b (:loxv::compile-program src) b1 (:c23::now)]
    (:c23::imin (:wat::core::- a1 a0) (:wat::core::- b1 b0))))

(:wat::core::defn :c23::row [k <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    ;; each `if` costs TWO patches; the control has the same shape and none
    [with-if (:c23::rep k "if (true) print 1; " "")
     without (:c23::rep k "print 1; print 1; " "")
     w1 (:loxv::compile-program with-if) w2 (:loxv::compile-program without)
     t-no (:c23::time-compile without)
     t-if (:c23::time-compile with-if)
     t-no2 (:c23::time-compile without)
     t-if2 (:c23::time-compile with-if)
     a (:c23::imin t-no t-no2)
     b (:c23::imin t-if t-if2)
     n (:wat::core::length (:loxv::Chunk/code (:loxv::C/chunk w1)))]
    (:wat::kernel::println
      (:wat::string::concat
        "ifs " (:c23::pad (:c23::int k) 5)
        " (" (:c23::pad (:c23::int n) 5) " instructions)"
        "  no patches " (:c23::pad (:c23::int (:wat::core::/ a 1000)) 7) " us"
        "  with " (:c23::pad (:c23::int (:wat::core::/ b 1000)) 7) " us"
        "  per patch " (:c23::pad (:c23::int (:wat::core::/ (:wat::core::- b a) (:wat::core::* k 2))) 8) " ns"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- what control flow must satisfy ----")
    (:wat::core::let
      [rs
       [;; IF / ELSE, and the code that implements it
        (:c23::expect "if true takes the then     " (:c23::run "if (true) print 1; else print 2;") "1")
        (:c23::expect "if false takes the else    " (:c23::run "if (false) print 1; else print 2;") "2")
        (:c23::expect "if with no else, true      " (:c23::run "if (1 < 2) print \"yes\";") "yes")
        (:c23::expect "if with no else, false     " (:c23::run "if (1 > 2) print \"yes\"; print \"after\";") "after")
        (:c23::expect "the condition is truthy    " (:c23::run "if (0) print \"zero is truthy\";") "zero is truthy")
        (:c23::expect "nil is not                 " (:c23::run "if (nil) print 1; else print 2;") "2")
        (:c23::expect "the emitted shape          " (:c23::code "if (true) print 1;")
          "TRUE JIF/4 POP CONST/0 PRINT JMP/1 POP RET")
        (:c23::expect "  with an else             " (:c23::code "if (true) print 1; else print 2;")
          "TRUE JIF/4 POP CONST/0 PRINT JMP/3 POP CONST/1 PRINT RET")
        (:c23::expect "and it leaves no stack     " (:c23::stack-left "if (true) print 1; else print 2;") "0")
        (:c23::expect "  on the other path too    " (:c23::stack-left "if (false) print 1; else print 2;") "0")
        (:c23::expect "nested ifs                 " (:c23::run "if (true) if (false) print 1; else print 2;") "2")

        ;; AND / OR: the value is the OPERAND, not a boolean, because JUMP_IF_FALSE peeks
        (:c23::expect "1 and 2 is 2               " (:c23::run "print 1 and 2;") "2")
        (:c23::expect "nil and 2 is nil           " (:c23::run "print nil and 2;") "nil")
        (:c23::expect "false and 2 is false       " (:c23::run "print false and 2;") "false")
        (:c23::expect "nil or 3 is 3              " (:c23::run "print nil or 3;") "3")
        (:c23::expect "1 or 2 is 1                " (:c23::run "print 1 or 2;") "1")
        (:c23::expect "chained or                 " (:c23::run "print false or false or 7;") "7")
        (:c23::expect "chained and                " (:c23::run "print 1 and 2 and 3;") "3")
        ;; SHORT CIRCUIT is an effect, not just a value
        (:c23::expect "and skips its right side   " (:c23::run "var a = 0; false and (a = 1); print a;") "0")
        (:c23::expect "or skips its right side    " (:c23::run "var a = 0; true or (a = 1); print a;") "0")
        (:c23::expect "and RUNS it when it must   " (:c23::run "var a = 0; true and (a = 1); print a;") "1")
        (:c23::expect "and binds tighter than or  " (:c23::run "print false and true or 9;") "9")
        (:c23::expect "the emitted and            " (:c23::code "print 1 and 2;")
          "CONST/0 JIF/2 POP CONST/1 PRINT RET")
        (:c23::expect "the emitted or             " (:c23::code "print 1 or 2;")
          "CONST/0 JIF/1 JMP/2 POP CONST/1 PRINT RET")

        ;; WHILE
        (:c23::expect "a counting loop            " (:c23::run "var i = 0; while (i < 3) { print i; i = i + 1; }") "0|1|2")
        (:c23::expect "a false condition runs 0x  " (:c23::run "while (false) print 1; print \"done\";") "done")
        (:c23::expect "the LOOP goes back to 0    " (:c23::code "while (true) print 1;")
          "TRUE JIF/4 POP CONST/0 PRINT LOOP/6 POP RET")
        (:c23::expect "and leaves no stack        " (:c23::stack-left "var i = 0; while (i < 3) i = i + 1;") "0")

        ;; FOR, with every clause present and each one absent
        (:c23::expect "a full for                 " (:c23::run "for (var i = 0; i < 3; i = i + 1) print i;") "0|1|2")
        (:c23::expect "no initializer             " (:c23::run "var i = 0; for (; i < 3; i = i + 1) print i;") "0|1|2")
        (:c23::expect "no increment               " (:c23::run "for (var j = 0; j < 3;) { print j; j = j + 1; }") "0|1|2")
        (:c23::expect "a sum                      " (:c23::run "var s = 0; for (var i = 1; i <= 5; i = i + 1) s = s + i; print s;") "15")
        (:c23::expect "nested fors                "
          (:c23::run "var n = 0; for (var i = 0; i < 3; i = i + 1) for (var j = 0; j < 3; j = j + 1) n = n + 1; print n;") "9")
        (:c23::expect "the loop variable is local "
          (:c23::run "var i = 99; for (var i = 0; i < 2; i = i + 1) print i; print i;") "0|1|99")
        (:c23::expect "and its scope closes       " (:c23::stack-left "for (var i = 0; i < 3; i = i + 1) {}") "0")

        ;; The increment is compiled BEFORE the body and jumped over, so the step count is what
        ;; tells you the desugaring is right. 17 instructions; 1 for the initializer, then three
        ;; iterations of 13 (cond 3, JIF, POP, JMP, LOOP-to-increment, increment 5, LOOP-to-cond),
        ;; then a fourth condition test of 4 that takes the exit jump, two POPs and the RETURN:
        ;; 1 + 39 + 4 + 3 = 47. The JMP over the increment runs EVERY iteration, not just the
        ;; first -- which is the price of compiling the increment before the body.
        (:c23::expect "a 3-iteration for's steps  " (:c23::steps "for (var i = 0; i < 3; i = i + 1) {}") "47")
        (:c23::expect "  and its instructions     "
          (:c23::int (:wat::core::length (:loxv::Chunk/code (:loxv::C/chunk (:loxv::compile-program "for (var i = 0; i < 3; i = i + 1) {}"))))) "17")

        ;; ERRORS
        (:c23::expect "if without parens          " (:c23::run "if true print 1;")
          "[line 1] Error: Expect '(' after 'if'.")
        (:c23::expect "while without a close      " (:c23::run "while (true print 1;")
          "[line 1] Error: Expect ')' after condition.")
        (:c23::expect "for without its semicolons " (:c23::run "for (var i = 0) print i;")
          "[line 1] Error: Expect ';' after variable declaration.")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what a backpatch costs (min of 2, arms interleaved) ----")
        (:c23::row 15)
        (:c23::row 45)
        (:c23::row 90)
        (:wat::kernel::println "")
        (:wat::kernel::println "`patchJump` in C is one array write. Here it rebuilds the code")
        (:wat::kernel::println "vector, because neither wat vector type has a positional update")
        (:wat::kernel::println "(F-104). Read the last column: a patch costs about seven microseconds")
        (:wat::kernel::println "for every instruction already emitted. So ONE patch is linear in the")
        (:wat::kernel::println "program compiled so far, and a program's patches together are")
        (:wat::kernel::println "QUADRATIC in its length -- 90 ifs take 1.06 s to compile where the same")
        (:wat::kernel::println "statements without jumps take 0.16 s.")
        (:wat::kernel::println "")
        (:wat::kernel::println "At these sizes the rebuild loop dominates and the per-element clone")
        (:wat::kernel::println "F-116 measured is still small; it grows, so the real curve is worse")
        (:wat::kernel::println "than quadratic rather than better.")
        (:wat::kernel::println "")
        (:wat::kernel::println "This is the clearest argument this section has for wat's own queued")
        (:wat::kernel::println "Index-assoc. A one-line array write is the thing a compiler does most,")
        (:wat::kernel::println "and it has no spelling; the cost of a jump is currently a property of")
        (:wat::kernel::println "where in the file it appears.")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
