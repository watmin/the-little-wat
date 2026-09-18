;; lox/lib/v-compiler.wat — chapter 18's compiler: literals, `!`, equality and comparison.
;;
;; The same Pratt parser as chapter 17, with four prefix rules added (`nil`, `true`, `false`,
;; `!`) and six infix ones. Nystrom's trick for three of the six is worth naming because it is a
;; deliberate, documented inaccuracy: there is no OP_NOT_EQUAL, OP_LESS_EQUAL or
;; OP_GREATER_EQUAL. `a != b` compiles as `a == b` then `!`, `a <= b` as `a > b` then `!`, and
;; `a >= b` as `a < b` then `!`. He says so, and says it is wrong under IEEE 754, because NaN is
;; not less than, equal to or greater than anything -- so `NaN <= NaN` is false by IEEE and TRUE
;; under the desugaring. `lox/ch18-types-of-values.wat` checks that it is, rather than taking his
;; word for it; wat's f64 is IEEE (`0.0/0.0` is NaN and `NaN > NaN` is false), so the bug ports.

(:wat::load-file! "v-vm.wat")
(:wat::load-file! "prec.wat")

;; chapter 22. A local is a name and the scope depth it was declared at; its SLOT is its index in
;; this vector, which is also its index on the running stack. `depth` -1 means "declared but not
;; yet initialized", which is what makes `var a = a;` an error rather than a read of nil.
(:wat::core::defrecord :loxv::Local [name <- :wat::core::String  depth <- :wat::core::i64])

(:wat::core::defrecord :loxv::C
  [src <- :wat::core::String  n <- :wat::core::i64  i <- :wat::core::i64  line <- :wat::core::i64
   cur <- :lox::Token  prev <- :lox::Token
   chunk <- :loxv::Chunk
   errs <- (:wat::core::Vector :- [:wat::core::String])
   panic <- :wat::core::bool
   locals <- (:wat::core::Vector :- [:loxv::Local])
   depth <- :wat::core::i64])

;; F-104 again, this time in the COMPILER: marking a local initialized changes the depth of the
;; LAST element of a vector, and there is no positional update, so the vector is rebuilt.
(:wat::core::defn :loxv::locals-set [v <- (:wat::core::Vector :- [:loxv::Local])
                                     i <- :wat::core::i64 x <- :loxv::Local
                                     j <- :wat::core::i64
                                     acc <- (:wat::core::Vector :- [:loxv::Local])]
  -> (:wat::core::Vector :- [:loxv::Local])
  (:wat::core::if (:wat::core::>= j (:wat::core::length v)) acc
    (:loxv::locals-set v i x (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= j i) x (:wat::core::nth v j))))))

;; and dropping the locals a scope owned is the same rebuild from the other end
(:wat::core::defn :loxv::locals-take [v <- (:wat::core::Vector :- [:loxv::Local]) k <- :wat::core::i64
                                      j <- :wat::core::i64
                                      acc <- (:wat::core::Vector :- [:loxv::Local])]
  -> (:wat::core::Vector :- [:loxv::Local])
  (:wat::core::if (:wat::core::>= j k) acc
    (:loxv::locals-take v k (:wat::core::+ j 1) (:wat::core::conj acc (:wat::core::nth v j)))))

(:wat::core::defn :loxv::c-error [p <- :loxv::C msg <- :wat::core::String] -> :loxv::C
  (:wat::core::if (:loxv::C/panic p) p
    (:wat::core::assoc (:wat::core::assoc p :panic true)
      :errs (:wat::core::conj (:loxv::C/errs p)
              (:wat::string::concat "[line " (:wat::i64::to-string (:lox::Token/line (:loxv::C/cur p)))
                "] Error: " msg)))))

(:wat::core::defn :loxv::c-advance [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [r (:lox::flat-scan-token (:loxv::C/src p) (:loxv::C/n p) (:loxv::C/i p) (:loxv::C/line p))
                    t (:lox::Flat/tok r)
                    a (:wat::core::assoc p :prev (:loxv::C/cur p))
                    b (:wat::core::assoc a :cur t)
                    c (:wat::core::assoc b :i (:lox::Flat/next r))
                    d (:wat::core::assoc c :line (:lox::Flat/line r))]
    (:wat::core::if (:lox::kind-is? t "ERROR")
      (:loxv::c-advance (:loxv::c-error d (:lox::Token/text t)))
      d)))

(:wat::core::defn :loxv::c-consume [p <- :loxv::C name <- :wat::core::String msg <- :wat::core::String] -> :loxv::C
  (:wat::core::if (:lox::kind-is? (:loxv::C/cur p) name) (:loxv::c-advance p)
    (:loxv::c-error p msg)))

(:wat::core::defn :loxv::c-emit [p <- :loxv::C op <- :loxv::Op] -> :loxv::C
  (:wat::core::assoc p :chunk (:loxv::write (:loxv::C/chunk p) op (:lox::Token/line (:loxv::C/prev p)))))

(:wat::core::defn :loxv::c-emit2 [p <- :loxv::C a <- :loxv::Op b <- :loxv::Op] -> :loxv::C
  (:loxv::c-emit (:loxv::c-emit p a) b))

(:wat::core::defn :loxv::c-constant [p <- :loxv::C v <- :loxv::Val] -> :loxv::C
  (:wat::core::let [ch (:loxv::add-constant (:loxv::C/chunk p) v)
                    p1 (:wat::core::assoc p :chunk ch)]
    (:loxv::c-emit p1 (:loxv::Op.Constant {:slot (:loxv::constant-slot ch)}))))

(:wat::core::defn :loxv::infix-prec [name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= name "PLUS") (:lox::PREC-TERM))
    ((:wat::core::= name "MINUS") (:lox::PREC-TERM))
    ((:wat::core::= name "STAR") (:lox::PREC-FACTOR))
    ((:wat::core::= name "SLASH") (:lox::PREC-FACTOR))
    ((:wat::core::= name "BANG_EQUAL") (:lox::PREC-EQUALITY))
    ((:wat::core::= name "EQUAL_EQUAL") (:lox::PREC-EQUALITY))
    ((:wat::core::= name "GREATER") (:lox::PREC-COMPARISON))
    ((:wat::core::= name "GREATER_EQUAL") (:lox::PREC-COMPARISON))
    ((:wat::core::= name "LESS") (:lox::PREC-COMPARISON))
    ((:wat::core::= name "LESS_EQUAL") (:lox::PREC-COMPARISON))
    (:else (:lox::PREC-NONE))))

(:wat::core::defn :loxv::expression [p <- :loxv::C] -> :loxv::C
  (:loxv::parse-prec p (:lox::PREC-ASSIGNMENT)))

;; chapter 21's `canAssign`. A prefix rule may only consume a following `=` when it was reached
;; at or below assignment precedence -- which is what makes `a * b = c` a compile error instead
;; of silently parsing as `a * (b = c)`. Nystrom calls this out as the subtlest bug in the
;; chapter; ch21 checks it.
(:wat::core::defn :loxv::parse-prec [p <- :loxv::C prec <- :wat::core::i64] -> :loxv::C
  (:wat::core::let [can-assign (:wat::core::<= prec (:lox::PREC-ASSIGNMENT))
                    p1 (:loxv::infix-loop (:loxv::c-prefix (:loxv::c-advance p) can-assign) prec)]
    ;; if an `=` is still sitting there, nothing was allowed to take it
    (:wat::core::if (:wat::core::and can-assign (:lox::kind-is? (:loxv::C/cur p1) "EQUAL"))
      (:loxv::c-error p1 "Invalid assignment target.")
      p1)))

(:wat::core::defn :loxv::infix-loop [p <- :loxv::C prec <- :wat::core::i64] -> :loxv::C
  (:wat::core::if (:wat::core::<= prec (:loxv::infix-prec (:lox::tok-name (:lox::Token/kind (:loxv::C/cur p)))))
    (:loxv::infix-loop (:loxv::c-infix (:loxv::c-advance p)) prec)
    p))

(:wat::core::defn :loxv::c-prefix [p <- :loxv::C can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::let [k (:lox::tok-name (:lox::Token/kind (:loxv::C/prev p)))]
    (:wat::core::cond
      ((:wat::core::= k "NUMBER")
        (:wat::core::match (:wat::string::to-f64 (:lox::Token/text (:loxv::C/prev p)))
          [:wat::core::Option.Some {:value v} (:loxv::c-constant p (:loxv::num v))]
          [:wat::core::Option.None {} (:loxv::c-error p "Not a number.")]))
      ;; the literals do not go in the constant pool -- they get their own opcodes, which is
      ;; Nystrom's point about why a tagged union earns dedicated instructions
      ;; chapter 19: the scanner's lexeme still has its quotes, so the literal drops them --
      ;; Nystrom's `copyString(start + 1, length - 2)`. Lox has no escape sequences, which he
      ;; notes as a deliberate omission, so there is nothing else to do.
      ((:wat::core::= k "STRING")
        (:wat::core::let [lex (:lox::Token/text (:loxv::C/prev p))]
          (:loxv::c-constant p
            (:loxv::str (:wat::string::subs lex 1 (:wat::core::- (:wat::string::length lex) 1))))))
      ((:wat::core::= k "IDENTIFIER") (:loxv::named-variable p can-assign))
      ((:wat::core::= k "NIL") (:loxv::c-emit p (:loxv::Op.Nil {})))
      ((:wat::core::= k "TRUE") (:loxv::c-emit p (:loxv::Op.True {})))
      ((:wat::core::= k "FALSE") (:loxv::c-emit p (:loxv::Op.False {})))
      ((:wat::core::= k "LEFT_PAREN")
        (:loxv::c-consume (:loxv::expression p) "RIGHT_PAREN" "Expect ')' after expression."))
      ((:wat::core::= k "MINUS")
        (:loxv::c-emit (:loxv::parse-prec p (:lox::PREC-UNARY)) (:loxv::Op.Negate {})))
      ((:wat::core::= k "BANG")
        (:loxv::c-emit (:loxv::parse-prec p (:lox::PREC-UNARY)) (:loxv::Op.Not {})))
      (:else (:loxv::c-error p "Expect expression.")))))

(:wat::core::defn :loxv::c-infix [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [k (:lox::tok-name (:lox::Token/kind (:loxv::C/prev p)))
                    p1 (:loxv::parse-prec p (:wat::core::+ (:loxv::infix-prec k) 1))]
    (:wat::core::cond
      ((:wat::core::= k "PLUS") (:loxv::c-emit p1 (:loxv::Op.Add {})))
      ((:wat::core::= k "MINUS") (:loxv::c-emit p1 (:loxv::Op.Subtract {})))
      ((:wat::core::= k "STAR") (:loxv::c-emit p1 (:loxv::Op.Multiply {})))
      ((:wat::core::= k "SLASH") (:loxv::c-emit p1 (:loxv::Op.Divide {})))
      ((:wat::core::= k "EQUAL_EQUAL") (:loxv::c-emit p1 (:loxv::Op.Equal {})))
      ((:wat::core::= k "GREATER") (:loxv::c-emit p1 (:loxv::Op.Greater {})))
      ((:wat::core::= k "LESS") (:loxv::c-emit p1 (:loxv::Op.Less {})))
      ;; the three that have no opcode of their own
      ((:wat::core::= k "BANG_EQUAL") (:loxv::c-emit2 p1 (:loxv::Op.Equal {}) (:loxv::Op.Not {})))
      ((:wat::core::= k "GREATER_EQUAL") (:loxv::c-emit2 p1 (:loxv::Op.Less {}) (:loxv::Op.Not {})))
      ((:wat::core::= k "LESS_EQUAL") (:loxv::c-emit2 p1 (:loxv::Op.Greater {}) (:loxv::Op.Not {})))
      (:else (:loxv::c-error p1 "Expect an operator.")))))

;; ---- chapter 22: scopes and locals
(:wat::core::defn :loxv::begin-scope [p <- :loxv::C] -> :loxv::C
  (:wat::core::assoc p :depth (:wat::core::+ (:loxv::C/depth p) 1)))

;; how many locals belong to scopes deeper than `d`
(:wat::core::defn :loxv::count-above [v <- (:wat::core::Vector :- [:loxv::Local]) d <- :wat::core::i64
                                      i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< i 0) acc
    (:wat::core::if (:wat::core::> (:loxv::Local/depth (:wat::core::nth v i)) d)
      (:loxv::count-above v d (:wat::core::- i 1) (:wat::core::+ acc 1))
      acc)))

(:wat::core::defn :loxv::emit-pops [p <- :loxv::C k <- :wat::core::i64] -> :loxv::C
  (:wat::core::if (:wat::core::= k 0) p
    (:loxv::emit-pops (:loxv::c-emit p (:loxv::Op.Pop {})) (:wat::core::- k 1))))

;; leaving a scope pops every local it owned -- one instruction each, which is why Nystrom notes
;; that a `for` loop body's locals cost two instructions per iteration
(:wat::core::defn :loxv::end-scope [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [d (:wat::core::- (:loxv::C/depth p) 1)
                    v (:loxv::C/locals p)
                    k (:loxv::count-above v d (:wat::core::- (:wat::core::length v) 1) 0)
                    p1 (:loxv::emit-pops p k)]
    (:wat::core::assoc (:wat::core::assoc p1 :depth d)
      :locals (:loxv::locals-take v (:wat::core::- (:wat::core::length v) k) 0
                (:wat::core::Vector :- [:loxv::Local])))))

;; resolveLocal: the INNERMOST declaration of `name`, or -1 for "not a local, try the globals"
(:wat::core::defn :loxv::resolve-local [v <- (:wat::core::Vector :- [:loxv::Local])
                                        name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::< i 0) -1)
    ((:wat::core::= (:loxv::Local/name (:wat::core::nth v i)) name) i)
    (:else (:loxv::resolve-local v name (:wat::core::- i 1)))))

;; is `name` already declared at exactly this depth? Shadowing an OUTER scope is legal; two
;; declarations in the SAME scope are not.
(:wat::core::defn :loxv::declared-here? [v <- (:wat::core::Vector :- [:loxv::Local])
                                         name <- :wat::core::String d <- :wat::core::i64
                                         i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::< i 0) false)
    ((:wat::core::< (:loxv::Local/depth (:wat::core::nth v i)) d) false)
    ((:wat::core::= (:loxv::Local/name (:wat::core::nth v i)) name) true)
    (:else (:loxv::declared-here? v name d (:wat::core::- i 1)))))

(:wat::core::defn :loxv::declare-variable [p <- :loxv::C name <- :wat::core::String] -> :loxv::C
  (:wat::core::if (:wat::core::= (:loxv::C/depth p) 0) p
    (:wat::core::if (:loxv::declared-here? (:loxv::C/locals p) name (:loxv::C/depth p)
                      (:wat::core::- (:wat::core::length (:loxv::C/locals p)) 1))
      (:loxv::c-error p "Already a variable with this name in this scope.")
      ;; depth -1: DECLARED, not yet initialized
      (:wat::core::assoc p :locals
        (:wat::core::conj (:loxv::C/locals p) (:loxv::Local :name name :depth -1))))))

(:wat::core::defn :loxv::mark-initialized [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [v (:loxv::C/locals p) n (:wat::core::length v)]
    (:wat::core::if (:wat::core::= n 0) p
      (:wat::core::assoc p :locals
        (:loxv::locals-set v (:wat::core::- n 1)
          (:loxv::Local :name (:loxv::Local/name (:wat::core::nth v (:wat::core::- n 1)))
                        :depth (:loxv::C/depth p))
          0 (:wat::core::Vector :- [:loxv::Local]))))))

;; ---- chapter 21: names, statements and declarations
;; identifierConstant(): the variable's NAME goes in the constant pool, and the instruction
;; carries its slot. Two calls rather than one, because a wat function answers one value.
(:wat::core::defn :loxv::add-name [p <- :loxv::C name <- :wat::core::String] -> :loxv::C
  (:wat::core::assoc p :chunk (:loxv::add-constant (:loxv::C/chunk p) (:loxv::str name))))

(:wat::core::defn :loxv::last-slot [p <- :loxv::C] -> :wat::core::i64
  (:loxv::constant-slot (:loxv::C/chunk p)))

(:wat::core::defn :loxv::global-variable [p <- :loxv::C name <- :wat::core::String
                                          can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::let [p1 (:loxv::add-name p name)
                    slot (:loxv::last-slot p1)]
    (:wat::core::if (:wat::core::and can-assign (:lox::kind-is? (:loxv::C/cur p1) "EQUAL"))
      (:loxv::c-emit (:loxv::expression (:loxv::c-advance p1)) (:loxv::Op.SetGlobal {:slot slot}))
      (:loxv::c-emit p1 (:loxv::Op.GetGlobal {:slot slot})))))

(:wat::core::defn :loxv::local-variable [p <- :loxv::C slot <- :wat::core::i64
                                         can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::if (:wat::core::and can-assign (:lox::kind-is? (:loxv::C/cur p) "EQUAL"))
    (:loxv::c-emit (:loxv::expression (:loxv::c-advance p)) (:loxv::Op.SetLocal {:slot slot}))
    (:loxv::c-emit p (:loxv::Op.GetLocal {:slot slot}))))

;; a local shadows a global of the same name, and the compiler -- not the VM -- decides which
(:wat::core::defn :loxv::named-variable [p <- :loxv::C can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::let [name (:lox::Token/text (:loxv::C/prev p))
                    slot (:loxv::resolve-local (:loxv::C/locals p) name
                           (:wat::core::- (:wat::core::length (:loxv::C/locals p)) 1))]
    (:wat::core::cond
      ((:wat::core::= slot -1) (:loxv::global-variable p name can-assign))
      ;; declared but not yet initialized: `var a = a;` reads the local being defined
      ((:wat::core::= (:loxv::Local/depth (:wat::core::nth (:loxv::C/locals p) slot)) -1)
        (:loxv::c-error p "Can't read local variable in its own initializer."))
      (:else (:loxv::local-variable p slot can-assign)))))

(:wat::core::defn :loxv::print-stmt [p <- :loxv::C] -> :loxv::C
  (:loxv::c-emit
    (:loxv::c-consume (:loxv::expression p) "SEMICOLON" "Expect ';' after value.")
    (:loxv::Op.Print {})))

;; an expression statement evaluates and DISCARDS -- the Pop is the whole difference between it
;; and a print, and it is why `1 + 2;` leaves the stack as it found it
(:wat::core::defn :loxv::expr-stmt [p <- :loxv::C] -> :loxv::C
  (:loxv::c-emit
    (:loxv::c-consume (:loxv::expression p) "SEMICOLON" "Expect ';' after expression.")
    (:loxv::Op.Pop {})))

(:wat::core::defn :loxv::block-loop [p <- :loxv::C] -> :loxv::C
  (:wat::core::if (:wat::core::or (:lox::kind-is? (:loxv::C/cur p) "RIGHT_BRACE")
                                  (:lox::kind-is? (:loxv::C/cur p) "EOF")) p
    (:loxv::block-loop (:loxv::declaration p))))

(:wat::core::defn :loxv::block [p <- :loxv::C] -> :loxv::C
  (:loxv::c-consume (:loxv::block-loop p) "RIGHT_BRACE" "Expect '}' after block."))

(:wat::core::defn :loxv::statement [p <- :loxv::C] -> :loxv::C
  (:wat::core::cond
    ((:lox::kind-is? (:loxv::C/cur p) "PRINT") (:loxv::print-stmt (:loxv::c-advance p)))
    ((:lox::kind-is? (:loxv::C/cur p) "LEFT_BRACE")
      (:loxv::end-scope (:loxv::block (:loxv::begin-scope (:loxv::c-advance p)))))
    (:else (:loxv::expr-stmt p))))

;; defineVariable: a global gets an instruction and a name constant; a LOCAL gets neither -- its
;; initializer already left the value in the right stack slot, so all that remains is to mark it
;; initialized. Nystrom's "there is no code to create a local variable at runtime".
(:wat::core::defn :loxv::define-variable [p <- :loxv::C slot <- :wat::core::i64] -> :loxv::C
  (:wat::core::if (:wat::core::> (:loxv::C/depth p) 0) (:loxv::mark-initialized p)
    (:loxv::c-emit p (:loxv::Op.DefineGlobal {:slot slot}))))

(:wat::core::defn :loxv::var-decl [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [p1 (:loxv::c-consume p "IDENTIFIER" "Expect variable name.")
                    name (:lox::Token/text (:loxv::C/prev p1))
                    p2 (:loxv::declare-variable p1 name)
                    ;; only a global needs its name in the constant pool
                    p3 (:wat::core::if (:wat::core::= (:loxv::C/depth p2) 0) (:loxv::add-name p2 name) p2)
                    slot (:wat::core::if (:wat::core::= (:loxv::C/depth p2) 0) (:loxv::last-slot p3) 0)
                    ;; `var a;` is `var a = nil;` -- the initializer is optional and defaults
                    p4 (:wat::core::if (:lox::kind-is? (:loxv::C/cur p3) "EQUAL")
                         (:loxv::expression (:loxv::c-advance p3))
                         (:loxv::c-emit p3 (:loxv::Op.Nil {})))
                    p5 (:loxv::c-consume p4 "SEMICOLON" "Expect ';' after variable declaration.")]
    (:loxv::define-variable p5 slot)))

(:wat::core::defn :loxv::sync-start? [k <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= k "CLASS")
    (:wat::core::or (:wat::core::= k "FUN")
      (:wat::core::or (:wat::core::= k "VAR")
        (:wat::core::or (:wat::core::= k "FOR")
          (:wat::core::or (:wat::core::= k "IF")
            (:wat::core::or (:wat::core::= k "WHILE")
              (:wat::core::or (:wat::core::= k "PRINT") (:wat::core::= k "RETURN")))))))))

;; synchronize(): after an error, skip to something that looks like a statement boundary, so one
;; mistake reports once instead of cascading. This is what makes panic mode survivable.
(:wat::core::defn :loxv::sync-loop [p <- :loxv::C] -> :loxv::C
  (:wat::core::cond
    ((:lox::kind-is? (:loxv::C/cur p) "EOF") p)
    ((:lox::kind-is? (:loxv::C/prev p) "SEMICOLON") p)
    ((:loxv::sync-start? (:lox::tok-name (:lox::Token/kind (:loxv::C/cur p)))) p)
    (:else (:loxv::sync-loop (:loxv::c-advance p)))))

(:wat::core::defn :loxv::synchronize [p <- :loxv::C] -> :loxv::C
  (:loxv::sync-loop (:wat::core::assoc p :panic false)))

(:wat::core::defn :loxv::declaration [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [p1 (:wat::core::if (:lox::kind-is? (:loxv::C/cur p) "VAR")
                         (:loxv::var-decl (:loxv::c-advance p))
                         (:loxv::statement p))]
    (:wat::core::if (:loxv::C/panic p1) (:loxv::synchronize p1) p1)))

(:wat::core::defn :loxv::decl-loop [p <- :loxv::C] -> :loxv::C
  (:wat::core::if (:lox::kind-is? (:loxv::C/cur p) "EOF") p
    (:loxv::decl-loop (:loxv::declaration p))))

;; chapter 21 replaces the top level: a source is a sequence of declarations, not one expression.
;; `:loxv::compile` -- the expression grammar chapters 17 to 20 are written against -- is kept
;; beside it rather than replaced, so those chapters keep testing the thing they were written for.
(:wat::core::defn :loxv::compile-program [src <- :wat::core::String] -> :loxv::C
  (:wat::core::let
    [p0 (:loxv::C :src src :n (:wat::string::length src) :i 0 :line 1
                  :cur (:lox::blank-token) :prev (:lox::blank-token)
                  :chunk (:loxv::new-chunk)
                  :errs (:wat::core::Vector :- [:wat::core::String]) :panic false
                  :locals (:wat::core::Vector :- [:loxv::Local]) :depth 0)
     p1 (:loxv::c-advance p0)
     p2 (:loxv::decl-loop p1)]
    (:loxv::c-emit p2 (:loxv::Op.Return {}))))

;; run a program and answer what it PRINTED, one line per print, or the first error
(:wat::core::defn :loxv::run-program [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [p (:loxv::compile-program src)
                    es (:loxv::C/errs p)]
    (:wat::core::if (:wat::core::> (:wat::core::length es) 0) (:wat::core::nth es 0)
      (:wat::core::match (:loxv::run (:loxv::C/chunk p))
        [:loxv::Out.Err {:msg m :line l :out o :steps k}
          (:wat::string::concat "[line " (:wat::i64::to-string l) "] Runtime error: " m)]
        [:loxv::Out.Ok {:stack s :globals g :out o :steps k} (:wat::string::join "|" o)]))))

(:wat::core::defn :loxv::program-errors [src <- :wat::core::String] -> :wat::core::i64
  (:wat::core::length (:loxv::C/errs (:loxv::compile-program src))))

(:wat::core::defn :loxv::compile [src <- :wat::core::String] -> :loxv::C
  (:wat::core::let
    [p0 (:loxv::C :src src :n (:wat::string::length src) :i 0 :line 1
                  :cur (:lox::blank-token) :prev (:lox::blank-token)
                  :chunk (:loxv::new-chunk)
                  :errs (:wat::core::Vector :- [:wat::core::String]) :panic false
                  :locals (:wat::core::Vector :- [:loxv::Local]) :depth 0)
     p1 (:loxv::c-advance p0)
     p2 (:loxv::expression p1)
     p3 (:loxv::c-consume p2 "EOF" "Expect end of expression.")]
    (:loxv::c-emit p3 (:loxv::Op.Return {}))))

;; compile and run, rendering whatever comes back -- a value, a compile error, or a runtime one
(:wat::core::defn :loxv::interpret [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [p (:loxv::compile src)
                    es (:loxv::C/errs p)]
    (:wat::core::if (:wat::core::> (:wat::core::length es) 0) (:wat::core::nth es 0)
      (:wat::core::match (:loxv::run (:loxv::C/chunk p))
        [:loxv::Out.Err {:msg m :line l :out o :steps k}
          (:wat::string::concat "[line " (:wat::i64::to-string l) "] Runtime error: " m)]
        [:loxv::Out.Ok {:stack s :globals g :out o :steps k}
          (:wat::core::if (:wat::core::= (:wat::core::length s) 0) "(empty stack)"
            (:loxv::show (:wat::core::nth s (:wat::core::- (:wat::core::length s) 1))))]))))
