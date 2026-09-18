;; lox/lib/compiler.wat — Crafting Interpreters chapter 17: compiling expressions.
;;
;; This is where the three pieces meet. The scanner (ch16) produces tokens on demand, the Pratt
;; parser consumes them, and the chunk (ch14) is emitted as it goes -- one pass, no syntax tree.
;;
;; **Nystrom's rule table is an array of function pointers indexed by TokenType**, three fields
;; per row: a prefix parser, an infix parser, and the infix precedence. The C code's central
;; trick is `getRule(operator)->infix`, a call through a table entry that may be NULL.
;;
;; This port does not build that table, and `probes/lox/rule-table.wat` was written so the reason
;; could be a choice rather than an excuse. The table IS expressible, and the probe builds it
;; three ways:
;;
;;   `defrecord` row   REFUSED -- the containment rule covers records, not only Pure enums, and a
;;                     function type counts as impure. F-114 on the diagnostic.
;;   Impure enum row   accepted, but an enum has no accessors, so `getRule(op)->infix` costs a
;;                     `match` per field: three helper functions where C writes three arrows.
;;   `defstruct` row   accepted WITH accessors, and reads like the C. This is the right carrier:
;;                     F-040 records that a `defstruct` may not cross a service boundary and a
;;                     `defrecord` may, which is exactly the distinction being enforced.
;;
;; So the table is available and this file does not use it. Nystrom needs `getRule` because C has
;; no way to say "dispatch on the token kind"; wat has `match`, which is exhaustive over
;; `:lox::Tok` at compile time, and a NULL prefix entry -- his "Expect expression." case --
;; becomes an arm rather than a pointer test.
;;
;; **The parser state is one record updated per token, not per character** -- C-099's lesson from
;; the scanner, applied before it cost anything. Nine fields, and every update goes through
;; `:wat::core::assoc` (F-113), which is flat in the field count where restating is linear.

(:wat::load-file! "vm.wat")
(:wat::load-file! "prec.wat")
(:wat::load-file! "scanner.wat")

;; the parser. `src`/`n`/`i`/`line` are the scanner's whole state -- the flat shape, so scanning
;; a character does not allocate.
(:wat::core::defrecord :lox::C
  [src <- :wat::core::String  n <- :wat::core::i64  i <- :wat::core::i64  line <- :wat::core::i64
   cur <- :lox::Token  prev <- :lox::Token
   chunk <- :lox::Chunk
   errs <- (:wat::core::Vector :- [:wat::core::String])
   panic <- :wat::core::bool])

(:wat::core::defn :lox::c-error [p <- :lox::C msg <- :wat::core::String] -> :lox::C
  ;; Nystrom's panic mode: after the first error, further ones are suppressed until the parser
  ;; resynchronizes (chapter 21). Without it one bad token reports five times.
  (:wat::core::if (:lox::C/panic p) p
    (:wat::core::assoc (:wat::core::assoc p :panic true)
      :errs (:wat::core::conj (:lox::C/errs p)
              (:wat::string::concat "[line " (:wat::i64::to-string (:lox::Token/line (:lox::C/cur p)))
                "] Error: " msg)))))

;; advance to the next token, reporting and skipping any ERROR tokens the scanner produced
(:wat::core::defn :lox::c-advance [p <- :lox::C] -> :lox::C
  (:wat::core::let [r (:lox::flat-scan-token (:lox::C/src p) (:lox::C/n p) (:lox::C/i p) (:lox::C/line p))
                    t (:lox::Flat/tok r)
                    a (:wat::core::assoc p :prev (:lox::C/cur p))
                    b (:wat::core::assoc a :cur t)
                    c (:wat::core::assoc b :i (:lox::Flat/next r))
                    d (:wat::core::assoc c :line (:lox::Flat/line r))]
    (:wat::core::if (:lox::kind-is? t "ERROR")
      (:lox::c-advance (:lox::c-error d (:lox::Token/text t)))
      d)))

(:wat::core::defn :lox::c-consume [p <- :lox::C name <- :wat::core::String msg <- :wat::core::String] -> :lox::C
  (:wat::core::if (:lox::kind-is? (:lox::C/cur p) name) (:lox::c-advance p)
    (:lox::c-error p msg)))

(:wat::core::defn :lox::c-emit [p <- :lox::C op <- :lox::Op] -> :lox::C
  (:wat::core::assoc p :chunk (:lox::write (:lox::C/chunk p) op (:lox::Token/line (:lox::C/prev p)))))

;; Nystrom's emitConstant: add to the pool, then emit the instruction that indexes it
(:wat::core::defn :lox::c-constant [p <- :lox::C v <- :wat::core::f64] -> :lox::C
  (:wat::core::let [ch (:lox::add-constant (:lox::C/chunk p) v)
                    p1 (:wat::core::assoc p :chunk ch)]
    (:lox::c-emit p1 (:lox::Op.Constant {:slot (:lox::constant-slot ch)}))))

;; the infix half of Nystrom's rule table: a precedence for the operators that have one
(:wat::core::defn :lox::infix-prec [name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= name "PLUS") (:lox::PREC-TERM))
    ((:wat::core::= name "MINUS") (:lox::PREC-TERM))
    ((:wat::core::= name "STAR") (:lox::PREC-FACTOR))
    ((:wat::core::= name "SLASH") (:lox::PREC-FACTOR))
    (:else (:lox::PREC-NONE))))

(:wat::core::defn :lox::expression [p <- :lox::C] -> :lox::C
  (:lox::parse-prec p (:lox::PREC-ASSIGNMENT)))

(:wat::core::defn :lox::parse-prec [p <- :lox::C prec <- :wat::core::i64] -> :lox::C
  (:wat::core::let [p1 (:lox::c-advance p)
                    p2 (:lox::c-prefix p1)]
    (:lox::infix-loop p2 prec)))

(:wat::core::defn :lox::infix-loop [p <- :lox::C prec <- :wat::core::i64] -> :lox::C
  (:wat::core::if (:wat::core::<= prec (:lox::infix-prec (:lox::tok-name (:lox::Token/kind (:lox::C/cur p)))))
    (:lox::infix-loop (:lox::c-infix (:lox::c-advance p)) prec)
    p))

;; the prefix half of the rule table. The `:else` arm is Nystrom's NULL entry.
(:wat::core::defn :lox::c-prefix [p <- :lox::C] -> :lox::C
  (:wat::core::let [k (:lox::tok-name (:lox::Token/kind (:lox::C/prev p)))]
    (:wat::core::cond
      ((:wat::core::= k "NUMBER")
        ;; Nystrom writes `strtod(parser.previous.start, NULL)`, which answers 0 for a string it
        ;; cannot read and says nothing. `:wat::string::to-f64` answers an Option, so the failure
        ;; has to be written down -- and the scanner guarantees it cannot happen, which is
        ;; exactly the kind of arm a compiler wants present and unreachable.
        (:wat::core::match (:wat::string::to-f64 (:lox::Token/text (:lox::C/prev p)))
          [:wat::core::Option.Some {:value v} (:lox::c-constant p v)]
          [:wat::core::Option.None {} (:lox::c-error p "Not a number.")]))
      ((:wat::core::= k "LEFT_PAREN")
        (:lox::c-consume (:lox::expression p) "RIGHT_PAREN" "Expect ')' after expression."))
      ((:wat::core::= k "MINUS")
        ;; unary binds tighter than any binary operator, and the operand is parsed at UNARY --
        ;; which is why -a.b works and -a*b is (-a)*b
        (:lox::c-emit (:lox::parse-prec p (:lox::PREC-UNARY)) (:lox::Op.Negate {})))
      (:else (:lox::c-error p "Expect expression.")))))

(:wat::core::defn :lox::c-infix [p <- :lox::C] -> :lox::C
  (:wat::core::let [k (:lox::tok-name (:lox::Token/kind (:lox::C/prev p)))
                    ;; left-associative: parse the right operand ONE level tighter
                    p1 (:lox::parse-prec p (:wat::core::+ (:lox::infix-prec k) 1))]
    (:wat::core::cond
      ((:wat::core::= k "PLUS") (:lox::c-emit p1 (:lox::Op.Add {})))
      ((:wat::core::= k "MINUS") (:lox::c-emit p1 (:lox::Op.Subtract {})))
      ((:wat::core::= k "STAR") (:lox::c-emit p1 (:lox::Op.Multiply {})))
      ((:wat::core::= k "SLASH") (:lox::c-emit p1 (:lox::Op.Divide {})))
      (:else (:lox::c-error p1 "Expect an operator.")))))

(:wat::core::defn :lox::compile [src <- :wat::core::String] -> :lox::C
  (:wat::core::let
    [p0 (:lox::C :src src :n (:wat::string::length src) :i 0 :line 1
                 :cur (:lox::blank-token) :prev (:lox::blank-token)
                 :chunk (:lox::new-chunk)
                 :errs (:wat::core::Vector :- [:wat::core::String]) :panic false)
     p1 (:lox::c-advance p0)
     p2 (:lox::expression p1)
     p3 (:lox::c-consume p2 "EOF" "Expect end of expression.")]
    (:lox::c-emit p3 (:lox::Op.Return {}))))

;; ---- reading a chunk back, for the checks
;; F-019: two values of one enum cannot be compared with `=`, and F-027/F-028 leave no nested
;; pattern to match a pair of them, so two chunks are compared by rendering each instruction.
(:wat::core::defn :lox::op-key [op <- :lox::Op] -> :wat::core::String
  (:wat::core::match op
    [:lox::Op.Constant {:slot s} (:wat::string::concat "CONST/" (:wat::i64::to-string s))]
    [:lox::Op.Add {} "ADD"] [:lox::Op.Subtract {} "SUB"] [:lox::Op.Multiply {} "MUL"]
    [:lox::Op.Divide {} "DIV"] [:lox::Op.Negate {} "NEG"] [:lox::Op.Return {} "RET"]))

(:wat::core::defn :lox::code-sig [c <- :lox::Chunk] -> :wat::core::String
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::String op <- :lox::Op] -> :wat::core::String
      (:wat::string::concat a " " (:lox::op-key op)))
    "" (:lox::Chunk/code c)))

(:wat::core::defn :lox::const-sig [c <- :lox::Chunk] -> :wat::core::String
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::String v <- :wat::core::f64] -> :wat::core::String
      (:wat::string::concat a " " (:wat::f64::to-string v)))
    "" (:lox::Chunk/constants c)))

(:wat::core::defn :lox::chunk-sig [c <- :lox::Chunk] -> :wat::core::String
  (:wat::string::concat (:wat::string::trim (:lox::code-sig c)) "   consts:"
    (:lox::const-sig c)))

;; compile and run, answering the value left on the stack
(:wat::core::defn :lox::interpret [src <- :wat::core::String] -> :wat::core::f64
  (:wat::core::let [p (:lox::compile src)
                    st (:lox::run-direct (:lox::C/chunk p))
                    s (:lox::VmState/stack st)]
    (:wat::core::if (:wat::core::= (:wat::core::length s) 0) 0.0
      (:wat::core::nth s (:wat::core::- (:wat::core::length s) 1)))))
