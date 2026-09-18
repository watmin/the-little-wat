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

(:wat::core::defrecord :loxv::C
  [src <- :wat::core::String  n <- :wat::core::i64  i <- :wat::core::i64  line <- :wat::core::i64
   cur <- :lox::Token  prev <- :lox::Token
   chunk <- :loxv::Chunk
   errs <- (:wat::core::Vector :- [:wat::core::String])
   panic <- :wat::core::bool])

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

(:wat::core::defn :loxv::parse-prec [p <- :loxv::C prec <- :wat::core::i64] -> :loxv::C
  (:loxv::infix-loop (:loxv::c-prefix (:loxv::c-advance p)) prec))

(:wat::core::defn :loxv::infix-loop [p <- :loxv::C prec <- :wat::core::i64] -> :loxv::C
  (:wat::core::if (:wat::core::<= prec (:loxv::infix-prec (:lox::tok-name (:lox::Token/kind (:loxv::C/cur p)))))
    (:loxv::infix-loop (:loxv::c-infix (:loxv::c-advance p)) prec)
    p))

(:wat::core::defn :loxv::c-prefix [p <- :loxv::C] -> :loxv::C
  (:wat::core::let [k (:lox::tok-name (:lox::Token/kind (:loxv::C/prev p)))]
    (:wat::core::cond
      ((:wat::core::= k "NUMBER")
        (:wat::core::match (:wat::string::to-f64 (:lox::Token/text (:loxv::C/prev p)))
          [:wat::core::Option.Some {:value v} (:loxv::c-constant p (:loxv::num v))]
          [:wat::core::Option.None {} (:loxv::c-error p "Not a number.")]))
      ;; the literals do not go in the constant pool -- they get their own opcodes, which is
      ;; Nystrom's point about why a tagged union earns dedicated instructions
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

(:wat::core::defn :loxv::compile [src <- :wat::core::String] -> :loxv::C
  (:wat::core::let
    [p0 (:loxv::C :src src :n (:wat::string::length src) :i 0 :line 1
                  :cur (:lox::blank-token) :prev (:lox::blank-token)
                  :chunk (:loxv::new-chunk)
                  :errs (:wat::core::Vector :- [:wat::core::String]) :panic false)
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
        [:loxv::Out.Err {:msg m :line l :steps k}
          (:wat::string::concat "[line " (:wat::i64::to-string l) "] Runtime error: " m)]
        [:loxv::Out.Ok {:stack s :steps k}
          (:wat::core::if (:wat::core::= (:wat::core::length s) 0) "(empty stack)"
            (:loxv::show (:wat::core::nth s (:wat::core::- (:wat::core::length s) 1))))]))))
