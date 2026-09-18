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
(:wat::core::defrecord :loxv::Local
  [name <- :wat::core::String  depth <- :wat::core::i64
   ;; chapter 25: set when an inner function captures this local, so the scope that owns it emits
   ;; CLOSE_UPVALUE instead of POP on the way out
   captured <- :wat::core::bool])

(:wat::core::defrecord :loxv::CFrame
  [chunk <- :loxv::Chunk  locals <- (:wat::core::Vector :- [:loxv::Local])  depth <- :wat::core::i64
   upvals <- (:wat::core::Vector :- [:loxv::UpDesc])  ftype <- :wat::core::String])

;; a resolution answers both the (possibly edited) compiler and an index
(:wat::core::defrecord :loxv::UpR [p <- :loxv::C  index <- :wat::core::i64])

;; a function's parser answers two things -- the compiler and the arity -- and a wat function
;; answers one, so they travel together
(:wat::core::defrecord :loxv::Params [p <- :loxv::C  arity <- :wat::core::i64])

(:wat::core::defrecord :loxv::C
  [src <- :wat::core::String  n <- :wat::core::i64  i <- :wat::core::i64  line <- :wat::core::i64
   cur <- :lox::Token  prev <- :lox::Token
   chunk <- :loxv::Chunk
   errs <- (:wat::core::Vector :- [:wat::core::String])
   panic <- :wat::core::bool
   locals <- (:wat::core::Vector :- [:loxv::Local])
   depth <- :wat::core::i64
   ;; chapter 24: the compilers a function declaration suspends. Nystrom links them with an
   ;; `enclosing` pointer; a vector of saved frames is the same thing without the pointer.
   cframes <- (:wat::core::Vector :- [:loxv::CFrame])
   ;; chapter 25: what the function being compiled captures
   upvals <- (:wat::core::Vector :- [:loxv::UpDesc])
   ;; chapters 24-28: "script", "function", "method" or "initializer". It decides whether local
   ;; slot 0 is reserved for `this`, and what a bare `return` means.
   ftype <- :wat::core::String
   ;; chapters 27-29: one entry per class being declared, true when it has a superclass. Nystrom
   ;; uses a linked list of ClassCompilers for exactly this.
   classes <- (:wat::core::Vector :- [:wat::core::bool])])

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
    ((:wat::core::= name "AND") (:lox::PREC-AND))
    ((:wat::core::= name "OR") (:lox::PREC-OR))
    ((:wat::core::= name "LEFT_PAREN") (:lox::PREC-CALL))
    ((:wat::core::= name "DOT") (:lox::PREC-CALL))
    (:else (:lox::PREC-NONE))))

(:wat::core::defn :loxv::expression [p <- :loxv::C] -> :loxv::C
  (:loxv::parse-prec p (:lox::PREC-ASSIGNMENT)))

;; chapter 21's `canAssign`. A prefix rule may only consume a following `=` when it was reached
;; at or below assignment precedence -- which is what makes `a * b = c` a compile error instead
;; of silently parsing as `a * (b = c)`. Nystrom calls this out as the subtlest bug in the
;; chapter; ch21 checks it.
(:wat::core::defn :loxv::parse-prec [p <- :loxv::C prec <- :wat::core::i64] -> :loxv::C
  (:wat::core::let [can-assign (:wat::core::<= prec (:lox::PREC-ASSIGNMENT))
                    p1 (:loxv::infix-loop (:loxv::c-prefix (:loxv::c-advance p) can-assign) prec can-assign)]
    ;; if an `=` is still sitting there, nothing was allowed to take it
    (:wat::core::if (:wat::core::and can-assign (:lox::kind-is? (:loxv::C/cur p1) "EQUAL"))
      (:loxv::c-error p1 "Invalid assignment target.")
      p1)))

(:wat::core::defn :loxv::infix-loop [p <- :loxv::C prec <- :wat::core::i64
                                     can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::if (:wat::core::<= prec (:loxv::infix-prec (:lox::tok-name (:lox::Token/kind (:loxv::C/cur p)))))
    (:loxv::infix-loop (:loxv::c-infix (:loxv::c-advance p) can-assign) prec can-assign)
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
      ;; `this` is local slot 0 of a method, or an upvalue in a function nested inside one --
      ;; which is why it needs no machinery of its own beyond refusing to exist outside a class
      ((:wat::core::= k "THIS")
        (:wat::core::if (:wat::core::= (:wat::core::length (:loxv::C/classes p)) 0)
          (:loxv::c-error p "Can't use 'this' outside of a class.")
          (:loxv::variable-named p "this" false)))
      ((:wat::core::= k "SUPER") (:loxv::super-expr p))
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

;; `and` short-circuits by jumping over its right operand and LEAVING the left one, which is why
;; `nil and 1` is nil rather than false. `or` does the same with the sense inverted, which it
;; spells as a jump over a jump -- Nystrom notes it would be one instruction with an
;; OP_JUMP_IF_TRUE, and that he keeps the instruction set small instead.
(:wat::core::defn :loxv::and-op [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [p1 (:loxv::c-emit p (:loxv::Op.JumpIfFalse {:offset 0}))
                    end (:wat::core::- (:loxv::ccount p1) 1)
                    p2 (:loxv::parse-prec (:loxv::c-emit p1 (:loxv::Op.Pop {})) (:lox::PREC-AND))]
    (:loxv::patch-jif p2 end)))

(:wat::core::defn :loxv::or-op [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [p1 (:loxv::c-emit p (:loxv::Op.JumpIfFalse {:offset 0}))
                    else-j (:wat::core::- (:loxv::ccount p1) 1)
                    p2 (:loxv::c-emit p1 (:loxv::Op.Jump {:offset 0}))
                    end-j (:wat::core::- (:loxv::ccount p2) 1)
                    p3 (:loxv::c-emit (:loxv::patch-jif p2 else-j) (:loxv::Op.Pop {}))
                    p4 (:loxv::parse-prec p3 (:lox::PREC-OR))]
    (:loxv::patch-jmp p4 end-j)))

(:wat::core::defn :loxv::c-infix [p <- :loxv::C can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::let [k0 (:lox::tok-name (:lox::Token/kind (:loxv::C/prev p)))]
    (:wat::core::cond
      ((:wat::core::= k0 "AND") (:loxv::and-op p))
      ((:wat::core::= k0 "OR") (:loxv::or-op p))
      ((:wat::core::= k0 "LEFT_PAREN") (:loxv::call-op p))
      ((:wat::core::= k0 "DOT") (:loxv::dot-op p can-assign))
      (:else (:loxv::c-infix-binary p)))))

;; `.` is an infix operator at the tightest precedence, which is what makes `a.b.c` and
;; `a.b(c).d` parse with no special case -- and `canAssign` is what makes `a.b = c` work while
;; `a.b + 1 = c` does not
(:wat::core::defn :loxv::dot-op [p <- :loxv::C can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::let [p1 (:loxv::c-consume p "IDENTIFIER" "Expect property name after '.'.")
                    p2 (:loxv::add-name p1 (:lox::Token/text (:loxv::C/prev p1)))
                    nslot (:loxv::last-slot p2)]
    (:wat::core::if (:wat::core::and can-assign (:lox::kind-is? (:loxv::C/cur p2) "EQUAL"))
      (:loxv::c-emit (:loxv::expression (:loxv::c-advance p2)) (:loxv::Op.SetProperty {:slot nslot}))
      (:loxv::c-emit p2 (:loxv::Op.GetProperty {:slot nslot})))))

;; `super.m` is two variable reads and one instruction: the receiver (`this`), the superclass
;; (a hidden local the class declaration created), and OP_GET_SUPER to bind one to the other.
;; Nystrom's point is that `super` is LEXICAL -- it is the enclosing class's superclass, not the
;; receiver's -- and the hidden local is what makes that true.
(:wat::core::defn :loxv::super-expr [p <- :loxv::C] -> :loxv::C
  (:wat::core::cond
    ((:wat::core::= (:wat::core::length (:loxv::C/classes p)) 0)
      (:loxv::c-error p "Can't use 'super' outside of a class."))
    ((:wat::core::not (:wat::core::nth (:loxv::C/classes p)
                        (:wat::core::- (:wat::core::length (:loxv::C/classes p)) 1)))
      (:loxv::c-error p "Can't use 'super' in a class with no superclass."))
    (:else
      (:wat::core::let [p1 (:loxv::c-consume p "DOT" "Expect '.' after 'super'.")
                        p2 (:loxv::c-consume p1 "IDENTIFIER" "Expect superclass method name.")
                        p3 (:loxv::add-name p2 (:lox::Token/text (:loxv::C/prev p2)))
                        nslot (:loxv::last-slot p3)
                        p4 (:loxv::variable-named p3 "this" false)
                        p5 (:loxv::variable-named p4 "super" false)]
        (:loxv::c-emit p5 (:loxv::Op.GetSuper {:slot nslot}))))))

(:wat::core::defn :loxv::c-infix-binary [p <- :loxv::C] -> :loxv::C
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

;; ---- chapter 24: functions
(:wat::core::defn :loxv::cframes-take [v <- (:wat::core::Vector :- [:loxv::CFrame]) k <- :wat::core::i64
                                       j <- :wat::core::i64
                                       acc <- (:wat::core::Vector :- [:loxv::CFrame])]
  -> (:wat::core::Vector :- [:loxv::CFrame])
  (:wat::core::if (:wat::core::>= j k) acc
    (:loxv::cframes-take v k (:wat::core::+ j 1) (:wat::core::conj acc (:wat::core::nth v j)))))

;; F-019 again: a bare `(:loxv::Val.Fn {…})` has the VARIANT's type, and the constant pool wants
;; the enum's. A helper whose declared return type is the enum widens it (P-006).
(:wat::core::defn :loxv::fnval [c <- :loxv::Chunk name <- :wat::core::String arity <- :wat::core::i64
                                ups <- (:wat::core::Vector :- [:loxv::UpDesc])] -> :loxv::Val
  (:loxv::Val.Fn {:chunk c :name name :arity arity :updescs ups}))

;; ---- chapter 25: resolving a name to an UPVALUE
;; Nystrom recurses through `enclosing` pointers and mutates each compiler on the way back down.
;; The levels here are a vector, so the same walk is an index and the mutations are rebuilds.
(:wat::core::defn :loxv::nlevels [p <- :loxv::C] -> :wat::core::i64
  (:wat::core::length (:loxv::C/cframes p)))

(:wat::core::defn :loxv::lvl-locals [p <- :loxv::C lv <- :wat::core::i64]
  -> (:wat::core::Vector :- [:loxv::Local])
  (:wat::core::if (:wat::core::= lv (:loxv::nlevels p)) (:loxv::C/locals p)
    (:loxv::CFrame/locals (:wat::core::nth (:loxv::C/cframes p) lv))))

(:wat::core::defn :loxv::lvl-upvals [p <- :loxv::C lv <- :wat::core::i64]
  -> (:wat::core::Vector :- [:loxv::UpDesc])
  (:wat::core::if (:wat::core::= lv (:loxv::nlevels p)) (:loxv::C/upvals p)
    (:loxv::CFrame/upvals (:wat::core::nth (:loxv::C/cframes p) lv))))

(:wat::core::defn :loxv::cframes-set [v <- (:wat::core::Vector :- [:loxv::CFrame]) i <- :wat::core::i64
                                      x <- :loxv::CFrame j <- :wat::core::i64
                                      acc <- (:wat::core::Vector :- [:loxv::CFrame])]
  -> (:wat::core::Vector :- [:loxv::CFrame])
  (:wat::core::if (:wat::core::>= j (:wat::core::length v)) acc
    (:loxv::cframes-set v i x (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= j i) x (:wat::core::nth v j))))))

(:wat::core::defn :loxv::set-lvl-locals [p <- :loxv::C lv <- :wat::core::i64
                                         v <- (:wat::core::Vector :- [:loxv::Local])] -> :loxv::C
  (:wat::core::if (:wat::core::= lv (:loxv::nlevels p)) (:wat::core::assoc p :locals v)
    (:wat::core::assoc p :cframes
      (:loxv::cframes-set (:loxv::C/cframes p) lv
        (:wat::core::assoc (:wat::core::nth (:loxv::C/cframes p) lv) :locals v) 0
        (:wat::core::Vector :- [:loxv::CFrame])))))

(:wat::core::defn :loxv::set-lvl-upvals [p <- :loxv::C lv <- :wat::core::i64
                                         v <- (:wat::core::Vector :- [:loxv::UpDesc])] -> :loxv::C
  (:wat::core::if (:wat::core::= lv (:loxv::nlevels p)) (:wat::core::assoc p :upvals v)
    (:wat::core::assoc p :cframes
      (:loxv::cframes-set (:loxv::C/cframes p) lv
        (:wat::core::assoc (:wat::core::nth (:loxv::C/cframes p) lv) :upvals v) 0
        (:wat::core::Vector :- [:loxv::CFrame])))))

(:wat::core::defn :loxv::mark-captured [p <- :loxv::C lv <- :wat::core::i64 idx <- :wat::core::i64] -> :loxv::C
  (:wat::core::let [ls (:loxv::lvl-locals p lv)]
    (:loxv::set-lvl-locals p lv
      (:loxv::locals-set ls idx (:wat::core::assoc (:wat::core::nth ls idx) :captured true) 0
        (:wat::core::Vector :- [:loxv::Local])))))

;; addUpvalue's de-duplication: the same capture asked for twice gets one slot
(:wat::core::defn :loxv::find-updesc [v <- (:wat::core::Vector :- [:loxv::UpDesc]) idx <- :wat::core::i64
                                      is-local <- :wat::core::bool i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length v)) -1)
    ((:wat::core::and (:wat::core::= (:loxv::UpDesc/index (:wat::core::nth v i)) idx)
                      (:wat::core::= (:loxv::UpDesc/is-local (:wat::core::nth v i)) is-local)) i)
    (:else (:loxv::find-updesc v idx is-local (:wat::core::+ i 1)))))

(:wat::core::defn :loxv::add-upvalue [p <- :loxv::C lv <- :wat::core::i64 index <- :wat::core::i64
                                      is-local <- :wat::core::bool] -> :loxv::UpR
  (:wat::core::let [v (:loxv::lvl-upvals p lv)
                    found (:loxv::find-updesc v index is-local 0)]
    (:wat::core::if (:wat::core::>= found 0) (:loxv::UpR :p p :index found)
      (:loxv::UpR :index (:wat::core::length v)
        :p (:loxv::set-lvl-upvals p lv
             (:wat::core::conj v (:loxv::UpDesc :index index :is-local is-local)))))))

(:wat::core::defn :loxv::resolve-up-at [p <- :loxv::C lv <- :wat::core::i64 name <- :wat::core::String] -> :loxv::UpR
  (:wat::core::if (:wat::core::= lv 0) (:loxv::UpR :p p :index -1)
    (:wat::core::let [enc (:wat::core::- lv 1)
                      ls (:loxv::lvl-locals p enc)
                      local (:loxv::resolve-local ls name (:wat::core::- (:wat::core::length ls) 1))]
      (:wat::core::if (:wat::core::>= local 0)
        (:loxv::add-upvalue (:loxv::mark-captured p enc local) lv local true)
        (:wat::core::let [r (:loxv::resolve-up-at p enc name)]
          (:wat::core::if (:wat::core::< (:loxv::UpR/index r) 0)
            (:loxv::UpR :p (:loxv::UpR/p r) :index -1)
            (:loxv::add-upvalue (:loxv::UpR/p r) lv (:loxv::UpR/index r) false)))))))

(:wat::core::defn :loxv::begin-function [p <- :loxv::C] -> :loxv::C
  (:wat::core::assoc (:wat::core::assoc
    (:wat::core::assoc
      (:wat::core::assoc
        (:wat::core::assoc p :cframes
          (:wat::core::conj (:loxv::C/cframes p)
            (:loxv::CFrame :chunk (:loxv::C/chunk p) :locals (:loxv::C/locals p)
                           :depth (:loxv::C/depth p) :upvals (:loxv::C/upvals p)
                           :ftype (:loxv::C/ftype p))))
        :chunk (:loxv::new-chunk))
      :locals (:wat::core::Vector :- [:loxv::Local]))
    :depth 0) :upvals (:wat::core::Vector :- [:loxv::UpDesc])))

;; endCompiler: finish the function's chunk with an implicit `return nil`, restore the enclosing
;; compiler, and emit the finished function as a CONSTANT of the enclosing chunk
(:wat::core::defn :loxv::end-function [p <- :loxv::C name <- :wat::core::String arity <- :wat::core::i64] -> :loxv::C
  (:wat::core::let
    ;; an initializer returns `this` implicitly, which is what makes `Foo()` answer the instance
     ;; rather than nil even when the body says nothing
     [p1 (:wat::core::if (:wat::core::= (:loxv::C/ftype p) "initializer")
           (:loxv::c-emit (:loxv::c-emit p (:loxv::Op.GetLocal {:slot 0})) (:loxv::Op.Return {}))
           (:loxv::c-emit (:loxv::c-emit p (:loxv::Op.Nil {})) (:loxv::Op.Return {})))
     fn (:loxv::fnval (:loxv::C/chunk p1) name arity (:loxv::C/upvals p1))
     n (:wat::core::length (:loxv::C/cframes p1))
     f (:wat::core::nth (:loxv::C/cframes p1) (:wat::core::- n 1))
     p2 (:wat::core::assoc
          (:wat::core::assoc
            (:wat::core::assoc
              (:wat::core::assoc
                (:wat::core::assoc p1 :chunk (:loxv::CFrame/chunk f))
                :locals (:loxv::CFrame/locals f))
              :upvals (:loxv::CFrame/upvals f))
            :depth (:loxv::CFrame/depth f))
          :cframes (:loxv::cframes-take (:loxv::C/cframes p1) (:wat::core::- n 1) 0
                     (:wat::core::Vector :- [:loxv::CFrame])))
     p2b (:wat::core::assoc p2 :ftype (:loxv::CFrame/ftype f))]
    ;; OP_CLOSURE rather than OP_CONSTANT: the function is built at RUNTIME, out of the constant
    ;; and whatever its `updescs` say it captures
    (:wat::core::let [ch (:loxv::add-constant (:loxv::C/chunk p2b) fn)
                      p3 (:wat::core::assoc p2b :chunk ch)]
      (:loxv::c-emit p3 (:loxv::Op.Closure {:slot (:loxv::constant-slot ch)})))))

;; ---- chapter 23: jumps, and the patch F-104 has been waiting for
;;
;; Nystrom emits a jump with a PLACEHOLDER operand, remembers the offset, compiles the body, and
;; then writes the real distance back: `chunk->code[offset] = (jump >> 8) & 0xff;`. That is a
;; positional write into a vector, which wat does not have (F-104) -- so a patch here REBUILDS
;; the code array. `lox/ch23-jumping.wat` measures it: about seven microseconds per instruction
;; already emitted, so one patch is LINEAR in the program compiled so far and a program's patches
;; together are QUADRATIC in its length. (F-116's per-element clone is on top of that, and still
;; small at these sizes, so the curve gets worse rather than better.)
(:wat::core::defn :loxv::ccount [p <- :loxv::C] -> :wat::core::i64
  (:wat::core::length (:loxv::Chunk/code (:loxv::C/chunk p))))

(:wat::core::defn :loxv::code-set [v <- :loxv::Code i <- :wat::core::i64 x <- :loxv::Op
                                   j <- :wat::core::i64 acc <- :loxv::Code] -> :loxv::Code
  (:wat::core::if (:wat::core::>= j (:wat::core::length v)) acc
    (:loxv::code-set v i x (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= j i) x (:wat::core::nth v j))))))

(:wat::core::defn :loxv::patch-with [p <- :loxv::C idx <- :wat::core::i64 op <- :loxv::Op] -> :loxv::C
  (:wat::core::assoc p :chunk
    (:wat::core::assoc (:loxv::C/chunk p) :code
      (:loxv::code-set (:loxv::Chunk/code (:loxv::C/chunk p)) idx op 0
        (:wat::core::Vector :- [:loxv::Op])))))

;; patchJump: the distance from the instruction AFTER the jump to here
(:wat::core::defn :loxv::patch-jif [p <- :loxv::C idx <- :wat::core::i64] -> :loxv::C
  (:loxv::patch-with p idx
    (:loxv::Op.JumpIfFalse {:offset (:wat::core::- (:wat::core::- (:loxv::ccount p) idx) 1)})))

(:wat::core::defn :loxv::patch-jmp [p <- :loxv::C idx <- :wat::core::i64] -> :loxv::C
  (:loxv::patch-with p idx
    (:loxv::Op.Jump {:offset (:wat::core::- (:wat::core::- (:loxv::ccount p) idx) 1)})))

;; emitLoop: a BACKWARD jump, whose distance is known when it is written, so it needs no patch
(:wat::core::defn :loxv::emit-loop [p <- :loxv::C start <- :wat::core::i64] -> :loxv::C
  (:loxv::c-emit p (:loxv::Op.Loop {:offset (:wat::core::- (:wat::core::+ (:loxv::ccount p) 1) start)})))

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

;; a captured local leaves by CLOSE_UPVALUE, an uncaptured one by POP -- which is the only
;; visible difference between a variable an inner function took a reference to and one it did not
(:wat::core::defn :loxv::emit-pops [p <- :loxv::C v <- (:wat::core::Vector :- [:loxv::Local])
                                    i <- :wat::core::i64 k <- :wat::core::i64] -> :loxv::C
  (:wat::core::if (:wat::core::= k 0) p
    (:loxv::emit-pops
      (:loxv::c-emit p (:wat::core::if (:loxv::Local/captured (:wat::core::nth v i))
                         (:loxv::Op.CloseUpvalue {}) (:loxv::Op.Pop {})))
      v (:wat::core::- i 1) (:wat::core::- k 1))))

;; leaving a scope pops every local it owned -- one instruction each, which is why Nystrom notes
;; that a `for` loop body's locals cost two instructions per iteration
(:wat::core::defn :loxv::end-scope [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [d (:wat::core::- (:loxv::C/depth p) 1)
                    v (:loxv::C/locals p)
                    k (:loxv::count-above v d (:wat::core::- (:wat::core::length v) 1) 0)
                    p1 (:loxv::emit-pops p v (:wat::core::- (:wat::core::length v) 1) k)]
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
        (:wat::core::conj (:loxv::C/locals p) (:loxv::Local :name name :depth -1 :captured false))))))

(:wat::core::defn :loxv::mark-initialized [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [v (:loxv::C/locals p) n (:wat::core::length v)]
    (:wat::core::if (:wat::core::= n 0) p
      (:wat::core::assoc p :locals
        (:loxv::locals-set v (:wat::core::- n 1)
          (:wat::core::assoc (:wat::core::nth v (:wat::core::- n 1)) :depth (:loxv::C/depth p))
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

(:wat::core::defn :loxv::upvalue-variable [p <- :loxv::C slot <- :wat::core::i64
                                           can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::if (:wat::core::and can-assign (:lox::kind-is? (:loxv::C/cur p) "EQUAL"))
    (:loxv::c-emit (:loxv::expression (:loxv::c-advance p)) (:loxv::Op.SetUpvalue {:slot slot}))
    (:loxv::c-emit p (:loxv::Op.GetUpvalue {:slot slot}))))

(:wat::core::defn :loxv::local-variable [p <- :loxv::C slot <- :wat::core::i64
                                         can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::if (:wat::core::and can-assign (:lox::kind-is? (:loxv::C/cur p) "EQUAL"))
    (:loxv::c-emit (:loxv::expression (:loxv::c-advance p)) (:loxv::Op.SetLocal {:slot slot}))
    (:loxv::c-emit p (:loxv::Op.GetLocal {:slot slot}))))

;; a local shadows a global of the same name, and the compiler -- not the VM -- decides which
(:wat::core::defn :loxv::named-variable [p <- :loxv::C can-assign <- :wat::core::bool] -> :loxv::C
  (:loxv::variable-named p (:lox::Token/text (:loxv::C/prev p)) can-assign))

(:wat::core::defn :loxv::variable-named [p <- :loxv::C name <- :wat::core::String
                                         can-assign <- :wat::core::bool] -> :loxv::C
  (:wat::core::let [slot (:loxv::resolve-local (:loxv::C/locals p) name
                           (:wat::core::- (:wat::core::length (:loxv::C/locals p)) 1))]
    (:wat::core::cond
      ((:wat::core::= slot -1)
        (:wat::core::let [r (:loxv::resolve-up-at p (:loxv::nlevels p) name)]
          (:wat::core::if (:wat::core::>= (:loxv::UpR/index r) 0)
            (:loxv::upvalue-variable (:loxv::UpR/p r) (:loxv::UpR/index r) can-assign)
            (:loxv::global-variable (:loxv::UpR/p r) name can-assign))))
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

;; if-then-else. The two Pops are the condition being discarded on whichever path is taken;
;; JUMP_IF_FALSE peeks rather than pops so `and`/`or` can keep the value.
(:wat::core::defn :loxv::if-stmt [p <- :loxv::C] -> :loxv::C
  (:wat::core::let
    [p1 (:loxv::c-consume p "LEFT_PAREN" "Expect '(' after 'if'.")
     p2 (:loxv::c-consume (:loxv::expression p1) "RIGHT_PAREN" "Expect ')' after condition.")
     p3 (:loxv::c-emit p2 (:loxv::Op.JumpIfFalse {:offset 0}))
     then-j (:wat::core::- (:loxv::ccount p3) 1)
     p4 (:loxv::statement (:loxv::c-emit p3 (:loxv::Op.Pop {})))
     p5 (:loxv::c-emit p4 (:loxv::Op.Jump {:offset 0}))
     else-j (:wat::core::- (:loxv::ccount p5) 1)
     p6 (:loxv::c-emit (:loxv::patch-jif p5 then-j) (:loxv::Op.Pop {}))
     p7 (:wat::core::if (:lox::kind-is? (:loxv::C/cur p6) "ELSE")
          (:loxv::statement (:loxv::c-advance p6)) p6)]
    (:loxv::patch-jmp p7 else-j)))

(:wat::core::defn :loxv::while-stmt [p <- :loxv::C] -> :loxv::C
  (:wat::core::let
    [start (:loxv::ccount p)
     p1 (:loxv::c-consume p "LEFT_PAREN" "Expect '(' after 'while'.")
     p2 (:loxv::c-consume (:loxv::expression p1) "RIGHT_PAREN" "Expect ')' after condition.")
     p3 (:loxv::c-emit p2 (:loxv::Op.JumpIfFalse {:offset 0}))
     exit (:wat::core::- (:loxv::ccount p3) 1)
     p4 (:loxv::statement (:loxv::c-emit p3 (:loxv::Op.Pop {})))
     p5 (:loxv::emit-loop p4 start)]
    (:loxv::c-emit (:loxv::patch-jif p5 exit) (:loxv::Op.Pop {}))))

;; `for` is the chapter's set piece: desugared entirely in the compiler, with the increment
;; compiled BEFORE the body and jumped over, so it can run after the body without a second pass.
(:wat::core::defn :loxv::for-stmt [p <- :loxv::C] -> :loxv::C
  (:wat::core::let
    [p1 (:loxv::c-consume (:loxv::begin-scope p) "LEFT_PAREN" "Expect '(' after 'for'.")
     p2 (:wat::core::cond
          ((:lox::kind-is? (:loxv::C/cur p1) "SEMICOLON") (:loxv::c-advance p1))
          ((:lox::kind-is? (:loxv::C/cur p1) "VAR") (:loxv::var-decl (:loxv::c-advance p1)))
          (:else (:loxv::expr-stmt p1)))
     start0 (:loxv::ccount p2)
     has-cond (:wat::core::not (:lox::kind-is? (:loxv::C/cur p2) "SEMICOLON"))
     p3 (:wat::core::if has-cond
          (:loxv::c-emit
            (:loxv::c-emit (:loxv::c-consume (:loxv::expression p2) "SEMICOLON" "Expect ';' after loop condition.")
              (:loxv::Op.JumpIfFalse {:offset 0}))
            (:loxv::Op.Pop {}))
          (:loxv::c-advance p2))
     exit (:wat::core::if has-cond (:wat::core::- (:loxv::ccount p3) 2) -1)
     has-inc (:wat::core::not (:lox::kind-is? (:loxv::C/cur p3) "RIGHT_PAREN"))
     p4 (:wat::core::if has-inc (:loxv::c-emit p3 (:loxv::Op.Jump {:offset 0})) p3)
     body-j (:wat::core::if has-inc (:wat::core::- (:loxv::ccount p4) 1) -1)
     inc-start (:loxv::ccount p4)
     p5 (:wat::core::if has-inc (:loxv::c-emit (:loxv::expression p4) (:loxv::Op.Pop {})) p4)
     p6 (:loxv::c-consume p5 "RIGHT_PAREN" "Expect ')' after for clauses.")
     p7 (:wat::core::if has-inc (:loxv::patch-jmp (:loxv::emit-loop p6 start0) body-j) p6)
     start (:wat::core::if has-inc inc-start start0)
     p8 (:loxv::emit-loop (:loxv::statement p7) start)
     p9 (:wat::core::if has-cond
          (:loxv::c-emit (:loxv::patch-jif p8 exit) (:loxv::Op.Pop {})) p8)]
    (:loxv::end-scope p9)))

;; ---- chapter 24: parameters, arguments, function declarations and `return`
(:wat::core::defn :loxv::param-loop [p <- :loxv::C arity <- :wat::core::i64] -> :loxv::Params
  (:wat::core::let [p0 (:wat::core::if (:wat::core::> arity 254)
                         (:loxv::c-error p "Can't have more than 255 parameters.") p)
                    p1 (:loxv::c-consume p0 "IDENTIFIER" "Expect parameter name.")
                    name (:lox::Token/text (:loxv::C/prev p1))
                    ;; a parameter is declared AND initialized at once: its value arrives on the
                    ;; stack from the caller, so there is no initializer to wait for
                    p2 (:loxv::mark-initialized (:loxv::declare-variable p1 name))
                    a (:wat::core::+ arity 1)]
    (:wat::core::if (:lox::kind-is? (:loxv::C/cur p2) "COMMA")
      (:loxv::param-loop (:loxv::c-advance p2) a)
      (:loxv::Params :p p2 :arity a))))

(:wat::core::defn :loxv::arg-loop [p <- :loxv::C n <- :wat::core::i64] -> :loxv::Params
  (:wat::core::let [p1 (:loxv::expression p)
                    p2 (:wat::core::if (:wat::core::> n 254)
                         (:loxv::c-error p1 "Can't have more than 255 arguments.") p1)
                    n1 (:wat::core::+ n 1)]
    (:wat::core::if (:lox::kind-is? (:loxv::C/cur p2) "COMMA")
      (:loxv::arg-loop (:loxv::c-advance p2) n1)
      (:loxv::Params :p p2 :arity n1))))

;; `(` as an INFIX operator, at the tightest precedence there is -- which is what makes
;; `f(1)(2)` and `a.b(c)` parse without a special case
(:wat::core::defn :loxv::call-op [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [r (:wat::core::if (:lox::kind-is? (:loxv::C/cur p) "RIGHT_PAREN")
                        (:loxv::Params :p p :arity 0)
                        (:loxv::arg-loop p 0))
                    p1 (:loxv::c-consume (:loxv::Params/p r) "RIGHT_PAREN" "Expect ')' after arguments.")]
    (:loxv::c-emit p1 (:loxv::Op.Call {:argc (:loxv::Params/arity r)}))))

(:wat::core::defn :loxv::compile-function [p <- :loxv::C name <- :wat::core::String] -> :loxv::C
  (:loxv::compile-function-typed p name "function"))

;; a METHOD reserves local slot 0 for the receiver, which is how `this` becomes an ordinary
;; local -- and why a closure inside a method can capture it like any other
(:wat::core::defn :loxv::compile-function-typed [p <- :loxv::C name <- :wat::core::String
                                                 ftype <- :wat::core::String] -> :loxv::C
  (:wat::core::let
    [q00 (:loxv::begin-scope (:wat::core::assoc (:loxv::begin-function p) :ftype ftype))
     q0 (:wat::core::if (:wat::core::= ftype "function") q00
          (:loxv::mark-initialized (:loxv::declare-variable q00 "this")))
     q1 (:loxv::c-consume q0 "LEFT_PAREN" "Expect '(' after function name.")
     r (:wat::core::if (:lox::kind-is? (:loxv::C/cur q1) "RIGHT_PAREN")
         (:loxv::Params :p q1 :arity 0)
         (:loxv::param-loop q1 0))
     q2 (:loxv::c-consume (:loxv::Params/p r) "RIGHT_PAREN" "Expect ')' after parameters.")
     q3 (:loxv::c-consume q2 "LEFT_BRACE" "Expect '{' before function body.")
     q4 (:loxv::block q3)]
    (:loxv::end-function q4 name (:loxv::Params/arity r))))

(:wat::core::defn :loxv::fun-decl [p <- :loxv::C] -> :loxv::C
  (:wat::core::let
    [p1 (:loxv::c-consume p "IDENTIFIER" "Expect function name.")
     name (:lox::Token/text (:loxv::C/prev p1))
     p2 (:loxv::declare-variable p1 name)
     p3 (:wat::core::if (:wat::core::= (:loxv::C/depth p2) 0) (:loxv::add-name p2 name) p2)
     slot (:wat::core::if (:wat::core::= (:loxv::C/depth p2) 0) (:loxv::last-slot p3) 0)
     ;; marked initialized BEFORE the body, so a local function can refer to itself
     p4 (:wat::core::if (:wat::core::> (:loxv::C/depth p3) 0) (:loxv::mark-initialized p3) p3)
     p5 (:loxv::compile-function p4 name)]
    (:loxv::define-variable p5 slot)))

;; ---- chapters 27-29: class declarations
(:wat::core::defn :loxv::add-local [p <- :loxv::C name <- :wat::core::String] -> :loxv::C
  (:loxv::mark-initialized (:loxv::declare-variable p name)))

(:wat::core::defn :loxv::method [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [p1 (:loxv::c-consume p "IDENTIFIER" "Expect method name.")
                    name (:lox::Token/text (:loxv::C/prev p1))
                    p2 (:loxv::add-name p1 name)
                    nslot (:loxv::last-slot p2)
                    ;; `init` is not a keyword; it is a method name the compiler knows about
                    ftype (:wat::core::if (:wat::core::= name "init") "initializer" "method")
                    p3 (:loxv::compile-function-typed p2 name ftype)]
    (:loxv::c-emit p3 (:loxv::Op.Method {:slot nslot}))))

(:wat::core::defn :loxv::method-loop [p <- :loxv::C] -> :loxv::C
  (:wat::core::if (:wat::core::or (:lox::kind-is? (:loxv::C/cur p) "RIGHT_BRACE")
                                  (:lox::kind-is? (:loxv::C/cur p) "EOF")) p
    (:loxv::method-loop (:loxv::method p))))

;; the class value is IMMUTABLE, so every method rebuilds it on the stack and the finished value
;; is stored back into its binding at the end. Nystrom mutates the object in place; the visible
;; behaviour is the same because nothing can observe the class until the declaration finishes.
(:wat::core::defn :loxv::store-class [p <- :loxv::C global? <- :wat::core::bool
                                      nslot <- :wat::core::i64 lslot <- :wat::core::i64] -> :loxv::C
  (:wat::core::if global? (:loxv::c-emit p (:loxv::Op.SetGlobal {:slot nslot}))
    (:loxv::c-emit p (:loxv::Op.SetLocal {:slot lslot}))))

(:wat::core::defn :loxv::class-decl [p <- :loxv::C] -> :loxv::C
  (:wat::core::let
    [p1 (:loxv::c-consume p "IDENTIFIER" "Expect class name.")
     name (:lox::Token/text (:loxv::C/prev p1))
     global? (:wat::core::= (:loxv::C/depth p1) 0)
     p2 (:loxv::declare-variable p1 name)
     lslot (:wat::core::- (:wat::core::length (:loxv::C/locals p2)) 1)
     p3 (:loxv::add-name p2 name)
     nslot (:loxv::last-slot p3)
     p4 (:loxv::c-emit p3 (:loxv::Op.Class {:slot nslot}))
     p5 (:wat::core::if global? (:loxv::c-emit p4 (:loxv::Op.DefineGlobal {:slot nslot}))
          (:loxv::mark-initialized p4))
     has-super (:lox::kind-is? (:loxv::C/cur p5) "LESS")
     p6 (:wat::core::assoc p5 :classes (:wat::core::conj (:loxv::C/classes p5) has-super))
     ;; a superclass: push it, give it a hidden local called `super` that methods can capture,
     ;; then merge its methods into the subclass
     p7 (:wat::core::if (:wat::core::not has-super) (:loxv::variable-named p6 name false)
          (:wat::core::let
            [a (:loxv::c-consume (:loxv::c-advance p6) "IDENTIFIER" "Expect superclass name.")
             supname (:lox::Token/text (:loxv::C/prev a))
             b (:wat::core::if (:wat::core::= supname name)
                 (:loxv::c-error a "A class can't inherit from itself.") a)
             c (:loxv::variable-named b supname false)
             d (:loxv::add-local (:loxv::begin-scope c) "super")
             e (:loxv::variable-named d name false)
             f (:loxv::c-emit e (:loxv::Op.Inherit {}))]
            (:loxv::store-class f global? nslot lslot)))
     p8 (:loxv::c-consume p7 "LEFT_BRACE" "Expect '{' before class body.")
     p9 (:loxv::method-loop p8)
     p10 (:loxv::c-consume p9 "RIGHT_BRACE" "Expect '}' after class body.")
     p11 (:loxv::c-emit (:loxv::store-class p10 global? nslot lslot) (:loxv::Op.Pop {}))
     p12 (:wat::core::if has-super (:loxv::end-scope p11) p11)]
    (:wat::core::assoc p12 :classes
      (:loxv::bools-take (:loxv::C/classes p12)
        (:wat::core::- (:wat::core::length (:loxv::C/classes p12)) 1) 0
        (:wat::core::Vector :- [:wat::core::bool])))))

(:wat::core::defn :loxv::bools-take [v <- (:wat::core::Vector :- [:wat::core::bool]) k <- :wat::core::i64
                                     j <- :wat::core::i64 acc <- (:wat::core::Vector :- [:wat::core::bool])]
  -> (:wat::core::Vector :- [:wat::core::bool])
  (:wat::core::if (:wat::core::>= j k) acc
    (:loxv::bools-take v k (:wat::core::+ j 1) (:wat::core::conj acc (:wat::core::nth v j)))))

(:wat::core::defn :loxv::return-stmt [p <- :loxv::C] -> :loxv::C
  (:wat::core::if (:wat::core::= (:wat::core::length (:loxv::C/cframes p)) 0)
    (:loxv::c-error p "Can't return from top-level code.")
    (:wat::core::if (:lox::kind-is? (:loxv::C/cur p) "SEMICOLON")
      ;; a bare `return` in an initializer returns `this`, not nil
      (:wat::core::if (:wat::core::= (:loxv::C/ftype p) "initializer")
        (:loxv::c-emit (:loxv::c-emit (:loxv::c-advance p) (:loxv::Op.GetLocal {:slot 0}))
          (:loxv::Op.Return {}))
        (:loxv::c-emit (:loxv::c-emit (:loxv::c-advance p) (:loxv::Op.Nil {})) (:loxv::Op.Return {})))
      (:wat::core::if (:wat::core::= (:loxv::C/ftype p) "initializer")
        (:loxv::c-error p "Can't return a value from an initializer.")
        (:loxv::c-emit
          (:loxv::c-consume (:loxv::expression p) "SEMICOLON" "Expect ';' after return value.")
          (:loxv::Op.Return {}))))))

(:wat::core::defn :loxv::statement [p <- :loxv::C] -> :loxv::C
  (:wat::core::cond
    ((:lox::kind-is? (:loxv::C/cur p) "PRINT") (:loxv::print-stmt (:loxv::c-advance p)))
    ((:lox::kind-is? (:loxv::C/cur p) "RETURN") (:loxv::return-stmt (:loxv::c-advance p)))
    ((:lox::kind-is? (:loxv::C/cur p) "IF") (:loxv::if-stmt (:loxv::c-advance p)))
    ((:lox::kind-is? (:loxv::C/cur p) "WHILE") (:loxv::while-stmt (:loxv::c-advance p)))
    ((:lox::kind-is? (:loxv::C/cur p) "FOR") (:loxv::for-stmt (:loxv::c-advance p)))
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
  (:wat::core::let [p1 (:wat::core::cond
                         ((:lox::kind-is? (:loxv::C/cur p) "VAR") (:loxv::var-decl (:loxv::c-advance p)))
                         ((:lox::kind-is? (:loxv::C/cur p) "FUN") (:loxv::fun-decl (:loxv::c-advance p)))
                         ((:lox::kind-is? (:loxv::C/cur p) "CLASS") (:loxv::class-decl (:loxv::c-advance p)))
                         (:else (:loxv::statement p)))]
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
                  :locals (:wat::core::Vector :- [:loxv::Local]) :depth 0
                  :cframes (:wat::core::Vector :- [:loxv::CFrame])
                  :upvals (:wat::core::Vector :- [:loxv::UpDesc])
                  :ftype "script" :classes (:wat::core::Vector :- [:wat::core::bool]))
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
                  :locals (:wat::core::Vector :- [:loxv::Local]) :depth 0
                  :cframes (:wat::core::Vector :- [:loxv::CFrame])
                  :upvals (:wat::core::Vector :- [:loxv::UpDesc])
                  :ftype "script" :classes (:wat::core::Vector :- [:wat::core::bool]))
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
