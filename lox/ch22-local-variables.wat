;; Crafting Interpreters chapter 22 (local variables), in wat.
;;
;; Globals live in a hash table keyed by name; locals do not. The compiler works out, at compile
;; time, which stack slot each local will occupy, and `OP_GET_LOCAL` / `OP_SET_LOCAL` index the
;; running stack directly. Nystrom's line for the chapter is that there is NO CODE to create a
;; local variable at runtime: the initializer already left the value in the right slot.
;;
;; Everything the chapter is careful about is checked below: shadowing an outer scope (legal)
;; against redeclaring in the same one (not), reading a local inside its own initializer, the
;; pops a scope emits on the way out, and a local shadowing a global.
;;
;; **And this is the chapter where F-104 lands in the inner loop.** `OP_SET_LOCAL` is
;; `vm.stack[slot] = peek(0)` -- a positional write into the running stack. wat has no positional
;; update on either vector type, and no `pop` or `subvec` either, and `take`/`drop` answer a
;; Stream with no way back (F-088). So:
;;
;;   * a SET of a local rebuilds the stack
;;   * and so does every POP, which means every expression statement, every scope exit, and
;;     every binary operator
;;
;; which is to say a stack machine written in wat today has **no O(1) pop**. That is a claim with
;; a cost attached, so the bottom of this file measures it: the same instruction count, run with
;; more and more locals in scope.
;;
;; Run: wat lox/ch22-local-variables.wat

(:wat::load-file! "lib/v-compiler.wat")

(:wat::core::defn :c22::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c22::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))

(:wat::core::defn :c22::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c22::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
(:wat::core::defn :c22::run [src <- :wat::core::String] -> :wat::core::String (:loxv::run-program src))
(:wat::core::defn :c22::code [src <- :wat::core::String] -> :wat::core::String
  (:loxv::code-sig (:loxv::C/chunk (:loxv::compile-program src))))

(:wat::core::defn :c22::stack-left [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:loxv::run (:loxv::C/chunk (:loxv::compile-program src)))
    [:loxv::Out.Ok {:stack s :globals g :out o :steps k} (:c22::int (:wat::core::length s))]
    [:loxv::Out.Err {:msg m :line l :out o :steps k} "(runtime error)"]))

;; ---- the measurement: k locals in scope, the same number of instructions
(:wat::core::defn :c22::decls [k <- :wat::core::i64 i <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i k) acc
    (:c22::decls k (:wat::core::+ i 1)
      (:wat::string::concat acc "var l" (:wat::i64::to-string i) " = 0; "))))

(:wat::core::defn :c22::stmts [n <- :wat::core::i64 body <- :wat::core::String acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::= n 0) acc
    (:c22::stmts (:wat::core::- n 1) body (:wat::string::concat acc body))))

;; `l0 = l0;` is GET_LOCAL SET_LOCAL POP; `l0;` is GET_LOCAL POP. The difference between the two
;; programs is exactly N x OP_SET_LOCAL, at a stack depth of k.
(:wat::core::defn :c22::prog [k <- :wat::core::i64 n <- :wat::core::i64 body <- :wat::core::String] -> :wat::core::String
  (:wat::string::concat "{ " (:c22::decls k 0 "") (:c22::stmts n body "") " }"))

(:wat::core::defn :c22::time-run [c <- :loxv::Chunk] -> :wat::core::i64
  (:wat::core::let [a0 (:c22::now) _a (:loxv::run c) a1 (:c22::now)
                    b0 (:c22::now) _b (:loxv::run c) b1 (:c22::now)]
    (:c22::imin (:wat::core::- a1 a0) (:wat::core::- b1 b0))))

(:wat::core::defn :c22::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:c22::pad (:wat::string::concat s " ") n)))

(:wat::core::defn :c22::row [k <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [set-chunk (:loxv::C/chunk (:loxv::compile-program (:c22::prog k n "l0 = l0; ")))
     get-chunk (:loxv::C/chunk (:loxv::compile-program (:c22::prog k n "l0; ")))
     w1 (:loxv::run set-chunk) w2 (:loxv::run get-chunk)
     t-get (:c22::time-run get-chunk)
     t-set (:c22::time-run set-chunk)
     t-get2 (:c22::time-run get-chunk)
     t-set2 (:c22::time-run set-chunk)
     g (:c22::imin t-get t-get2)
     st (:c22::imin t-set t-set2)]
    (:wat::kernel::println
      (:wat::string::concat
        "locals in scope " (:c22::pad (:c22::int k) 5)
        "  GET+POP " (:c22::pad (:c22::int (:wat::core::/ g n)) 8) " ns/stmt"
        "  GET+SET+POP " (:c22::pad (:c22::int (:wat::core::/ st n)) 8) " ns/stmt"
        "  one SET_LOCAL " (:c22::pad (:c22::int (:wat::core::/ (:wat::core::- st g) n)) 8) " ns"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- what scopes and locals must satisfy ----")
    (:wat::core::let
      [rs
       [;; A LOCAL COSTS NO INSTRUCTION TO CREATE
        (:c22::expect "a local emits no DEFINE    " (:c22::code "{ var a = 1; print a; }")
          "CONST/0 GETL/0 PRINT POP RET")
        (:c22::expect "a global does              " (:c22::code "var a = 1; print a;")
          "CONST/1 DEFG/0 GETG/2 PRINT RET")
        (:c22::expect "and the local is read      " (:c22::run "{ var a = 1; print a; }") "1")
        (:c22::expect "leaving a scope pops it    " (:c22::code "{ var a = 1; }") "CONST/0 POP RET")
        (:c22::expect "two locals, two pops       " (:c22::code "{ var a = 1; var b = 2; }")
          "CONST/0 CONST/1 POP POP RET")
        (:c22::expect "the stack ends empty       " (:c22::stack-left "{ var a = 1; var b = 2; }") "0")
        (:c22::expect "  even after nesting       " (:c22::stack-left "{ var a = 1; { var b = 2; print b; } }") "0")

        ;; SCOPES AND SHADOWING
        (:c22::expect "a local shadows a global   " (:c22::run "var a = 1; { var a = 2; print a; } print a;") "2|1")
        (:c22::expect "and an outer local         " (:c22::run "{ var a = 1; { var a = 2; print a; } print a; }") "2|1")
        (:c22::expect "three deep                 " (:c22::run "{ var a=1; { var a=2; { var a=3; print a; } print a; } print a; }") "3|2|1")
        (:c22::expect "siblings do not collide    " (:c22::run "{ { var a = 1; print a; } { var a = 2; print a; } }") "1|2")
        (:c22::expect "an inner block sees outer  " (:c22::run "{ var a = 1; { print a; } }") "1")
        (:c22::expect "and can assign to it       " (:c22::run "{ var a = 1; { a = 2; } print a; }") "2")
        (:c22::expect "slot 0 then slot 1         " (:c22::code "{ var a=1; var b=2; print b; }")
          "CONST/0 CONST/1 GETL/1 PRINT POP POP RET")

        ;; THE TWO COMPILE ERRORS THIS CHAPTER ADDS
        (:c22::expect "redeclaring in one scope   " (:c22::run "{ var a = 1; var a = 2; }")
          "[line 1] Error: Already a variable with this name in this scope.")
        (:c22::expect "  but redeclaring a GLOBAL " (:c22::run "var a = 1; var a = 2; print a;") "2")
        (:c22::expect "reading a local in its own " (:c22::run "{ var a = a; }")
          "[line 1] Error: Can't read local variable in its own initializer.")
        (:c22::expect "  even from an outer a     " (:c22::run "var a = 1; { var a = a; }")
          "[line 1] Error: Can't read local variable in its own initializer.")
        (:c22::expect "an unclosed block          " (:c22::run "{ var a = 1;")
          "[line 1] Error: Expect '}' after block.")

        ;; ASSIGNMENT TO A LOCAL IS STILL AN EXPRESSION
        (:c22::expect "a local assignment         " (:c22::run "{ var a = 1; a = 5; print a; }") "5")
        (:c22::expect "and evaluates to its value " (:c22::run "{ var a = 1; print a = 5; }") "5")
        (:c22::expect "SET_LOCAL, not SET_GLOBAL  " (:c22::code "{ var a = 1; a = 2; }")
          "CONST/0 CONST/1 SETL/0 POP POP RET")
        (:c22::expect "canAssign still applies    " (:c22::run "{ var a; var b; a * b = 1; }")
          "[line 1] Error: Invalid assignment target.")

        ;; A BLOCK IS A STATEMENT, so it nests anywhere a statement does
        (:c22::expect "an empty block             " (:c22::code "{}") "RET")
        (:c22::expect "nested empty blocks        " (:c22::code "{{{}}}") "RET")
        (:c22::expect "a block after a print      " (:c22::run "print 1; { print 2; } print 3;") "1|2|3")]]
      (:wat::core::do
        (:wat::kernel::println "")
        (:wat::kernel::println "---- what a pop costs, measured (min of 2, arms interleaved) ----")
        (:c22::row 1 300)
        (:c22::row 10 300)
        (:c22::row 40 300)
        (:wat::kernel::println "")
        (:wat::kernel::println "Read the last column down. OP_SET_LOCAL is one line in C --")
        (:wat::kernel::println "`vm.stack[slot] = peek(0)` -- and it is constant time there. Here it")
        (:wat::kernel::println "rebuilds the stack, because neither wat vector type has a positional")
        (:wat::kernel::println "update (F-104). The first two columns rise for the same reason: POP has")
        (:wat::kernel::println "no O(1) spelling either. There is no `pop` and no `subvec`; `take` and")
        (:wat::kernel::println "`drop` answer a Stream with no way back (F-088); so a pop is a rebuild.")
        (:wat::kernel::println "")
        (:wat::kernel::println "A stack machine written in wat today therefore has no constant-time")
        (:wat::kernel::println "pop, and a pop is what almost every instruction ends with.")
        (:wat::kernel::println "")
        (:wat::kernel::println "probes/lox/stack-ops.wat takes that apart, and the answer is worse and")
        (:wat::kernel::println "more actionable than it looks from here. `conj` on a Vector CLONES")
        (:wat::kernel::println "(F-023), so the rebuild is QUADRATIC: one pop at depth 4000 costs 121")
        (:wat::kernel::println "milliseconds. `conj` on a PersistentVector is flat, so the same rebuild")
        (:wat::kernel::println "there is linear -- 34 ms, which is exactly 4000 interpreted iterations")
        (:wat::kernel::println "and nothing else. A `pop` verb would make it about 8 microseconds.")
        (:wat::kernel::println "")
        (:wat::kernel::println "So F-104's queued Index-assoc fixes OP_SET_LOCAL and does nothing for")
        (:wat::kernel::println "OP_POP; F-116 is the second ask. And the type called Vector is the wrong")
        (:wat::kernel::println "one to build a stack from, while the namespace called :wat::vector:: is")
        (:wat::kernel::println "the one that refuses it (F-108).")
        (:wat::kernel::println "")
        (:wat::test::assert-eq
          (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                               (:wat::core::+ a b)) 0 rs)
          0)))))
