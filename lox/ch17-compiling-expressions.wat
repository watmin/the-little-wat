;; Crafting Interpreters chapter 17 (compiling expressions), in wat.
;;
;; The single-pass compiler: a Pratt parser that pulls tokens from chapter 16's scanner and emits
;; chapter 14's chunk as it goes, with no syntax tree in between. Chapter 15's VM then runs what
;; comes out -- so this chapter is where all three previous ones are checked against each other.
;;
;; The strongest check here is the first one. Chapter 14 built the chunk for `-((1.2+3.4)/5.6)`
;; BY HAND, instruction by instruction, because there was no compiler yet. This chapter builds
;; the same chunk from the source text and asserts the two are identical -- same opcodes, same
;; constant pool, same order -- and then runs it and gets chapter 15's answer.
;;
;; On the port itself: Nystrom's rule table is an array of function pointers indexed by
;; TokenType, and this port does not build one -- `getRule(op)->infix` exists because C cannot
;; say "dispatch on the token kind", and wat can. `probes/lox/rule-table.wat` was written so that
;; would be a choice rather than an excuse: the table IS expressible, with a `defstruct` row
;; carrying the two closures and the precedence, accessors and all. A `defrecord` row is refused
;; outright (F-114), and an Impure enum row works but costs a `match` per field read.
;;
;; Run: wat lox/ch17-compiling-expressions.wat

(:wat::load-file! "lib/compiler.wat")

(:wat::core::defn :c17::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c17::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))

(:wat::core::defn :c17::sig [src <- :wat::core::String] -> :wat::core::String
  (:lox::chunk-sig (:lox::C/chunk (:lox::compile src))))

;; just the opcodes, for the precedence checks
(:wat::core::defn :c17::code [src <- :wat::core::String] -> :wat::core::String
  (:wat::string::trim (:lox::code-sig (:lox::C/chunk (:lox::compile src)))))

(:wat::core::defn :c17::val [src <- :wat::core::String] -> :wat::core::String
  (:wat::f64::to-string (:lox::interpret src)))

(:wat::core::defn :c17::errs [src <- :wat::core::String] -> (:wat::core::Vector :- [:wat::core::String])
  (:lox::C/errs (:lox::compile src)))

(:wat::core::defn :c17::err-count [src <- :wat::core::String] -> :wat::core::String
  (:c17::int (:wat::core::length (:c17::errs src))))

(:wat::core::defn :c17::first-err [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [es (:c17::errs src)]
    (:wat::core::if (:wat::core::= (:wat::core::length es) 0) "(no error)" (:wat::core::nth es 0))))

;; chapter 14's chunk, built by hand exactly as that chapter builds it
(:wat::core::defn :c17::handmade [] -> :lox::Chunk
  (:wat::core::let
    [c0 (:lox::add-constant (:lox::new-chunk) 1.2)
     c1 (:lox::write c0 (:lox::Op.Constant {:slot (:lox::constant-slot c0)}) 123)
     c2 (:lox::add-constant c1 3.4)
     c3 (:lox::write c2 (:lox::Op.Constant {:slot (:lox::constant-slot c2)}) 123)
     c4 (:lox::write c3 (:lox::Op.Add {}) 123)
     c5 (:lox::add-constant c4 5.6)
     c6 (:lox::write c5 (:lox::Op.Constant {:slot (:lox::constant-slot c5)}) 123)
     c7 (:lox::write c6 (:lox::Op.Divide {}) 123)
     c8 (:lox::write c7 (:lox::Op.Negate {}) 123)]
    (:lox::write c8 (:lox::Op.Return {}) 124)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [book "-((1.2 + 3.4) / 5.6)"
     compiled (:lox::C/chunk (:lox::compile book))
     lines (:lox::disassemble compiled 0 (:wat::core::Vector :- [:wat::core::String]))]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "== compiled from: " book " =="))
      (:wat::core::foldl (:wat::core::fn [a <- :wat::core::nil s <- :wat::core::String] -> :wat::core::nil
                           (:wat::kernel::println s)) nil lines)
      (:wat::kernel::println "")
      (:wat::kernel::println "---- what the compiler must satisfy ----")
      (:wat::core::let
        [rs
         [;; THE CROSS-CHECK: chapter 14 built this chunk by hand; chapter 17 compiles it
          (:c17::expect "compiled == ch14's handmade "
            (:wat::core::if (:wat::core::= (:lox::chunk-sig compiled) (:lox::chunk-sig (:c17::handmade))) "yes" "no") "yes")
          (:c17::expect "and it is 7 instructions   " (:c17::int (:lox::count compiled)) "7")
          (:c17::expect "and 3 constants            " (:c17::int (:wat::core::length (:lox::Chunk/constants compiled))) "3")
          ;; and chapter 15's VM gives chapter 15's answer
          (:c17::expect "run on the ch15 VM         " (:c17::val book) "-0.8214285714285714")
          (:c17::expect "no errors                  " (:c17::err-count book) "0")

          ;; PRECEDENCE: the whole reason a Pratt parser exists
          (:c17::expect "1+2*3 multiplies first     " (:c17::code "1 + 2 * 3") "CONST/0 CONST/1 CONST/2 MUL ADD RET")
          (:c17::expect "  and answers              " (:c17::val "1 + 2 * 3") "7")
          (:c17::expect "(1+2)*3 adds first         " (:c17::code "(1 + 2) * 3") "CONST/0 CONST/1 ADD CONST/2 MUL RET")
          (:c17::expect "  and answers              " (:c17::val "(1 + 2) * 3") "9")
          (:c17::expect "2*3+4*5                    " (:c17::val "2 * 3 + 4 * 5") "26")
          (:c17::expect "2+3*4-5                    " (:c17::val "2 + 3 * 4 - 5") "9")

          ;; LEFT ASSOCIATIVITY: the +1 in `parse-prec (infix-prec k) + 1`
          (:c17::expect "1-2-3 is (1-2)-3           " (:c17::val "1 - 2 - 3") "-4")
          (:c17::expect "  not 1-(2-3)              " (:c17::code "1 - 2 - 3") "CONST/0 CONST/1 SUB CONST/2 SUB RET")
          (:c17::expect "8/4/2 is (8/4)/2           " (:c17::val "8 / 4 / 2") "1")
          (:c17::expect "2*3/4                      " (:c17::val "2 * 3 / 4") "1.5")

          ;; UNARY binds tighter than any binary operator, and is right-associative
          (:c17::expect "-1*2 negates first         " (:c17::code "-1 * 2") "CONST/0 NEG CONST/1 MUL RET")
          (:c17::expect "-(1*2) multiplies first    " (:c17::code "-(1 * 2)") "CONST/0 CONST/1 MUL NEG RET")
          (:c17::expect "  both answer              " (:c17::val "-1 * 2") "-2")
          (:c17::expect "  the same                 " (:c17::val "-(1 * 2)") "-2")
          (:c17::expect "- - 3 is 3                 " (:c17::val "- - 3") "3")
          (:c17::expect "1 - -2 is 3                " (:c17::val "1 - -2") "3")
          (:c17::expect "-2*-3 is 6                 " (:c17::val "-2 * -3") "6")

          ;; GROUPING emits nothing of its own -- Nystrom's point about grouping()
          (:c17::expect "((((1)))) is one constant  " (:c17::code "((((1))))") "CONST/0 RET")
          (:c17::expect "nesting does not nest code " (:c17::code "(2 + 3)") (:c17::code "2 + 3"))

          ;; ERRORS: a message, on the right line, and exactly one of them
          (:c17::expect "1 + is an error            " (:c17::first-err "1 +") "[line 1] Error: Expect expression.")
          (:c17::expect "(1 wants a paren           " (:c17::first-err "(1") "[line 1] Error: Expect ')' after expression.")
          (:c17::expect "1 2 is trailing input      " (:c17::first-err "1 2") "[line 1] Error: Expect end of expression.")
          (:c17::expect "a bare * is an error       " (:c17::first-err "*") "[line 1] Error: Expect expression.")
          (:c17::expect "an empty source too        " (:c17::first-err "") "[line 1] Error: Expect expression.")
          (:c17::expect "a scanner error reaches it " (:c17::first-err "1 @ 2") "[line 1] Error: Unexpected character: @")
          (:c17::expect "the line is reported       " (:c17::first-err "1 +\n\n") "[line 3] Error: Expect expression.")

          ;; PANIC MODE: one error, not a cascade -- the reason Nystrom has the flag at all
          (:c17::expect "+ + + reports once         " (:c17::err-count "+ + +") "1")
          (:c17::expect "( ( ( reports once         " (:c17::err-count "( ( (") "1")
          (:c17::expect "and a good source, never   " (:c17::err-count "1 + 2 * (3 - 4)") "0")]]
        (:wat::core::do
          (:wat::kernel::println "")
          (:wat::kernel::println "---- what this chapter proves about the three before it ----")
          (:wat::kernel::println "The chunk chapter 14 wrote out by hand, instruction by instruction,")
          (:wat::kernel::println "because there was no compiler yet, is the chunk this chapter compiles")
          (:wat::kernel::println "from the source text -- same opcodes, same pool, same order -- and the")
          (:wat::kernel::println "VM from chapter 15 gives the answer chapter 15 gave. Scanner, chunk,")
          (:wat::kernel::println "compiler and VM agree; nothing here is checked against a description of")
          (:wat::kernel::println "itself.")
          (:wat::kernel::println "")
          (:wat::kernel::println "Nothing in the chapter fought wat. The one place the port had to think")
          (:wat::kernel::println "was the rule table, and probes/lox/rule-table.wat settles it by building")
          (:wat::kernel::println "one: a `defstruct` row carries both closures and the precedence, with")
          (:wat::kernel::println "accessors, and reads like the C. A `defrecord` row is refused outright")
          (:wat::kernel::println "(F-114) and an Impure enum row costs a match per field. So not using")
          (:wat::kernel::println "the table is a choice -- an array of function pointers indexed by token")
          (:wat::kernel::println "type is C's way of writing a dispatch, and `match` is wat's, with the")
          (:wat::kernel::println "NULL prefix entry becoming an arm the checker can see.")
          (:wat::kernel::println "")
          (:wat::test::assert-eq
            (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                                 (:wat::core::+ a b)) 0 rs)
            0))))))
