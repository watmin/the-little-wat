;; lox/lib/chunk.wat — Crafting Interpreters chapter 14: a chunk of bytecode.
;;
;; Nystrom's chunk is three parallel arrays: the code itself (opcodes and their operand bytes,
;; flat), a constant pool the code indexes into, and a line number per byte for error reporting.
;; That layout is the whole point of Part II -- an instruction is a small integer and an operand
;; is the next integer along, not a node in a tree.
;;
;; **The one place wat forces a different shape is the code array itself, and it is F-104 again.**
;; A chunk is BUILT by appending, which `conj` does, so writing a chunk is fine; but chapter 23
;; (jumping back and forth) has to PATCH a jump operand already written -- Nystrom's
;; `patchJump()` assigns into `chunk->code[offset]` -- and wat has no positional update on either
;; vector type. The patch is a rebuild. That is recorded here rather than at chapter 23 because
;; the data structure is decided now, and this is the eighth workload in this repository to route
;; around F-104 (C-086 lists the other seven).
;;
;; Opcodes are an ENUM rather than raw integers, which is the first divergence from C worth
;; naming: Nystrom's `OP_CONSTANT` is a `uint8_t` and a bad byte is undefined behaviour, where a
;; bad opcode here cannot be constructed. The cost is that the code array cannot then be a plain
;; `Vector<i64>` holding both opcodes and operands -- so it holds INSTRUCTIONS, each carrying its
;; own operand, and the "flat array of bytes" becomes a flat array of small records. The
;; instruction COUNT is unchanged; the byte layout is not, and chapter 30's NaN boxing would have
;; nothing to say here.
;;
;; The arithmetic that follows from that is worth stating once, because every later chapter's
;; numbers depend on it. The book's first chunk is **7 instructions and 10 bytes** -- three
;; two-byte `OP_CONSTANT`s and four one-byte opcodes. Here it is **7 instructions and 7 elements**,
;; because an operand rides inside its instruction. So an "offset" in this port counts
;; instructions where Nystrom's counts bytes, and a jump operand (chapter 23) is a count of
;; instructions rather than of bytes. Every disassembly offset below is therefore one-per-line,
;; and Nystrom's would skip.

(:wat::core::defenum :lox::Op :wat::enum::Pure
  :Constant [slot <- :wat::core::i64]
  :Add      []
  :Subtract []
  :Multiply []
  :Divide   []
  :Negate   []
  :Return   [])

(:wat::core::typealias :lox::Code (:wat::core::Vector :- [:lox::Op]))
(:wat::core::typealias :lox::Consts (:wat::core::Vector :- [:wat::core::f64]))
(:wat::core::typealias :lox::Lines (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defrecord :lox::Chunk
  [code <- :lox::Code  constants <- :lox::Consts  lines <- :lox::Lines])

(:wat::core::defn :lox::new-chunk [] -> :lox::Chunk
  (:lox::Chunk :code (:wat::core::Vector :- [:lox::Op])
               :constants (:wat::core::Vector :- [:wat::core::f64])
               :lines (:wat::core::Vector :- [:wat::core::i64])))

;; writing is an append, which wat does well
(:wat::core::defn :lox::write [c <- :lox::Chunk op <- :lox::Op line <- :wat::core::i64] -> :lox::Chunk
  (:lox::Chunk :code (:wat::core::conj (:lox::Chunk/code c) op)
               :constants (:lox::Chunk/constants c)
               :lines (:wat::core::conj (:lox::Chunk/lines c) line)))

;; add a constant and answer its slot, as Nystrom's addConstant does
(:wat::core::defn :lox::add-constant [c <- :lox::Chunk v <- :wat::core::f64] -> :lox::Chunk
  (:lox::Chunk :code (:lox::Chunk/code c)
               :constants (:wat::core::conj (:lox::Chunk/constants c) v)
               :lines (:lox::Chunk/lines c)))

(:wat::core::defn :lox::constant-slot [c <- :lox::Chunk] -> :wat::core::i64
  (:wat::core::- (:wat::core::length (:lox::Chunk/constants c)) 1))

(:wat::core::defn :lox::count [c <- :lox::Chunk] -> :wat::core::i64
  (:wat::core::length (:lox::Chunk/code c)))

;; ---- the disassembler (chapter 14.5)
(:wat::core::defn :lox::op-name [op <- :lox::Op] -> :wat::core::String
  (:wat::core::match op
    [:lox::Op.Constant {:slot s} "OP_CONSTANT"]
    [:lox::Op.Add {} "OP_ADD"]
    [:lox::Op.Subtract {} "OP_SUBTRACT"]
    [:lox::Op.Multiply {} "OP_MULTIPLY"]
    [:lox::Op.Divide {} "OP_DIVIDE"]
    [:lox::Op.Negate {} "OP_NEGATE"]
    [:lox::Op.Return {} "OP_RETURN"]))

(:wat::core::defn :lox::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:lox::pad (:wat::string::concat s " ") n)))

;; right-align in 4 columns with SPACES, as Nystrom's %4d does for a line number
(:wat::core::defn :lox::rpad4 [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [s (:wat::i64::to-string n)]
    (:wat::core::if (:wat::core::>= (:wat::string::length s) 4) s
      (:wat::string::concat (:wat::string::subs "    " 0 (:wat::core::- 4 (:wat::string::length s))) s))))

;; and zero-pad the OFFSET, as %04d does
(:wat::core::defn :lox::pad4 [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [s (:wat::i64::to-string n)]
    (:wat::core::if (:wat::core::>= (:wat::string::length s) 4) s
      (:wat::string::concat (:wat::string::subs "0000" 0 (:wat::core::- 4 (:wat::string::length s))) s))))

(:wat::core::defn :lox::disassemble-at [c <- :lox::Chunk i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [op (:wat::core::nth (:lox::Chunk/code c) i)
                    line (:wat::core::nth (:lox::Chunk/lines c) i)
                    ;; Nystrom prints "|" when an instruction shares the previous one's line
                    same (:wat::core::and (:wat::core::> i 0)
                           (:wat::core::= line (:wat::core::nth (:lox::Chunk/lines c) (:wat::core::- i 1))))
                    lead (:wat::core::if same "   |" (:lox::rpad4 line))]
    (:wat::core::match op
      [:lox::Op.Constant {:slot s}
        (:wat::string::concat (:lox::pad4 i) " " lead " " (:lox::pad (:lox::op-name op) 17) " "
          (:wat::i64::to-string s) " '"
          (:wat::f64::to-string (:wat::core::nth (:lox::Chunk/constants c) s)) "'")]
      [:lox::Op.Add {} (:wat::string::concat (:lox::pad4 i) " " lead " " (:lox::op-name op))]
      [:lox::Op.Subtract {} (:wat::string::concat (:lox::pad4 i) " " lead " " (:lox::op-name op))]
      [:lox::Op.Multiply {} (:wat::string::concat (:lox::pad4 i) " " lead " " (:lox::op-name op))]
      [:lox::Op.Divide {} (:wat::string::concat (:lox::pad4 i) " " lead " " (:lox::op-name op))]
      [:lox::Op.Negate {} (:wat::string::concat (:lox::pad4 i) " " lead " " (:lox::op-name op))]
      [:lox::Op.Return {} (:wat::string::concat (:lox::pad4 i) " " lead " " (:lox::op-name op))])))

(:wat::core::defn :lox::disassemble [c <- :lox::Chunk i <- :wat::core::i64
                                     acc <- (:wat::core::Vector :- [:wat::core::String])]
  -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::if (:wat::core::>= i (:lox::count c)) acc
    (:lox::disassemble c (:wat::core::+ i 1) (:wat::core::conj acc (:lox::disassemble-at c i)))))
