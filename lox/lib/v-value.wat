;; lox/lib/v-value.wat — Crafting Interpreters chapter 18: types of values.
;;
;; Up to chapter 17 a Lox value was a C `double` and the VM's stack was an array of them. Chapter
;; 18 makes it a tagged union -- a type tag plus a union of `bool`, nothing, and `double` -- so
;; the language can have `nil`, `true`, `false`, `!`, `==` and the comparisons, and so the VM can
;; have RUNTIME ERRORS ("Operands must be numbers.") rather than reinterpreting bits.
;;
;; **Why this is a new namespace rather than an edit.** In C this chapter edits `value.h` in
;; place. Here `:lox::` -- chapters 14 to 17 -- is left exactly as it was, and the value-era
;; machine is `:loxv::`. The reason is that C-098 and C-099 published MEASUREMENTS taken on that
;; code (three VM loop shapes, two scanner shapes), and this repository does not re-aim a
;; published experiment: `lox/ch15-virtual-machine.wat` must keep running the loop its numbers
;; came from. The scanner is shared unchanged -- tokens do not care what a value is.
;;
;; A tagged union is a `defenum`, which is the whole port. Nystrom spends the chapter's second
;; half on the macros (`IS_NUMBER`, `AS_NUMBER`, `NUMBER_VAL`) that make C's union safe to use;
;; there is nothing to port there, because a `match` arm that binds `n` has already done it, and
;; a missing arm is a compile error rather than a reinterpreted bit pattern. Chapter 30's NaN
;; boxing -- the same union packed into the unused bits of a quiet NaN -- has nothing to say here
;; either, which is why NEXT.md lists it as "no portable content".

(:wat::core::defenum :loxv::Val :wat::enum::Pure
  :Nil  []
  :Bool [b <- :wat::core::bool]
  :Num  [n <- :wat::core::f64]
  ;; chapter 19. In C this is a POINTER to a heap-allocated `ObjString` with its own type tag,
  ;; its length, its characters and a `next` link threading every object the VM has ever made so
  ;; that `freeObjects()` can walk them. None of that is representable here and none of it needs
  ;; to be: wat owns the heap, so `Obj`, `ObjString`, `allocateObject`, the `vm.objects` list and
  ;; `freeObjects` are the chapter's C-memory half, and what is left is that a value can be a
  ;; string. See lox/ch19-strings.wat for what that costs and what it buys.
  :Str  [s <- :wat::core::String]
  ;; chapter 24. Nystrom's ObjFunction: a chunk, an arity and a name. The enum is recursive
  ;; through a `defrecord` here -- a `Val` holds a `Chunk`, and a `Chunk`'s constant pool holds
  ;; `Val`s -- which wat accepts (probes/lox/rule-table.wat's sibling question, checked before it
  ;; was relied on).
  :Fn   [chunk <- :loxv::Chunk  name <- :wat::core::String  arity <- :wat::core::i64]
  ;; a native is named rather than carried: a closure cannot live in a `:wat::enum::Pure` (the
  ;; containment rule, F-114), and Nystrom's C function pointer has no wat spelling that a value
  ;; can hold. So the VM dispatches on the name, which is what a table of function pointers is.
  :Native [name <- :wat::core::String  arity <- :wat::core::i64])

(:wat::core::typealias :loxv::Stack (:wat::core::Vector :- [:loxv::Val]))
(:wat::core::typealias :loxv::Consts (:wat::core::Vector :- [:loxv::Val]))

;; Nystrom's printValue
(:wat::core::defn :loxv::show [v <- :loxv::Val] -> :wat::core::String
  (:wat::core::match v
    [:loxv::Val.Nil {} "nil"]
    [:loxv::Val.Bool {:b b} (:wat::core::if b "true" "false")]
    ;; printValue prints a string's characters, not its quotes
    [:loxv::Val.Str {:s x} x]
    [:loxv::Val.Fn {:chunk c :name nm :arity a}
      (:wat::core::if (:wat::core::= nm "") "<script>" (:wat::string::concat "<fn " nm ">"))]
    [:loxv::Val.Native {:name nm :arity a} "<native fn>"]
    [:loxv::Val.Num {:n n} (:wat::f64::to-string n)]))

(:wat::core::defn :loxv::type-name [v <- :loxv::Val] -> :wat::core::String
  (:wat::core::match v
    [:loxv::Val.Nil {} "nil"] [:loxv::Val.Bool {:b b} "bool"] [:loxv::Val.Num {:n n} "number"]
    [:loxv::Val.Str {:s x} "string"]
    [:loxv::Val.Fn {:chunk c :name nm :arity a} "function"]
    [:loxv::Val.Native {:name nm :arity a} "function"]))

(:wat::core::defn :loxv::num? [v <- :loxv::Val] -> :wat::core::bool
  (:wat::core::match v
    [:loxv::Val.Num {:n n} true] [:loxv::Val.Nil {} false] [:loxv::Val.Bool {:b b} false]
    [:loxv::Val.Str {:s x} false]
    [:loxv::Val.Fn {:chunk c :name nm :arity a} false]
    [:loxv::Val.Native {:name nm :arity a} false]))

(:wat::core::defn :loxv::str? [v <- :loxv::Val] -> :wat::core::bool
  (:wat::core::match v
    [:loxv::Val.Str {:s x} true] [:loxv::Val.Num {:n n} false]
    [:loxv::Val.Nil {} false] [:loxv::Val.Bool {:b b} false]
    [:loxv::Val.Fn {:chunk c :name nm :arity a} false]
    [:loxv::Val.Native {:name nm :arity a} false]))

(:wat::core::defn :loxv::as-str [v <- :loxv::Val] -> :wat::core::String
  (:wat::core::match v
    [:loxv::Val.Str {:s x} x] [:loxv::Val.Num {:n n} ""]
    [:loxv::Val.Nil {} ""] [:loxv::Val.Bool {:b b} ""]
    [:loxv::Val.Fn {:chunk c :name nm :arity a} ""]
    [:loxv::Val.Native {:name nm :arity a} ""]))

;; AS_NUMBER, with the guard the C macro does not have. Callers check `num?` first; this answers
;; 0.0 for the case the checker cannot see is impossible.
(:wat::core::defn :loxv::as-num [v <- :loxv::Val] -> :wat::core::f64
  (:wat::core::match v
    [:loxv::Val.Num {:n n} n] [:loxv::Val.Nil {} 0.0] [:loxv::Val.Bool {:b b} 0.0]
    [:loxv::Val.Str {:s x} 0.0]
    [:loxv::Val.Fn {:chunk c :name nm :arity a} 0.0]
    [:loxv::Val.Native {:name nm :arity a} 0.0]))

;; Lox's truthiness: nil and false are falsey, EVERYTHING else is truthy -- including 0 and "",
;; which is Ruby's rule, not C's or Python's.
(:wat::core::defn :loxv::falsey? [v <- :loxv::Val] -> :wat::core::bool
  (:wat::core::match v
    [:loxv::Val.Nil {} true]
    [:loxv::Val.Bool {:b b} (:wat::core::not b)]
    [:loxv::Val.Num {:n n} false]
    ;; a string is truthy, INCLUDING the empty one -- Ruby's rule again, not Python's
    [:loxv::Val.Str {:s x} false]
    [:loxv::Val.Fn {:chunk c :name nm :arity a} false]
    [:loxv::Val.Native {:name nm :arity a} false]))

;; valuesEqual. Nystrom compares the tags first and returns false when they differ -- so `1` and
;; `true` are not equal, which is the choice Lox makes and JavaScript does not.
;;
;; **This was written by hand first, and it did not need to be.** The hand-written version
;; compared type names and then unwrapped each variant, on the belief that F-019 forbade
;; `(= a b)` on two values of one enum. F-019 says something narrower: a value that still carries
;; its VARIANT type cannot be compared with a value of another variant. Two values typed as the
;; ENUM compare fine, and `probes/lox/value-equality.wat` checks the three cases that matter --
;; equal numbers, different variants, and NaN. The last one is the interesting one: enum equality
;; does NOT compare the f64 payload bitwise, it compares it as an f64, so `NaN == NaN` is false
;; through the enum exactly as it is through the number. `=` on `:loxv::Val` is `valuesEqual`.
(:wat::core::defn :loxv::equal? [a <- :loxv::Val b <- :loxv::Val] -> :wat::core::bool
  (:wat::core::= a b))

;; ---- the chunk, with chapter 18's full opcode set
(:wat::core::defenum :loxv::Op :wat::enum::Pure
  :Constant [slot <- :wat::core::i64]
  :Nil [] :True [] :False []
  :Equal [] :Greater [] :Less []
  :Add [] :Subtract [] :Multiply [] :Divide []
  :Not [] :Negate []
  ;; chapter 21: statements, and globals. `slot` indexes the constant pool, where the variable's
  ;; NAME is stored as a string -- Nystrom's identifierConstant().
  :Print [] :Pop []
  :DefineGlobal [slot <- :wat::core::i64]
  :GetGlobal [slot <- :wat::core::i64]
  :SetGlobal [slot <- :wat::core::i64]
  ;; chapter 22: a local lives on the STACK, at a slot the compiler worked out, so these two
  ;; instructions index the running stack rather than a table of names.
  :GetLocal [slot <- :wat::core::i64]
  :SetLocal [slot <- :wat::core::i64]
  ;; chapter 23. `offset` counts INSTRUCTIONS, not bytes -- see the note at the top of
  ;; lox/lib/chunk.wat: an opcode here carries its operand, so there are no operand bytes to
  ;; count. Nystrom's two-byte big-endian operand and his 65535 limit have no analogue.
  :Jump [offset <- :wat::core::i64]
  :JumpIfFalse [offset <- :wat::core::i64]
  :Loop [offset <- :wat::core::i64]
  ;; chapter 24
  :Call [argc <- :wat::core::i64]
  :Return [])

(:wat::core::typealias :loxv::Code (:wat::core::Vector :- [:loxv::Op]))
(:wat::core::typealias :loxv::Lines (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defrecord :loxv::Chunk
  [code <- :loxv::Code  constants <- :loxv::Consts  lines <- :loxv::Lines])

(:wat::core::defn :loxv::new-chunk [] -> :loxv::Chunk
  (:loxv::Chunk :code (:wat::core::Vector :- [:loxv::Op])
                :constants (:wat::core::Vector :- [:loxv::Val])
                :lines (:wat::core::Vector :- [:wat::core::i64])))

;; F-113: one field changes, so one field is written
(:wat::core::defn :loxv::write [c <- :loxv::Chunk op <- :loxv::Op line <- :wat::core::i64] -> :loxv::Chunk
  (:wat::core::assoc (:wat::core::assoc c :code (:wat::core::conj (:loxv::Chunk/code c) op))
    :lines (:wat::core::conj (:loxv::Chunk/lines c) line)))

(:wat::core::defn :loxv::add-constant [c <- :loxv::Chunk v <- :loxv::Val] -> :loxv::Chunk
  (:wat::core::assoc c :constants (:wat::core::conj (:loxv::Chunk/constants c) v)))

(:wat::core::defn :loxv::constant-slot [c <- :loxv::Chunk] -> :wat::core::i64
  (:wat::core::- (:wat::core::length (:loxv::Chunk/constants c)) 1))

(:wat::core::defn :loxv::count [c <- :loxv::Chunk] -> :wat::core::i64
  (:wat::core::length (:loxv::Chunk/code c)))

(:wat::core::defn :loxv::op-name [op <- :loxv::Op] -> :wat::core::String
  (:wat::core::match op
    [:loxv::Op.Constant {:slot s} "OP_CONSTANT"]
    [:loxv::Op.Nil {} "OP_NIL"] [:loxv::Op.True {} "OP_TRUE"] [:loxv::Op.False {} "OP_FALSE"]
    [:loxv::Op.Equal {} "OP_EQUAL"] [:loxv::Op.Greater {} "OP_GREATER"] [:loxv::Op.Less {} "OP_LESS"]
    [:loxv::Op.Add {} "OP_ADD"] [:loxv::Op.Subtract {} "OP_SUBTRACT"]
    [:loxv::Op.Multiply {} "OP_MULTIPLY"] [:loxv::Op.Divide {} "OP_DIVIDE"]
    [:loxv::Op.Not {} "OP_NOT"] [:loxv::Op.Negate {} "OP_NEGATE"]
    [:loxv::Op.Print {} "OP_PRINT"] [:loxv::Op.Pop {} "OP_POP"]
    [:loxv::Op.DefineGlobal {:slot s} "OP_DEFINE_GLOBAL"]
    [:loxv::Op.GetGlobal {:slot s} "OP_GET_GLOBAL"]
    [:loxv::Op.SetGlobal {:slot s} "OP_SET_GLOBAL"]
    [:loxv::Op.GetLocal {:slot s} "OP_GET_LOCAL"] [:loxv::Op.SetLocal {:slot s} "OP_SET_LOCAL"]
    [:loxv::Op.Jump {:offset o} "OP_JUMP"] [:loxv::Op.JumpIfFalse {:offset o} "OP_JUMP_IF_FALSE"]
    [:loxv::Op.Loop {:offset o} "OP_LOOP"] [:loxv::Op.Call {:argc a} "OP_CALL"]
    [:loxv::Op.Return {} "OP_RETURN"]))

(:wat::core::defn :loxv::op-key [op <- :loxv::Op] -> :wat::core::String
  (:wat::core::match op
    [:loxv::Op.Constant {:slot s} (:wat::string::concat "CONST/" (:wat::i64::to-string s))]
    [:loxv::Op.Nil {} "NIL"] [:loxv::Op.True {} "TRUE"] [:loxv::Op.False {} "FALSE"]
    [:loxv::Op.Equal {} "EQ"] [:loxv::Op.Greater {} "GT"] [:loxv::Op.Less {} "LT"]
    [:loxv::Op.Add {} "ADD"] [:loxv::Op.Subtract {} "SUB"]
    [:loxv::Op.Multiply {} "MUL"] [:loxv::Op.Divide {} "DIV"]
    [:loxv::Op.Not {} "NOT"] [:loxv::Op.Negate {} "NEG"]
    [:loxv::Op.Print {} "PRINT"] [:loxv::Op.Pop {} "POP"]
    [:loxv::Op.DefineGlobal {:slot s} (:wat::string::concat "DEFG/" (:wat::i64::to-string s))]
    [:loxv::Op.GetGlobal {:slot s} (:wat::string::concat "GETG/" (:wat::i64::to-string s))]
    [:loxv::Op.SetGlobal {:slot s} (:wat::string::concat "SETG/" (:wat::i64::to-string s))]
    [:loxv::Op.GetLocal {:slot s} (:wat::string::concat "GETL/" (:wat::i64::to-string s))]
    [:loxv::Op.SetLocal {:slot s} (:wat::string::concat "SETL/" (:wat::i64::to-string s))]
    [:loxv::Op.Jump {:offset o} (:wat::string::concat "JMP/" (:wat::i64::to-string o))]
    [:loxv::Op.JumpIfFalse {:offset o} (:wat::string::concat "JIF/" (:wat::i64::to-string o))]
    [:loxv::Op.Loop {:offset o} (:wat::string::concat "LOOP/" (:wat::i64::to-string o))]
    [:loxv::Op.Call {:argc a} (:wat::string::concat "CALL/" (:wat::i64::to-string a))]
    [:loxv::Op.Return {} "RET"]))

(:wat::core::defn :loxv::code-sig [c <- :loxv::Chunk] -> :wat::core::String
  (:wat::string::trim
    (:wat::core::foldl
      (:wat::core::fn [a <- :wat::core::String op <- :loxv::Op] -> :wat::core::String
        (:wat::string::concat a " " (:loxv::op-key op)))
      "" (:loxv::Chunk/code c))))
