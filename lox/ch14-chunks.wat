;; Crafting Interpreters chapter 14 (chunks of bytecode), in wat.
;;
;; The chapter builds one chunk by hand and disassembles it. There is nothing to run yet -- the
;; VM arrives in chapter 15 -- so what is checked here is the LAYOUT: the constant pool indexes
;; correctly, the line table tracks the code, and the disassembler agrees with Nystrom's format.
;;
;; Run: wat lox/ch14-chunks.wat

(:wat::load-file! "lib/chunk.wat")

(:wat::core::defn :c14::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " got
      (:wat::core::if (:wat::core::= got want) "   PASS"
        (:wat::string::concat "   FAIL (want " want ")")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [;; the book's own first chunk: -((1.2 + 3.4) / 5.6), then return
     c0 (:lox::add-constant (:lox::new-chunk) 1.2)
     c1 (:lox::write c0 (:lox::Op.Constant {:slot (:lox::constant-slot c0)}) 123)
     c2 (:lox::add-constant c1 3.4)
     c3 (:lox::write c2 (:lox::Op.Constant {:slot (:lox::constant-slot c2)}) 123)
     c4 (:lox::write c3 (:lox::Op.Add {}) 123)
     c5 (:lox::add-constant c4 5.6)
     c6 (:lox::write c5 (:lox::Op.Constant {:slot (:lox::constant-slot c5)}) 123)
     c7 (:lox::write c6 (:lox::Op.Divide {}) 123)
     c8 (:lox::write c7 (:lox::Op.Negate {}) 123)
     chunk (:lox::write c8 (:lox::Op.Return {}) 124)
     lines (:lox::disassemble chunk 0 (:wat::core::Vector :- [:wat::core::String]))
     int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:wat::core::do
      (:wat::kernel::println "== test chunk ==")
      (:wat::core::foldl (:wat::core::fn [a <- :wat::core::nil s <- :wat::core::String] -> :wat::core::nil
                           (:wat::kernel::println s)) nil lines)
      (:wat::kernel::println "---- what the layout must satisfy ----")
      ;; 7 instructions. Nystrom's identical chunk is 7 instructions and TEN BYTES, because his
      ;; OP_CONSTANT is two bytes; here an operand rides inside its instruction. See lib/chunk.wat.
      (:c14::expect "instructions written        " (int (:lox::count chunk)) "7")
      (:c14::expect "constants in the pool       " (int (:wat::core::length (:lox::Chunk/constants chunk))) "3")
      (:c14::expect "a line for every instruction" (int (:wat::core::length (:lox::Chunk/lines chunk))) "7")
      (:c14::expect "the third constant is 5.6   "
        (:wat::f64::to-string (:wat::core::nth (:lox::Chunk/constants chunk) 2)) "5.6")
      (:c14::expect "the last instruction        " (:lox::op-name (:wat::core::nth (:lox::Chunk/code chunk) 6)) "OP_RETURN")
      (:c14::expect "and it is on a new line     " (int (:wat::core::nth (:lox::Chunk/lines chunk) 6)) "124"))))
