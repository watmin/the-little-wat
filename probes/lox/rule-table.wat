;; probes/lox/rule-table.wat
;;
;; Q: can wat build Crafting Interpreters' rule table -- an array indexed by token kind whose
;;    rows hold FUNCTION POINTERS (a prefix parser, an infix parser, a precedence)?
;;
;; lox/lib/compiler.wat does not build one, because `match` is wat's way of writing the dispatch
;; the table encodes. But "wat does not need it" and "wat cannot do it" are different claims, and
;; only one of them is this repository's to make. So: build it.
;;
;; Run: wat probes/lox/rule-table.wat

(:wat::core::defenum :p::Tok :wat::enum::Pure :Num [] :Plus [] :Star [] :Eof [])

;; the row. A closure is IMPURE, so a `:wat::enum::Pure` row type is unavailable (the aggregate
;; carrier rule); this asks whether a `defrecord` will carry one.
;; ATTEMPT 1 -- a `defrecord` row. REFUSED:
;;   containment rule (arc 293.W): pure aggregate ":p::Rule" may only hold pure fields --
;;   field "prefix" has impure (struct) type "[:wat::core::i64 :-> :wat::core::i64]"
;; located at src/check.rs:15086 (the F-006/F-008 family). So the containment rule covers
;; `defrecord`, not only `:wat::enum::Pure` -- a record may not hold a function value at all.
;;
;; (:wat::core::defrecord :p::Rule
;;   [prefix <- [:wat::core::i64 :-> :wat::core::i64]
;;    infix <- [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]
;;    prec <- :wat::core::i64])
;;
;; ATTEMPT 2 -- an IMPURE enum row, the carrier PAIP ch22 had to use for a closure. ACCEPTED,
;; but an enum has no accessors, so `getRule(op)->infix` needs a `match` per field: three helper
;; functions below where C writes three arrows.
(:wat::core::defenum :p::Rule :wat::enum::Impure
  :Row [prefix <- [:wat::core::i64 :-> :wat::core::i64]
        infix <- [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]
        prec <- :wat::core::i64])

(:wat::core::defn :p::lit [x <- :wat::core::i64] -> :wat::core::i64 x)
(:wat::core::defn :p::none1 [x <- :wat::core::i64] -> :wat::core::i64 -1)
(:wat::core::defn :p::add [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b))
(:wat::core::defn :p::mul [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* a b))
(:wat::core::defn :p::none2 [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 -1)

;; F-038: a builtin verb passed as a value is not a function value, so every entry is a user
;; `defn` or an explicit `fn`.
(:wat::core::defn :p::table [] -> (:wat::core::Vector :- [:p::Rule])
  [(:p::Rule.Row {:prefix (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:p::lit x))
             :infix (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:p::none2 a b))
             :prec 0})
   (:p::Rule.Row {:prefix (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:p::none1 x))
             :infix (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:p::add a b))
             :prec 6})
   (:p::Rule.Row {:prefix (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:p::none1 x))
             :infix (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:p::mul a b))
             :prec 7})
   (:p::Rule.Row {:prefix (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:p::none1 x))
             :infix (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:p::none2 a b))
             :prec 0})]) 

(:wat::core::defn :p::index [t <- :p::Tok] -> :wat::core::i64
  (:wat::core::match t
    [:p::Tok.Num {} 0] [:p::Tok.Plus {} 1] [:p::Tok.Star {} 2] [:p::Tok.Eof {} 3]))

(:wat::core::defn :p::rule [t <- :p::Tok] -> :p::Rule
  (:wat::core::nth (:p::table) (:p::index t)))

(:wat::core::defn :p::rule-prefix [t <- :p::Tok] -> [:wat::core::i64 :-> :wat::core::i64]
  (:wat::core::match (:p::rule t) [:p::Rule.Row {:prefix f :infix g :prec n} f]))

(:wat::core::defn :p::rule-infix [t <- :p::Tok] -> [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]
  (:wat::core::match (:p::rule t) [:p::Rule.Row {:prefix f :infix g :prec n} g]))

(:wat::core::defn :p::rule-prec [t <- :p::Tok] -> :wat::core::i64
  (:wat::core::match (:p::rule t) [:p::Rule.Row {:prefix f :infix g :prec n} n]))

;; getRule(op)->infix(a, b) -- the call through a table entry
(:wat::core::defn :p::apply-infix [t <- :p::Tok a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  ((:p::rule-infix t) a b))

(:wat::core::defn :p::apply-prefix [t <- :p::Tok x <- :wat::core::i64] -> :wat::core::i64
  ((:p::rule-prefix t) x))

;; ATTEMPT 3 -- a `defstruct` row. ACCEPTED, WITH ACCESSORS. This is the answer: F-040 records
;; that a `defstruct` may not cross a service boundary and a `defrecord` may, and that is exactly
;; the distinction the containment rule is enforcing -- so the aggregate that may hold a function
;; is the one that was never going to cross. The refusal in ATTEMPT 1 does not say so.
(:wat::core::defstruct :p::SRule
  [prefix <- [:wat::core::i64 :-> :wat::core::i64]
   infix <- [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]
   prec <- :wat::core::i64])

(:wat::core::defn :p::stable [] -> (:wat::core::Vector :- [:p::SRule])
  [(:p::SRule :prefix (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:p::lit x))
              :infix (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:p::none2 a b))
              :prec 0)
   (:p::SRule :prefix (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:p::none1 x))
              :infix (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:p::add a b))
              :prec 6)
   (:p::SRule :prefix (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:p::none1 x))
              :infix (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:p::mul a b))
              :prec 7)
   (:p::SRule :prefix (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:p::none1 x))
              :infix (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:p::none2 a b))
              :prec 0)])

;; getRule(op)->infix(a, b), in one line, exactly as the C reads
(:wat::core::defn :p::srule [t <- :p::Tok] -> :p::SRule (:wat::core::nth (:p::stable) (:p::index t)))

(:wat::core::defn :p::s-infix [t <- :p::Tok a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  ((:p::SRule/infix (:p::srule t)) a b))

(:wat::core::defn :p::s-prefix [t <- :p::Tok x <- :wat::core::i64] -> :wat::core::i64
  ((:p::SRule/prefix (:p::srule t)) x))

(:wat::core::defn :p::show [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label " => " (:wat::i64::to-string n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:p::show "prefix of Num on 41        " (:p::apply-prefix (:p::Tok.Num {}) 41))
    (:p::show "prefix of Plus (the NULL)  " (:p::apply-prefix (:p::Tok.Plus {}) 41))
    (:p::show "infix of Plus 20 22        " (:p::apply-infix (:p::Tok.Plus {}) 20 22))
    (:p::show "infix of Star 6 7          " (:p::apply-infix (:p::Tok.Star {}) 6 7))
    (:p::show "precedence of Star         " (:p::rule-prec (:p::Tok.Star {})))
    (:p::show "precedence of Eof          " (:p::rule-prec (:p::Tok.Eof {})))
    (:wat::kernel::println "")
    (:wat::kernel::println "the same table as a defstruct -- accessors, no match per field:")
    (:p::show "SRule prefix of Num on 41  " (:p::s-prefix (:p::Tok.Num {}) 41))
    (:p::show "SRule infix of Plus 20 22  " (:p::s-infix (:p::Tok.Plus {}) 20 22))
    (:p::show "SRule infix of Star 6 7    " (:p::s-infix (:p::Tok.Star {}) 6 7))
    (:p::show "SRule precedence of Star   " (:p::SRule/prec (:p::srule (:p::Tok.Star {}))))
    (:wat::kernel::println "")
    (:wat::kernel::println "VERDICT: the rule table is expressible. A `defrecord` row is refused")
    (:wat::kernel::println "outright, an Impure enum row works but costs a match per field read,")
    (:wat::kernel::println "and a `defstruct` row works with accessors and reads like the C. What")
    (:wat::kernel::println "lox/lib/compiler.wat uses instead is `match`, because the table encodes")
    (:wat::kernel::println "a dispatch wat can write directly -- a choice, not a limitation.")))
