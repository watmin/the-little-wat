;; lox/lib/v-vm.wat — the chapter-18 VM: a stack of tagged values, and runtime errors.
;;
;; Chapter 15's VM could not fail. Every opcode took doubles off a stack of doubles and pushed a
;; double back; there was nothing to check. Chapter 18's can: `-true` and `1 < nil` are programs
;; the compiler accepts and the VM must refuse, which is what a dynamically typed language IS.
;;
;; Nystrom reports a runtime error by `longjmp`-free unwinding -- `runtimeError()` prints, resets
;; the stack and returns `INTERPRET_RUNTIME_ERROR` up through `run()`. wat has no early return
;; and its only general catch spawns a thread (F-063), so the failure is a VALUE: every
;; instruction answers `Step.Next` or `Step.Fail`, and the loop stops on the second. That is the
;; same shape EOPL chapter 5's exceptions took (C-070) and it costs one `match` per instruction.

(:wat::load-file! "v-value.wat")

;; chapter 21 gives the VM state beyond its stack: a table of globals, and an output. Nystrom
;; mutates `vm.globals` and calls `printf`; both are values here, so every instruction carries
;; all three forward. That is one enum allocation per instruction either way -- three fields
;; rather than one -- but it does mean a `print` is a `conj` onto a vector that the test can read
;; back, which is how ch21 checks a program's OUTPUT rather than its stack.
(:wat::core::typealias :loxv::Globals (:wat::core::HashMap :- [:wat::core::String :loxv::Val]))
(:wat::core::typealias :loxv::Output (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defenum :loxv::Step :wat::enum::Pure
  :Next [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output]
  ;; chapter 23: an instruction that sets `ip` rather than advancing it
  :Jump [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output  target <- :wat::core::i64]
  ;; chapter 24: an instruction that changes which CHUNK is running
  :Call [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output
         argc <- :wat::core::i64  chunk <- :loxv::Chunk
         ups <- (:wat::core::Vector :- [:wat::core::i64])]
  :Ret  [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output]
  ;; chapter 25: four instructions that touch the CELL table, which lives in the loop rather
  ;; than in `exec` -- the same arrangement jumps and calls already use
  :MakeClosure [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output  slot <- :wat::core::i64]
  :GetUp [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output  slot <- :wat::core::i64]
  :SetUp [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output  slot <- :wat::core::i64]
  :CloseUp [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output]
  :Fail [msg <- :wat::core::String])

;; an upvalue's home. OPEN means the variable is still on the stack and the cell is an alias for
;; that slot; CLOSED means the frame is gone and the cell owns the value. Nystrom's `Value*
;; location` and `Value closed` in one enum, with the pointer replaced by an index.
(:wat::core::defenum :loxv::Cell :wat::enum::Pure
  :OnStack [idx <- :wat::core::i64]
  :Closed  [v <- :loxv::Val]
  ;; chapter 26: a slot the collector has reclaimed. Nystrom's sweep `free()`s the object and
  ;; unlinks it; a table cannot forget an index, so the slot is marked free and reused.
  :Free    [])

(:wat::core::typealias :loxv::Cells (:wat::core::Vector :- [:loxv::Cell]))

;; the frames the VM has left behind. The CURRENT frame is not in here -- it rides in
;; `run-loop`'s arguments, which is C-098's threaded shape: a frame record allocated per CALL
;; rather than per instruction.
(:wat::core::defrecord :loxv::Saved
  [chunk <- :loxv::Chunk  ip <- :wat::core::i64  base <- :wat::core::i64
   ups <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::defenum :loxv::Out :wat::enum::Pure
  :Ok  [stack <- :loxv::Stack  globals <- :loxv::Globals  out <- :loxv::Output  steps <- :wat::core::i64]
  :Err [msg <- :wat::core::String  line <- :wat::core::i64  out <- :loxv::Output  steps <- :wat::core::i64])

;; F-104 and F-088 again: no positional update, and `take` answers a Stream, so a pop rebuilds.
(:wat::core::defn :loxv::take-k [s <- :loxv::Stack k <- :wat::core::i64 i <- :wat::core::i64
                                 acc <- :loxv::Stack] -> :loxv::Stack
  (:wat::core::if (:wat::core::>= i k) acc
    (:loxv::take-k s k (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth s i)))))

(:wat::core::defn :loxv::pop-n [s <- :loxv::Stack n <- :wat::core::i64] -> :loxv::Stack
  (:loxv::take-k s (:wat::core::- (:wat::core::length s) n) 0 (:wat::core::Vector :- [:loxv::Val])))

;; **F-104, in the inner loop.** Chapter 22 puts locals ON the stack, so `OP_SET_LOCAL` is
;; `vm.stack[slot] = peek(0)` -- a positional write to a vector, which neither of wat's vector
;; types has. Nystrom's line is an assignment into an array; this rebuilds the stack.
;; `lox/ch22-local-variables.wat` measures what that costs as the number of locals grows.
(:wat::core::defn :loxv::set-at [s <- :loxv::Stack i <- :wat::core::i64 v <- :loxv::Val
                                 j <- :wat::core::i64 acc <- :loxv::Stack] -> :loxv::Stack
  (:wat::core::if (:wat::core::>= j (:wat::core::length s)) acc
    (:loxv::set-at s i v (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= j i) v (:wat::core::nth s j))))))

(:wat::core::defn :loxv::store [s <- :loxv::Stack i <- :wat::core::i64 v <- :loxv::Val] -> :loxv::Stack
  (:loxv::set-at s i v 0 (:wat::core::Vector :- [:loxv::Val])))

(:wat::core::defn :loxv::peek-n [s <- :loxv::Stack n <- :wat::core::i64] -> :loxv::Val
  (:wat::core::nth s (:wat::core::- (:wat::core::length s) (:wat::core::+ n 1))))

(:wat::core::defn :loxv::num [x <- :wat::core::f64] -> :loxv::Val (:loxv::Val.Num {:n x}))
(:wat::core::defn :loxv::str [x <- :wat::core::String] -> :loxv::Val (:loxv::Val.Str {:s x}))
(:wat::core::defn :loxv::bool [x <- :wat::core::bool] -> :loxv::Val (:loxv::Val.Bool {:b x}))

;; a binary operator over two numbers, or Nystrom's "Operands must be numbers."
(:wat::core::defn :loxv::binary-num [s <- :loxv::Stack g <- :loxv::Globals out <- :loxv::Output
                                     which <- :wat::core::String] -> :loxv::Step
  (:wat::core::if (:wat::core::< (:wat::core::length s) 2) (:loxv::Step.Fail {:msg "Stack underflow."})
    (:wat::core::let [b (:loxv::peek-n s 0)
                      a (:loxv::peek-n s 1)
                      rest (:loxv::pop-n s 2)]
      (:wat::core::if (:wat::core::not (:wat::core::and (:loxv::num? a) (:loxv::num? b)))
        (:loxv::Step.Fail {:msg "Operands must be numbers."})
        (:wat::core::let [x (:loxv::as-num a) y (:loxv::as-num b)]
          (:loxv::Step.Next {:g g :out out :s (:wat::core::conj rest
            (:wat::core::cond
              ((:wat::core::= which "+") (:loxv::num (:wat::core::+ x y)))
              ((:wat::core::= which "-") (:loxv::num (:wat::core::- x y)))
              ((:wat::core::= which "*") (:loxv::num (:wat::core::* x y)))
              ((:wat::core::= which "/") (:loxv::num (:wat::core::/ x y)))
              ((:wat::core::= which ">") (:loxv::bool (:wat::core::> x y)))
              (:else (:loxv::bool (:wat::core::< x y)))))}))))))

(:wat::core::defn :loxv::op-add [s <- :loxv::Stack g <- :loxv::Globals out <- :loxv::Output] -> :loxv::Step
  (:wat::core::if (:wat::core::< (:wat::core::length s) 2) (:loxv::Step.Fail {:msg "Stack underflow."})
    (:wat::core::let [b (:loxv::peek-n s 0)
                      a (:loxv::peek-n s 1)
                      rest (:loxv::pop-n s 2)]
      (:wat::core::cond
        ((:wat::core::and (:loxv::num? a) (:loxv::num? b))
          (:loxv::Step.Next {:g g :out out :s (:wat::core::conj rest
            (:loxv::num (:wat::core::+ (:loxv::as-num a) (:loxv::as-num b))))}))
        ;; concatenate(). In C this allocates, copies both halves and takes ownership; here it is
        ;; `:wat::string::concat` and the result is just another value.
        ((:wat::core::and (:loxv::str? a) (:loxv::str? b))
          (:loxv::Step.Next {:g g :out out :s (:wat::core::conj rest
            (:loxv::str (:wat::string::concat (:loxv::as-str a) (:loxv::as-str b))))}))
        (:else (:loxv::Step.Fail {:msg "Operands must be two numbers or two strings."}))))))

;; the variable's NAME lives in the constant pool -- Nystrom's identifierConstant()
(:wat::core::defn :loxv::global-name [c <- :loxv::Chunk slot <- :wat::core::i64] -> :wat::core::String
  (:loxv::as-str (:wat::core::nth (:loxv::Chunk/constants c) slot)))

(:wat::core::defn :loxv::undefined [name <- :wat::core::String] -> :loxv::Step
  (:loxv::Step.Fail {:msg (:wat::string::concat "Undefined variable '" name "'.")}))

;; Nystrom's natives are C function pointers stored in a value. A closure cannot live in a
;; `:wat::enum::Pure` (F-114), so a native is a NAME and the VM dispatches on it -- which is what
;; a table of function pointers is, spelled as a match.
(:wat::core::defn :loxv::native-call [s <- :loxv::Stack g <- :loxv::Globals out <- :loxv::Output
                                      name <- :wat::core::String argc <- :wat::core::i64] -> :loxv::Step
  (:wat::core::let [rest (:loxv::pop-n s (:wat::core::+ argc 1))]
    (:wat::core::cond
      ;; clock(): the one native chapter 24 defines
      ((:wat::core::= name "clock")
        (:loxv::Step.Next {:g g :out out :s (:wat::core::conj rest
          (:loxv::num (:wat::core::/ (:wat::i64::to-f64 (:wat::time::epoch-nanos (:wat::time::now))) 1000000000.0)))}))
      ;; two deterministic ones, so the chapter can check a native's RESULT and not only its type
      ((:wat::core::= name "double")
        (:wat::core::let [a (:loxv::peek-n s 0)]
          (:wat::core::if (:wat::core::not (:loxv::num? a))
            (:loxv::Step.Fail {:msg "Operand must be a number."})
            (:loxv::Step.Next {:g g :out out :s (:wat::core::conj rest
              (:loxv::num (:wat::core::* 2.0 (:loxv::as-num a))))}))))
      ((:wat::core::= name "answer")
        (:loxv::Step.Next {:g g :out out :s (:wat::core::conj rest (:loxv::num 42.0))}))
      (:else (:loxv::Step.Fail {:msg (:wat::string::concat "Unknown native '" name "'.")})))))

(:wat::core::defn :loxv::exec [op <- :loxv::Op c <- :loxv::Chunk s <- :loxv::Stack
                               g <- :loxv::Globals out <- :loxv::Output
                               ip <- :wat::core::i64 base <- :wat::core::i64] -> :loxv::Step
  (:wat::core::match op
    [:loxv::Op.Constant {:slot i}
      (:loxv::Step.Next {:g g :out out :s (:wat::core::conj s (:wat::core::nth (:loxv::Chunk/constants c) i))})]
    [:loxv::Op.Nil {} (:loxv::Step.Next {:g g :out out :s (:wat::core::conj s (:loxv::Val.Nil {}))})]
    [:loxv::Op.True {} (:loxv::Step.Next {:g g :out out :s (:wat::core::conj s (:loxv::bool true))})]
    [:loxv::Op.False {} (:loxv::Step.Next {:g g :out out :s (:wat::core::conj s (:loxv::bool false))})]
    ;; == compares ANY two values; only the comparisons demand numbers
    [:loxv::Op.Equal {}
      (:wat::core::if (:wat::core::< (:wat::core::length s) 2) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:loxv::Step.Next {:g g :out out :s (:wat::core::conj (:loxv::pop-n s 2)
          (:loxv::bool (:loxv::equal? (:loxv::peek-n s 1) (:loxv::peek-n s 0))))}))]
    [:loxv::Op.Greater {} (:loxv::binary-num s g out ">")]
    [:loxv::Op.Less {} (:loxv::binary-num s g out "<")]
    ;; chapter 19: `+` is the one overloaded operator, so it does its own operand check
    [:loxv::Op.Add {} (:loxv::op-add s g out)]
    [:loxv::Op.Subtract {} (:loxv::binary-num s g out "-")]
    [:loxv::Op.Multiply {} (:loxv::binary-num s g out "*")]
    [:loxv::Op.Divide {} (:loxv::binary-num s g out "/")]
    ;; `!` accepts anything -- falsey? is total
    [:loxv::Op.Not {}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:loxv::Step.Next {:g g :out out :s (:wat::core::conj (:loxv::pop-n s 1)
          (:loxv::bool (:loxv::falsey? (:loxv::peek-n s 0))))}))]
    [:loxv::Op.Negate {}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:wat::core::if (:wat::core::not (:loxv::num? (:loxv::peek-n s 0)))
          (:loxv::Step.Fail {:msg "Operand must be a number."})
          (:loxv::Step.Next {:g g :out out :s (:wat::core::conj (:loxv::pop-n s 1)
            (:loxv::num (:wat::core::- 0.0 (:loxv::as-num (:loxv::peek-n s 0)))))})))]
    ;; ---- chapter 21
    [:loxv::Op.Print {}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:loxv::Step.Next {:g g :s (:loxv::pop-n s 1)
          :out (:wat::core::conj out (:loxv::show (:loxv::peek-n s 0)))}))]
    [:loxv::Op.Pop {}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:loxv::Step.Next {:g g :out out :s (:loxv::pop-n s 1)}))]
    ;; define always succeeds, and REDEFINING a global is legal in Lox -- deliberately, so the
    ;; REPL can say `var a = 1;` twice
    [:loxv::Op.DefineGlobal {:slot i}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:loxv::Step.Next {:out out :s (:loxv::pop-n s 1)
          :g (:wat::core::assoc g (:loxv::global-name c i) (:loxv::peek-n s 0))}))]
    [:loxv::Op.GetGlobal {:slot i}
      (:wat::core::let [name (:loxv::global-name c i)]
        (:wat::core::match (:wat::core::get g name)
          [:wat::core::Option.None {} (:loxv::undefined name)]
          [:wat::core::Option.Some {:value v}
            (:loxv::Step.Next {:g g :out out :s (:wat::core::conj s v)})]))]
    ;; assignment is an EXPRESSION, so it leaves its value on the stack; and assigning to a
    ;; variable that was never defined is an error rather than a definition
    [:loxv::Op.SetGlobal {:slot i}
      (:wat::core::let [name (:loxv::global-name c i)]
        (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
          (:wat::core::if (:wat::core::not (:wat::core::contains? g name)) (:loxv::undefined name)
            (:loxv::Step.Next {:out out :s s
              :g (:wat::core::assoc g name (:loxv::peek-n s 0))}))))]
    ;; ---- chapter 22: locals, which live on the stack itself. From chapter 24 a slot is
    ;; relative to the CURRENT FRAME's base, which is what makes the same function body work at
    ;; any call depth.
    [:loxv::Op.GetLocal {:slot i}
      (:wat::core::if (:wat::core::>= (:wat::core::+ base i) (:wat::core::length s))
        (:loxv::Step.Fail {:msg "Bad local slot."})
        (:loxv::Step.Next {:g g :out out :s (:wat::core::conj s (:wat::core::nth s (:wat::core::+ base i)))}))]
    ;; assignment is an expression, so the value STAYS on the stack after being stored
    [:loxv::Op.SetLocal {:slot i}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:wat::core::if (:wat::core::>= (:wat::core::+ base i) (:wat::core::length s))
          (:loxv::Step.Fail {:msg "Bad local slot."})
          (:loxv::Step.Next {:g g :out out :s (:loxv::store s (:wat::core::+ base i) (:loxv::peek-n s 0))})))]
    ;; ---- chapter 23. A jump is a value, so the loop does not have to reach into `exec`.
    [:loxv::Op.Jump {:offset o}
      (:loxv::Step.Jump {:g g :out out :s s :target (:wat::core::+ (:wat::core::+ ip 1) o)})]
    ;; the condition is PEEKED, not popped -- the surrounding code emits the Pop, which is what
    ;; lets `and` and `or` leave their operand behind as the expression's value
    [:loxv::Op.JumpIfFalse {:offset o}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:wat::core::if (:loxv::falsey? (:loxv::peek-n s 0))
          (:loxv::Step.Jump {:g g :out out :s s :target (:wat::core::+ (:wat::core::+ ip 1) o)})
          (:loxv::Step.Next {:g g :out out :s s})))]
    [:loxv::Op.Loop {:offset o}
      (:loxv::Step.Jump {:g g :out out :s s :target (:wat::core::- (:wat::core::+ ip 1) o)})]
    ;; ---- chapter 24
    [:loxv::Op.Call {:argc n}
      (:wat::core::if (:wat::core::< (:wat::core::length s) (:wat::core::+ n 1))
        (:loxv::Step.Fail {:msg "Stack underflow."})
        (:wat::core::match (:loxv::peek-n s n)
          ;; after chapter 25 only a CLOSURE is callable -- every function literal is wrapped by
          ;; OP_CLOSURE, so a bare `Fn` is a constant-pool entry and never a user-visible value
          [:loxv::Val.Closure {:chunk fc :name nm :arity a :cells cs}
            (:wat::core::if (:wat::core::not= a n)
              (:loxv::Step.Fail {:msg (:wat::string::concat "Expected " (:wat::i64::to-string a)
                                        " arguments but got " (:wat::i64::to-string n) ".")})
              (:loxv::Step.Call {:g g :out out :s s :argc n :chunk fc :ups cs}))]
          [:loxv::Val.Fn {:chunk fc :name nm :arity a :updescs u}
            (:loxv::Step.Fail {:msg "Can only call functions and classes."})]
          [:loxv::Val.Native {:name nm :arity a}
            (:wat::core::if (:wat::core::not= a n)
              (:loxv::Step.Fail {:msg (:wat::string::concat "Expected " (:wat::i64::to-string a)
                                        " arguments but got " (:wat::i64::to-string n) ".")})
              (:loxv::native-call s g out nm n))]
          [:loxv::Val.Nil {} (:loxv::Step.Fail {:msg "Can only call functions and classes."})]
          [:loxv::Val.Bool {:b b} (:loxv::Step.Fail {:msg "Can only call functions and classes."})]
          [:loxv::Val.Num {:n x} (:loxv::Step.Fail {:msg "Can only call functions and classes."})]
          [:loxv::Val.Str {:s x} (:loxv::Step.Fail {:msg "Can only call functions and classes."})]))]
    ;; ---- chapter 25: handled by the loop, which owns the cell table
    [:loxv::Op.Closure {:slot i} (:loxv::Step.MakeClosure {:g g :out out :s s :slot i})]
    [:loxv::Op.GetUpvalue {:slot i} (:loxv::Step.GetUp {:g g :out out :s s :slot i})]
    [:loxv::Op.SetUpvalue {:slot i} (:loxv::Step.SetUp {:g g :out out :s s :slot i})]
    [:loxv::Op.CloseUpvalue {} (:loxv::Step.CloseUp {:g g :out out :s s})]
    [:loxv::Op.Return {} (:loxv::Step.Ret {:g g :out out :s s})]))

;; kept for the disassembler's sake; the LOOP no longer uses it, because a Return now pops a
;; call frame and only the outermost one ends the program
(:wat::core::defn :loxv::halts? [op <- :loxv::Op] -> :wat::core::bool
  (:wat::core::match op
    [:loxv::Op.Return {} true]
    [:loxv::Op.Constant {:slot i} false] [:loxv::Op.Nil {} false] [:loxv::Op.True {} false]
    [:loxv::Op.False {} false] [:loxv::Op.Equal {} false] [:loxv::Op.Greater {} false]
    [:loxv::Op.Less {} false] [:loxv::Op.Add {} false] [:loxv::Op.Subtract {} false]
    [:loxv::Op.Multiply {} false] [:loxv::Op.Divide {} false] [:loxv::Op.Not {} false]
    [:loxv::Op.Negate {} false] [:loxv::Op.Print {} false] [:loxv::Op.Pop {} false]
    [:loxv::Op.DefineGlobal {:slot i} false] [:loxv::Op.GetGlobal {:slot i} false]
    [:loxv::Op.SetGlobal {:slot i} false]
    [:loxv::Op.GetLocal {:slot i} false] [:loxv::Op.SetLocal {:slot i} false]
    [:loxv::Op.Jump {:offset o} false] [:loxv::Op.JumpIfFalse {:offset o} false]
    [:loxv::Op.Loop {:offset o} false] [:loxv::Op.Call {:argc a} false]
    [:loxv::Op.Closure {:slot i} false] [:loxv::Op.GetUpvalue {:slot i} false]
    [:loxv::Op.SetUpvalue {:slot i} false] [:loxv::Op.CloseUpvalue {} false]))

;; drop the innermost saved frame -- F-104 once more, but paid per RETURN rather than per
;; instruction, which is the difference between a tax and a disaster
(:wat::core::defn :loxv::frames-take [v <- (:wat::core::Vector :- [:loxv::Saved]) k <- :wat::core::i64
                                      j <- :wat::core::i64
                                      acc <- (:wat::core::Vector :- [:loxv::Saved])]
  -> (:wat::core::Vector :- [:loxv::Saved])
  (:wat::core::if (:wat::core::>= j k) acc
    (:loxv::frames-take v k (:wat::core::+ j 1) (:wat::core::conj acc (:wat::core::nth v j)))))

;; ---- the cell table (chapter 25)
(:wat::core::defn :loxv::cells-set [v <- :loxv::Cells i <- :wat::core::i64 x <- :loxv::Cell
                                    j <- :wat::core::i64 acc <- :loxv::Cells] -> :loxv::Cells
  (:wat::core::if (:wat::core::>= j (:wat::core::length v)) acc
    (:loxv::cells-set v i x (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= j i) x (:wat::core::nth v j))))))

(:wat::core::defn :loxv::cell-read [cells <- :loxv::Cells s <- :loxv::Stack id <- :wat::core::i64] -> :loxv::Val
  (:wat::core::match (:wat::core::nth cells id)
    [:loxv::Cell.Closed {:v v} v]
    ;; reading a freed cell would mean the collector reclaimed something reachable; it answers
    ;; nil rather than crashing, and ch26 checks that it never happens
    [:loxv::Cell.Free {} (:loxv::Val.Nil {})]
    [:loxv::Cell.OnStack {:idx i}
      (:wat::core::if (:wat::core::>= i (:wat::core::length s)) (:loxv::Val.Nil {}) (:wat::core::nth s i))]))

;; a write goes to the STACK while the cell is open and to the cell once it is closed, which is
;; the whole reason the indirection exists
(:wat::core::defrecord :loxv::CW [cells <- :loxv::Cells  s <- :loxv::Stack])

(:wat::core::defn :loxv::cell-write [cells <- :loxv::Cells s <- :loxv::Stack id <- :wat::core::i64
                                     v <- :loxv::Val] -> :loxv::CW
  (:wat::core::match (:wat::core::nth cells id)
    [:loxv::Cell.OnStack {:idx i} (:loxv::CW :cells cells :s (:loxv::store s i v))]
    [:loxv::Cell.Free {} (:loxv::CW :cells cells :s s)]
    [:loxv::Cell.Closed {:v old}
      (:loxv::CW :s s :cells (:loxv::cells-set cells id (:loxv::Cell.Closed {:v v}) 0
                               (:wat::core::Vector :- [:loxv::Cell])))]))

;; captureUpvalue's search: one cell per captured stack slot, so two closures over one variable
;; get the SAME id and therefore see each other's writes
(:wat::core::defn :loxv::find-open [cells <- :loxv::Cells idx <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length cells)) -1
    (:wat::core::match (:wat::core::nth cells i)
      [:loxv::Cell.OnStack {:idx j} (:wat::core::if (:wat::core::= j idx) i
                                      (:loxv::find-open cells idx (:wat::core::+ i 1)))]
      [:loxv::Cell.Free {} (:loxv::find-open cells idx (:wat::core::+ i 1))]
      [:loxv::Cell.Closed {:v v} (:loxv::find-open cells idx (:wat::core::+ i 1))])))

;; the first reclaimed slot, or -1 -- Nystrom's free list, as a scan
(:wat::core::defn :loxv::find-free [cells <- :loxv::Cells i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length cells)) -1
    (:wat::core::match (:wat::core::nth cells i)
      [:loxv::Cell.Free {} i]
      [:loxv::Cell.OnStack {:idx j} (:loxv::find-free cells (:wat::core::+ i 1))]
      [:loxv::Cell.Closed {:v v} (:loxv::find-free cells (:wat::core::+ i 1))])))

;; closeUpvalues(last): every open cell at or above `from` takes its value with it
(:wat::core::defn :loxv::close-from [cells <- :loxv::Cells s <- :loxv::Stack from <- :wat::core::i64
                                     i <- :wat::core::i64] -> :loxv::Cells
  (:wat::core::if (:wat::core::>= i (:wat::core::length cells)) cells
    (:wat::core::match (:wat::core::nth cells i)
      [:loxv::Cell.Closed {:v v} (:loxv::close-from cells s from (:wat::core::+ i 1))]
      [:loxv::Cell.Free {} (:loxv::close-from cells s from (:wat::core::+ i 1))]
      [:loxv::Cell.OnStack {:idx j}
        (:wat::core::if (:wat::core::< j from) (:loxv::close-from cells s from (:wat::core::+ i 1))
          (:loxv::close-from
            (:loxv::cells-set cells i
              (:loxv::Cell.Closed {:v (:wat::core::if (:wat::core::>= j (:wat::core::length s))
                                        (:loxv::Val.Nil {}) (:wat::core::nth s j))})
              0 (:wat::core::Vector :- [:loxv::Cell]))
            s from (:wat::core::+ i 1)))])))

;; the ids a new closure captures, and the cells table after any it had to create
(:wat::core::defrecord :loxv::CapR
  [cells <- :loxv::Cells  ids <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::defn :loxv::capture [cells <- :loxv::Cells base <- :wat::core::i64
                                  ups <- (:wat::core::Vector :- [:wat::core::i64])
                                  descs <- (:wat::core::Vector :- [:loxv::UpDesc])
                                  i <- :wat::core::i64
                                  acc <- (:wat::core::Vector :- [:wat::core::i64])] -> :loxv::CapR
  (:wat::core::if (:wat::core::>= i (:wat::core::length descs)) (:loxv::CapR :cells cells :ids acc)
    (:wat::core::let [d (:wat::core::nth descs i)]
      (:wat::core::if (:loxv::UpDesc/is-local d)
        (:wat::core::let [target (:wat::core::+ base (:loxv::UpDesc/index d))
                          found (:loxv::find-open cells target 0)]
          (:wat::core::if (:wat::core::>= found 0)
            (:loxv::capture cells base ups descs (:wat::core::+ i 1) (:wat::core::conj acc found))
            (:wat::core::let [slot (:loxv::find-free cells 0)]
              (:wat::core::if (:wat::core::>= slot 0)
                (:loxv::capture
                  (:loxv::cells-set cells slot (:loxv::Cell.OnStack {:idx target}) 0
                    (:wat::core::Vector :- [:loxv::Cell]))
                  base ups descs (:wat::core::+ i 1) (:wat::core::conj acc slot))
                (:loxv::capture (:wat::core::conj cells (:loxv::Cell.OnStack {:idx target}))
                  base ups descs (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::length cells)))))))
        (:loxv::capture cells base ups descs (:wat::core::+ i 1)
          (:wat::core::conj acc (:wat::core::nth ups (:loxv::UpDesc/index d))))))))

;; F-019: widen the variant to the enum, as everywhere else
(:wat::core::defn :loxv::closureval [c <- :loxv::Chunk name <- :wat::core::String arity <- :wat::core::i64
                                     cells <- (:wat::core::Vector :- [:wat::core::i64])] -> :loxv::Val
  (:loxv::Val.Closure {:chunk c :name name :arity arity :cells cells}))

;; ---- chapter 26: mark and sweep, over the only heap this VM actually has
;;
;; Nystrom collects `Obj`s -- strings, functions, closures, upvalues -- because C's heap is his to
;; manage. wat's heap is not, so most of the chapter has no object to collect. What DOES need
;; collecting is the cell table chapter 25 introduced: `capture` allocates a cell every time a
;; closure captures a variable, and nothing ever released one. A loop that makes closures grew the
;; table without bound.
;;
;; So this is a real mark-sweep collector over a real leak, not a simulation of one. The roots are
;; the same roots clox has: the value stack, the globals, and every frame's captured cells. The
;; only structural difference is that a table cannot forget an index, so a swept slot becomes
;; `Cell.Free` and is reused rather than unlinked -- which is a free list, spelled as a scan.

(:wat::core::typealias :loxv::Marks (:wat::core::Vector :- [:wat::core::bool]))

(:wat::core::defn :loxv::new-marks [n <- :wat::core::i64 i <- :wat::core::i64 acc <- :loxv::Marks] -> :loxv::Marks
  (:wat::core::if (:wat::core::>= i n) acc (:loxv::new-marks n (:wat::core::+ i 1) (:wat::core::conj acc false))))

(:wat::core::defn :loxv::marks-set [v <- :loxv::Marks i <- :wat::core::i64 j <- :wat::core::i64
                                    acc <- :loxv::Marks] -> :loxv::Marks
  (:wat::core::if (:wat::core::>= j (:wat::core::length v)) acc
    (:loxv::marks-set v i (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::or (:wat::core::= j i) (:wat::core::nth v j))))))

(:wat::core::defn :loxv::mark-ids [ids <- (:wat::core::Vector :- [:wat::core::i64]) i <- :wat::core::i64
                                   marked <- :loxv::Marks] -> :loxv::Marks
  (:wat::core::if (:wat::core::>= i (:wat::core::length ids)) marked
    (:loxv::mark-ids ids (:wat::core::+ i 1)
      (:loxv::marks-set marked (:wat::core::nth ids i) 0 (:wat::core::Vector :- [:wat::core::bool])))))

(:wat::core::defn :loxv::mark-val [v <- :loxv::Val marked <- :loxv::Marks] -> :loxv::Marks
  (:wat::core::match v
    [:loxv::Val.Closure {:chunk c :name nm :arity a :cells cs} (:loxv::mark-ids cs 0 marked)]
    [:loxv::Val.Nil {} marked] [:loxv::Val.Bool {:b b} marked] [:loxv::Val.Num {:n n} marked]
    [:loxv::Val.Str {:s x} marked] [:loxv::Val.Native {:name nm :arity a} marked]
    [:loxv::Val.Fn {:chunk c :name nm :arity a :updescs u} marked]))

(:wat::core::defn :loxv::mark-vals [vs <- (:wat::core::Vector :- [:loxv::Val]) i <- :wat::core::i64
                                    marked <- :loxv::Marks] -> :loxv::Marks
  (:wat::core::if (:wat::core::>= i (:wat::core::length vs)) marked
    (:loxv::mark-vals vs (:wat::core::+ i 1) (:loxv::mark-val (:wat::core::nth vs i) marked))))

(:wat::core::defn :loxv::mark-frames [fs <- (:wat::core::Vector :- [:loxv::Saved]) i <- :wat::core::i64
                                      marked <- :loxv::Marks] -> :loxv::Marks
  (:wat::core::if (:wat::core::>= i (:wat::core::length fs)) marked
    (:loxv::mark-frames fs (:wat::core::+ i 1)
      (:loxv::mark-ids (:loxv::Saved/ups (:wat::core::nth fs i)) 0 marked))))

;; a marked cell whose value is a closure keeps that closure's cells alive too, so marking is a
;; fixpoint -- clox's grey stack, run to exhaustion instead of worklist-style
(:wat::core::defrecord :loxv::MarkR [marked <- :loxv::Marks  changed <- :wat::core::bool])

(:wat::core::defn :loxv::propagate [cells <- :loxv::Cells marked <- :loxv::Marks i <- :wat::core::i64
                                    changed <- :wat::core::bool] -> :loxv::MarkR
  (:wat::core::if (:wat::core::>= i (:wat::core::length cells)) (:loxv::MarkR :marked marked :changed changed)
    (:wat::core::if (:wat::core::not (:wat::core::nth marked i))
      (:loxv::propagate cells marked (:wat::core::+ i 1) changed)
      (:wat::core::match (:wat::core::nth cells i)
        [:loxv::Cell.Closed {:v v}
          (:wat::core::let [m2 (:loxv::mark-val v marked)]
            (:loxv::propagate cells m2 (:wat::core::+ i 1)
              (:wat::core::or changed (:wat::core::not= m2 marked))))]
        [:loxv::Cell.OnStack {:idx j} (:loxv::propagate cells marked (:wat::core::+ i 1) changed)]
        [:loxv::Cell.Free {} (:loxv::propagate cells marked (:wat::core::+ i 1) changed)]))))

(:wat::core::defn :loxv::mark-fixpoint [cells <- :loxv::Cells marked <- :loxv::Marks
                                        fuel <- :wat::core::i64] -> :loxv::Marks
  (:wat::core::if (:wat::core::= fuel 0) marked
    (:wat::core::let [r (:loxv::propagate cells marked 0 false)]
      (:wat::core::if (:loxv::MarkR/changed r)
        (:loxv::mark-fixpoint cells (:loxv::MarkR/marked r) (:wat::core::- fuel 1))
        (:loxv::MarkR/marked r)))))

(:wat::core::defn :loxv::sweep [cells <- :loxv::Cells marked <- :loxv::Marks i <- :wat::core::i64
                                acc <- :loxv::Cells] -> :loxv::Cells
  (:wat::core::if (:wat::core::>= i (:wat::core::length cells)) acc
    (:loxv::sweep cells marked (:wat::core::+ i 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::nth marked i) (:wat::core::nth cells i)
                              (:loxv::Cell.Free {}))))))

(:wat::core::defn :loxv::collect [cells <- :loxv::Cells s <- :loxv::Stack g <- :loxv::Globals
                                  ups <- (:wat::core::Vector :- [:wat::core::i64])
                                  frames <- (:wat::core::Vector :- [:loxv::Saved])] -> :loxv::Cells
  (:wat::core::let
    [m0 (:loxv::new-marks (:wat::core::length cells) 0 (:wat::core::Vector :- [:wat::core::bool]))
     m1 (:loxv::mark-ids ups 0 m0)
     m2 (:loxv::mark-frames frames 0 m1)
     m3 (:loxv::mark-vals s 0 m2)
     m4 (:loxv::mark-vals (:wat::core::values g) 0 m3)
     m5 (:loxv::mark-fixpoint cells m4 (:wat::core::length cells))]
    (:loxv::sweep cells m5 0 (:wat::core::Vector :- [:loxv::Cell]))))

(:wat::core::defn :loxv::live-cells [cells <- :loxv::Cells i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length cells)) acc
    (:loxv::live-cells cells (:wat::core::+ i 1)
      (:wat::core::match (:wat::core::nth cells i)
        [:loxv::Cell.Free {} acc]
        [:loxv::Cell.OnStack {:idx j} (:wat::core::+ acc 1)]
        [:loxv::Cell.Closed {:v v} (:wat::core::+ acc 1)]))))

;; what a run did, beyond its answer: the cell table it ended with, the largest it ever was, and
;; how many collections ran. `run` still answers an `Out`, so every earlier chapter is untouched.
(:wat::core::defrecord :loxv::Run
  [out <- :loxv::Out  cells <- :loxv::Cells  peak <- :wat::core::i64  collections <- :wat::core::i64])

;; the threaded loop -- C-098's cheaper shape, chosen on that chapter's evidence. The CURRENT
;; frame's chunk, ip, base and captured cells ride in the arguments; only enclosing frames are a
;; vector. `peak` and `ncol` are chapter 26's instruments.
(:wat::core::defn :loxv::run-loop [c <- :loxv::Chunk ip <- :wat::core::i64 base <- :wat::core::i64
                                   ups <- (:wat::core::Vector :- [:wat::core::i64])
                                   frames <- (:wat::core::Vector :- [:loxv::Saved])
                                   s <- :loxv::Stack g <- :loxv::Globals out <- :loxv::Output
                                   cells <- :loxv::Cells
                                   steps <- :wat::core::i64 peak <- :wat::core::i64
                                   ncol <- :wat::core::i64 gcat <- :wat::core::i64] -> :loxv::Run
  (:wat::core::if (:wat::core::>= ip (:loxv::count c))
    (:loxv::Run :cells cells :peak peak :collections ncol
      :out (:loxv::Out.Ok {:stack s :globals g :out out :steps steps}))
    (:wat::core::let [op (:wat::core::nth (:loxv::Chunk/code c) ip)]
      (:wat::core::match (:loxv::exec op c s g out ip base)
        [:loxv::Step.Fail {:msg m}
          (:loxv::Run :cells cells :peak peak :collections ncol
            :out (:loxv::Out.Err {:msg m :line (:wat::core::nth (:loxv::Chunk/lines c) ip)
                                  :out out :steps (:wat::core::+ steps 1)}))]
        [:loxv::Step.Jump {:s s2 :g g2 :out o2 :target t}
          (:loxv::run-loop c t base ups frames s2 g2 o2 cells (:wat::core::+ steps 1) peak ncol gcat)]
        [:loxv::Step.Call {:s s2 :g g2 :out o2 :argc n :chunk fc :ups us}
          (:wat::core::if (:wat::core::> (:wat::core::length frames) 200)
            (:loxv::Run :cells cells :peak peak :collections ncol
              :out (:loxv::Out.Err {:msg "Stack overflow." :line (:wat::core::nth (:loxv::Chunk/lines c) ip)
                                    :out o2 :steps (:wat::core::+ steps 1)}))
            (:loxv::run-loop fc 0 (:wat::core::- (:wat::core::length s2) n) us
              (:wat::core::conj frames (:loxv::Saved :chunk c :ip (:wat::core::+ ip 1) :base base :ups ups))
              s2 g2 o2 cells (:wat::core::+ steps 1) peak ncol gcat))]
        [:loxv::Step.Ret {:s s2 :g g2 :out o2}
          (:wat::core::if (:wat::core::= (:wat::core::length frames) 0)
            (:loxv::Run :cells cells :peak peak :collections ncol
              :out (:loxv::Out.Ok {:stack s2 :globals g2 :out o2 :steps (:wat::core::+ steps 1)}))
            (:wat::core::let
              [result (:wat::core::if (:wat::core::= (:wat::core::length s2) 0) (:loxv::Val.Nil {})
                        (:loxv::peek-n s2 0))
               ;; anything this frame's locals were captured into must be closed before the
               ;; frame goes away, or the cell would alias a slot that no longer exists
               cells2 (:loxv::close-from cells s2 base 0)
               f (:wat::core::nth frames (:wat::core::- (:wat::core::length frames) 1))
               fr2 (:loxv::frames-take frames (:wat::core::- (:wat::core::length frames) 1) 0
                     (:wat::core::Vector :- [:loxv::Saved]))
               s3 (:wat::core::conj
                    (:loxv::take-k s2 (:wat::core::- base 1) 0 (:wat::core::Vector :- [:loxv::Val]))
                    result)]
              (:loxv::run-loop (:loxv::Saved/chunk f) (:loxv::Saved/ip f) (:loxv::Saved/base f)
                (:loxv::Saved/ups f) fr2 s3 g2 o2 cells2 (:wat::core::+ steps 1) peak ncol gcat)))]
        [:loxv::Step.MakeClosure {:s s2 :g g2 :out o2 :slot i}
          (:wat::core::match (:wat::core::nth (:loxv::Chunk/constants c) i)
            [:loxv::Val.Fn {:chunk fc :name nm :arity a :updescs descs}
              ;; chapter 26's trigger: a closure is about to allocate, so collect first if the
              ;; table has grown past the threshold. Nystrom collects on allocation too.
              (:wat::core::let
                [do-gc (:wat::core::>= (:wat::core::length cells) gcat)
                 cells0 (:wat::core::if do-gc (:loxv::collect cells s2 g2 ups frames) cells)
                 r (:loxv::capture cells0 base ups descs 0 (:wat::core::Vector :- [:wat::core::i64]))
                 cells1 (:loxv::CapR/cells r)
                 live (:loxv::live-cells cells1 0 0)]
                (:loxv::run-loop c (:wat::core::+ ip 1) base ups frames
                  (:wat::core::conj s2 (:loxv::closureval fc nm a (:loxv::CapR/ids r)))
                  g2 o2 cells1 (:wat::core::+ steps 1)
                  (:wat::core::if (:wat::core::> live peak) live peak)
                  (:wat::core::if do-gc (:wat::core::+ ncol 1) ncol) gcat))]
            [:loxv::Val.Nil {} (:loxv::bad-closure c ip cells peak ncol o2 steps)]
            [:loxv::Val.Bool {:b b} (:loxv::bad-closure c ip cells peak ncol o2 steps)]
            [:loxv::Val.Num {:n x} (:loxv::bad-closure c ip cells peak ncol o2 steps)]
            [:loxv::Val.Str {:s x} (:loxv::bad-closure c ip cells peak ncol o2 steps)]
            [:loxv::Val.Closure {:chunk fc :name nm :arity a :cells cs}
              (:loxv::bad-closure c ip cells peak ncol o2 steps)]
            [:loxv::Val.Native {:name nm :arity a} (:loxv::bad-closure c ip cells peak ncol o2 steps)])]
        [:loxv::Step.GetUp {:s s2 :g g2 :out o2 :slot i}
          (:loxv::run-loop c (:wat::core::+ ip 1) base ups frames
            (:wat::core::conj s2 (:loxv::cell-read cells s2 (:wat::core::nth ups i)))
            g2 o2 cells (:wat::core::+ steps 1) peak ncol gcat)]
        [:loxv::Step.SetUp {:s s2 :g g2 :out o2 :slot i}
          (:wat::core::let [w (:loxv::cell-write cells s2 (:wat::core::nth ups i) (:loxv::peek-n s2 0))]
            (:loxv::run-loop c (:wat::core::+ ip 1) base ups frames
              (:loxv::CW/s w) g2 o2 (:loxv::CW/cells w) (:wat::core::+ steps 1) peak ncol gcat))]
        ;; a block ending with a captured local: close its cell, then pop the slot
        [:loxv::Step.CloseUp {:s s2 :g g2 :out o2}
          (:loxv::run-loop c (:wat::core::+ ip 1) base ups frames
            (:loxv::pop-n s2 1) g2 o2
            (:loxv::close-from cells s2 (:wat::core::- (:wat::core::length s2) 1) 0)
            (:wat::core::+ steps 1) peak ncol gcat)]
        [:loxv::Step.Next {:s s2 :g g2 :out o2}
          (:loxv::run-loop c (:wat::core::+ ip 1) base ups frames s2 g2 o2 cells
            (:wat::core::+ steps 1) peak ncol gcat)]))))

(:wat::core::defn :loxv::bad-closure [c <- :loxv::Chunk ip <- :wat::core::i64 cells <- :loxv::Cells
                                      peak <- :wat::core::i64 ncol <- :wat::core::i64
                                      out <- :loxv::Output steps <- :wat::core::i64] -> :loxv::Run
  (:loxv::Run :cells cells :peak peak :collections ncol
    :out (:loxv::Out.Err {:msg "OP_CLOSURE on a non-function."
                          :line (:wat::core::nth (:loxv::Chunk/lines c) ip)
                          :out out :steps (:wat::core::+ steps 1)})))

;; F-019, again
(:wat::core::defn :loxv::native [name <- :wat::core::String arity <- :wat::core::i64] -> :loxv::Val
  (:loxv::Val.Native {:name name :arity arity}))

;; the three natives chapter 24 installs, present before the program starts
(:wat::core::defn :loxv::base-globals [] -> :loxv::Globals
  (:wat::core::assoc
    (:wat::core::assoc
      (:wat::core::assoc (:wat::core::HashMap :- [:wat::core::String :loxv::Val])
        "clock" (:loxv::native "clock" 0))
      "double" (:loxv::native "double" 1))
    "answer" (:loxv::native "answer" 0)))

;; `gcat` is the table size that triggers a collection -- Nystrom's `nextGC`, without the
;; doubling, so that a chapter can turn the collector OFF by raising it out of reach
(:wat::core::defn :loxv::run-at [c <- :loxv::Chunk gcat <- :wat::core::i64] -> :loxv::Run
  (:loxv::run-loop c 0 0 (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::Vector :- [:loxv::Saved])
    (:wat::core::Vector :- [:loxv::Val]) (:loxv::base-globals)
    (:wat::core::Vector :- [:wat::core::String])
    (:wat::core::Vector :- [:loxv::Cell]) 0 0 0 gcat))

(:wat::core::defn :loxv::run-full [c <- :loxv::Chunk] -> :loxv::Run (:loxv::run-at c 8))

;; the same VM with the collector out of reach -- the control every GC claim needs
(:wat::core::defn :loxv::run-nogc [c <- :loxv::Chunk] -> :loxv::Run (:loxv::run-at c 1000000000))

;; every chapter before 26 wants only the answer, and this is what keeps them unedited
(:wat::core::defn :loxv::run [c <- :loxv::Chunk] -> :loxv::Out
  (:loxv::Run/out (:loxv::run-full c)))
