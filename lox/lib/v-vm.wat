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

(:wat::core::defenum :loxv::Step :wat::enum::Pure
  :Next [s <- :loxv::Stack]
  :Fail [msg <- :wat::core::String])

(:wat::core::defenum :loxv::Out :wat::enum::Pure
  :Ok  [stack <- :loxv::Stack  steps <- :wat::core::i64]
  :Err [msg <- :wat::core::String  line <- :wat::core::i64  steps <- :wat::core::i64])

;; F-104 and F-088 again: no positional update, and `take` answers a Stream, so a pop rebuilds.
(:wat::core::defn :loxv::take-k [s <- :loxv::Stack k <- :wat::core::i64 i <- :wat::core::i64
                                 acc <- :loxv::Stack] -> :loxv::Stack
  (:wat::core::if (:wat::core::>= i k) acc
    (:loxv::take-k s k (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth s i)))))

(:wat::core::defn :loxv::pop-n [s <- :loxv::Stack n <- :wat::core::i64] -> :loxv::Stack
  (:loxv::take-k s (:wat::core::- (:wat::core::length s) n) 0 (:wat::core::Vector :- [:loxv::Val])))

(:wat::core::defn :loxv::peek-n [s <- :loxv::Stack n <- :wat::core::i64] -> :loxv::Val
  (:wat::core::nth s (:wat::core::- (:wat::core::length s) (:wat::core::+ n 1))))

(:wat::core::defn :loxv::num [x <- :wat::core::f64] -> :loxv::Val (:loxv::Val.Num {:n x}))
(:wat::core::defn :loxv::str [x <- :wat::core::String] -> :loxv::Val (:loxv::Val.Str {:s x}))
(:wat::core::defn :loxv::bool [x <- :wat::core::bool] -> :loxv::Val (:loxv::Val.Bool {:b x}))

;; a binary operator over two numbers, or Nystrom's "Operands must be numbers."
(:wat::core::defn :loxv::binary-num [s <- :loxv::Stack which <- :wat::core::String] -> :loxv::Step
  (:wat::core::if (:wat::core::< (:wat::core::length s) 2) (:loxv::Step.Fail {:msg "Stack underflow."})
    (:wat::core::let [b (:loxv::peek-n s 0)
                      a (:loxv::peek-n s 1)
                      rest (:loxv::pop-n s 2)]
      (:wat::core::if (:wat::core::not (:wat::core::and (:loxv::num? a) (:loxv::num? b)))
        (:loxv::Step.Fail {:msg "Operands must be numbers."})
        (:wat::core::let [x (:loxv::as-num a) y (:loxv::as-num b)]
          (:loxv::Step.Next {:s (:wat::core::conj rest
            (:wat::core::cond
              ((:wat::core::= which "+") (:loxv::num (:wat::core::+ x y)))
              ((:wat::core::= which "-") (:loxv::num (:wat::core::- x y)))
              ((:wat::core::= which "*") (:loxv::num (:wat::core::* x y)))
              ((:wat::core::= which "/") (:loxv::num (:wat::core::/ x y)))
              ((:wat::core::= which ">") (:loxv::bool (:wat::core::> x y)))
              (:else (:loxv::bool (:wat::core::< x y)))))})))))) 

(:wat::core::defn :loxv::op-add [s <- :loxv::Stack] -> :loxv::Step
  (:wat::core::if (:wat::core::< (:wat::core::length s) 2) (:loxv::Step.Fail {:msg "Stack underflow."})
    (:wat::core::let [b (:loxv::peek-n s 0)
                      a (:loxv::peek-n s 1)
                      rest (:loxv::pop-n s 2)]
      (:wat::core::cond
        ((:wat::core::and (:loxv::num? a) (:loxv::num? b))
          (:loxv::Step.Next {:s (:wat::core::conj rest
            (:loxv::num (:wat::core::+ (:loxv::as-num a) (:loxv::as-num b))))}))
        ;; concatenate(). In C this allocates, copies both halves and takes ownership; here it is
        ;; `:wat::string::concat` and the result is just another value.
        ((:wat::core::and (:loxv::str? a) (:loxv::str? b))
          (:loxv::Step.Next {:s (:wat::core::conj rest
            (:loxv::str (:wat::string::concat (:loxv::as-str a) (:loxv::as-str b))))}))
        (:else (:loxv::Step.Fail {:msg "Operands must be two numbers or two strings."}))))))

(:wat::core::defn :loxv::exec [op <- :loxv::Op c <- :loxv::Chunk s <- :loxv::Stack] -> :loxv::Step
  (:wat::core::match op
    [:loxv::Op.Constant {:slot i}
      (:loxv::Step.Next {:s (:wat::core::conj s (:wat::core::nth (:loxv::Chunk/constants c) i))})]
    [:loxv::Op.Nil {} (:loxv::Step.Next {:s (:wat::core::conj s (:loxv::Val.Nil {}))})]
    [:loxv::Op.True {} (:loxv::Step.Next {:s (:wat::core::conj s (:loxv::bool true))})]
    [:loxv::Op.False {} (:loxv::Step.Next {:s (:wat::core::conj s (:loxv::bool false))})]
    ;; == compares ANY two values; only the comparisons demand numbers
    [:loxv::Op.Equal {}
      (:wat::core::if (:wat::core::< (:wat::core::length s) 2) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:loxv::Step.Next {:s (:wat::core::conj (:loxv::pop-n s 2)
          (:loxv::bool (:loxv::equal? (:loxv::peek-n s 1) (:loxv::peek-n s 0))))}))]
    [:loxv::Op.Greater {} (:loxv::binary-num s ">")]
    [:loxv::Op.Less {} (:loxv::binary-num s "<")]
    ;; chapter 19: `+` is the one operator that is overloaded, so it does its own operand check.
    ;; Nystrom's message changes here too, from "Operands must be numbers." to the longer one.
    [:loxv::Op.Add {} (:loxv::op-add s)]
    [:loxv::Op.Subtract {} (:loxv::binary-num s "-")]
    [:loxv::Op.Multiply {} (:loxv::binary-num s "*")]
    [:loxv::Op.Divide {} (:loxv::binary-num s "/")]
    ;; `!` accepts anything -- falsey? is total
    [:loxv::Op.Not {}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:loxv::Step.Next {:s (:wat::core::conj (:loxv::pop-n s 1)
          (:loxv::bool (:loxv::falsey? (:loxv::peek-n s 0))))}))]
    [:loxv::Op.Negate {}
      (:wat::core::if (:wat::core::= (:wat::core::length s) 0) (:loxv::Step.Fail {:msg "Stack underflow."})
        (:wat::core::if (:wat::core::not (:loxv::num? (:loxv::peek-n s 0)))
          (:loxv::Step.Fail {:msg "Operand must be a number."})
          (:loxv::Step.Next {:s (:wat::core::conj (:loxv::pop-n s 1)
            (:loxv::num (:wat::core::- 0.0 (:loxv::as-num (:loxv::peek-n s 0)))))})))]
    [:loxv::Op.Return {} (:loxv::Step.Next {:s s})]))

(:wat::core::defn :loxv::halts? [op <- :loxv::Op] -> :wat::core::bool
  (:wat::core::match op
    [:loxv::Op.Return {} true]
    [:loxv::Op.Constant {:slot i} false] [:loxv::Op.Nil {} false] [:loxv::Op.True {} false]
    [:loxv::Op.False {} false] [:loxv::Op.Equal {} false] [:loxv::Op.Greater {} false]
    [:loxv::Op.Less {} false] [:loxv::Op.Add {} false] [:loxv::Op.Subtract {} false]
    [:loxv::Op.Multiply {} false] [:loxv::Op.Divide {} false] [:loxv::Op.Not {} false]
    [:loxv::Op.Negate {} false]))

;; the threaded loop -- C-098's cheaper shape, chosen on that chapter's evidence
(:wat::core::defn :loxv::run-loop [c <- :loxv::Chunk ip <- :wat::core::i64 s <- :loxv::Stack
                                   steps <- :wat::core::i64] -> :loxv::Out
  (:wat::core::if (:wat::core::>= ip (:loxv::count c)) (:loxv::Out.Ok {:stack s :steps steps})
    (:wat::core::let [op (:wat::core::nth (:loxv::Chunk/code c) ip)]
      (:wat::core::if (:loxv::halts? op)
        (:loxv::Out.Ok {:stack s :steps (:wat::core::+ steps 1)})
        (:wat::core::match (:loxv::exec op c s)
          [:loxv::Step.Fail {:msg m}
            (:loxv::Out.Err {:msg m :line (:wat::core::nth (:loxv::Chunk/lines c) ip)
                             :steps (:wat::core::+ steps 1)})]
          [:loxv::Step.Next {:s s2}
            (:loxv::run-loop c (:wat::core::+ ip 1) s2 (:wat::core::+ steps 1))])))))

(:wat::core::defn :loxv::run [c <- :loxv::Chunk] -> :loxv::Out
  (:loxv::run-loop c 0 (:wat::core::Vector :- [:loxv::Val]) 0))
