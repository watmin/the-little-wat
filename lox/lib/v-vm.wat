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
         argc <- :wat::core::i64  chunk <- :loxv::Chunk]
  :Ret  [s <- :loxv::Stack  g <- :loxv::Globals  out <- :loxv::Output]
  :Fail [msg <- :wat::core::String])

;; the frames the VM has left behind. The CURRENT frame is not in here -- it rides in
;; `run-loop`'s arguments, which is C-098's threaded shape: a frame record allocated per CALL
;; rather than per instruction.
(:wat::core::defrecord :loxv::Saved
  [chunk <- :loxv::Chunk  ip <- :wat::core::i64  base <- :wat::core::i64])

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
          [:loxv::Val.Fn {:chunk fc :name nm :arity a}
            (:wat::core::if (:wat::core::not= a n)
              (:loxv::Step.Fail {:msg (:wat::string::concat "Expected " (:wat::i64::to-string a)
                                        " arguments but got " (:wat::i64::to-string n) ".")})
              (:loxv::Step.Call {:g g :out out :s s :argc n :chunk fc}))]
          [:loxv::Val.Native {:name nm :arity a}
            (:wat::core::if (:wat::core::not= a n)
              (:loxv::Step.Fail {:msg (:wat::string::concat "Expected " (:wat::i64::to-string a)
                                        " arguments but got " (:wat::i64::to-string n) ".")})
              (:loxv::native-call s g out nm n))]
          [:loxv::Val.Nil {} (:loxv::Step.Fail {:msg "Can only call functions and classes."})]
          [:loxv::Val.Bool {:b b} (:loxv::Step.Fail {:msg "Can only call functions and classes."})]
          [:loxv::Val.Num {:n x} (:loxv::Step.Fail {:msg "Can only call functions and classes."})]
          [:loxv::Val.Str {:s x} (:loxv::Step.Fail {:msg "Can only call functions and classes."})]))]
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
    [:loxv::Op.Loop {:offset o} false] [:loxv::Op.Call {:argc a} false]))

;; drop the innermost saved frame -- F-104 once more, but paid per RETURN rather than per
;; instruction, which is the difference between a tax and a disaster
(:wat::core::defn :loxv::frames-take [v <- (:wat::core::Vector :- [:loxv::Saved]) k <- :wat::core::i64
                                      j <- :wat::core::i64
                                      acc <- (:wat::core::Vector :- [:loxv::Saved])]
  -> (:wat::core::Vector :- [:loxv::Saved])
  (:wat::core::if (:wat::core::>= j k) acc
    (:loxv::frames-take v k (:wat::core::+ j 1) (:wat::core::conj acc (:wat::core::nth v j)))))

;; the threaded loop -- C-098's cheaper shape, chosen on that chapter's evidence. The CURRENT
;; frame's chunk, ip and base ride in the arguments; only enclosing frames are a vector.
(:wat::core::defn :loxv::run-loop [c <- :loxv::Chunk ip <- :wat::core::i64 base <- :wat::core::i64
                                   frames <- (:wat::core::Vector :- [:loxv::Saved])
                                   s <- :loxv::Stack g <- :loxv::Globals out <- :loxv::Output
                                   steps <- :wat::core::i64] -> :loxv::Out
  (:wat::core::if (:wat::core::>= ip (:loxv::count c))
    (:loxv::Out.Ok {:stack s :globals g :out out :steps steps})
    (:wat::core::let [op (:wat::core::nth (:loxv::Chunk/code c) ip)]
      (:wat::core::match (:loxv::exec op c s g out ip base)
        [:loxv::Step.Fail {:msg m}
          (:loxv::Out.Err {:msg m :line (:wat::core::nth (:loxv::Chunk/lines c) ip)
                           :out out :steps (:wat::core::+ steps 1)})]
        [:loxv::Step.Jump {:s s2 :g g2 :out o2 :target t}
          (:loxv::run-loop c t base frames s2 g2 o2 (:wat::core::+ steps 1))]
        ;; a call pushes the RETURN address and starts the callee at ip 0. `base` is the first
        ;; argument, so the callee itself sits at base-1 and is discarded on return.
        [:loxv::Step.Call {:s s2 :g g2 :out o2 :argc n :chunk fc}
          (:wat::core::if (:wat::core::> (:wat::core::length frames) 200)
            (:loxv::Out.Err {:msg "Stack overflow." :line (:wat::core::nth (:loxv::Chunk/lines c) ip)
                             :out o2 :steps (:wat::core::+ steps 1)})
            (:loxv::run-loop fc 0 (:wat::core::- (:wat::core::length s2) n)
              (:wat::core::conj frames (:loxv::Saved :chunk c :ip (:wat::core::+ ip 1) :base base))
              s2 g2 o2 (:wat::core::+ steps 1)))]
        [:loxv::Step.Ret {:s s2 :g g2 :out o2}
          (:wat::core::if (:wat::core::= (:wat::core::length frames) 0)
            (:loxv::Out.Ok {:stack s2 :globals g2 :out o2 :steps (:wat::core::+ steps 1)})
            (:wat::core::let
              [result (:wat::core::if (:wat::core::= (:wat::core::length s2) 0) (:loxv::Val.Nil {})
                        (:loxv::peek-n s2 0))
               f (:wat::core::nth frames (:wat::core::- (:wat::core::length frames) 1))
               fr2 (:loxv::frames-take frames (:wat::core::- (:wat::core::length frames) 1) 0
                     (:wat::core::Vector :- [:loxv::Saved]))
               ;; discard the whole frame -- arguments and the callee -- and leave the result
               s3 (:wat::core::conj
                    (:loxv::take-k s2 (:wat::core::- base 1) 0 (:wat::core::Vector :- [:loxv::Val]))
                    result)]
              (:loxv::run-loop (:loxv::Saved/chunk f) (:loxv::Saved/ip f) (:loxv::Saved/base f)
                fr2 s3 g2 o2 (:wat::core::+ steps 1))))]
        [:loxv::Step.Next {:s s2 :g g2 :out o2}
          (:loxv::run-loop c (:wat::core::+ ip 1) base frames s2 g2 o2 (:wat::core::+ steps 1))]))))

;; F-019, met in the ordinary course of writing this: `(:loxv::Val.Native {…})` inline has type
;; `:loxv::Val.Native`, not `:loxv::Val`, so `assoc` into a `HashMap<String, Val>` is refused --
;; *"parameter #3 expects :loxv::Val; got :loxv::Val.Native"*. A helper whose declared RETURN type
;; is the enum widens it, which is that finding's own recorded route (P-006).
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

(:wat::core::defn :loxv::run [c <- :loxv::Chunk] -> :loxv::Out
  (:loxv::run-loop c 0 0 (:wat::core::Vector :- [:loxv::Saved])
    (:wat::core::Vector :- [:loxv::Val]) (:loxv::base-globals)
    (:wat::core::Vector :- [:wat::core::String]) 0))
