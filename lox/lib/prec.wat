;; lox/lib/prec.wat — the pieces a Pratt parser needs that do not depend on what a VALUE is:
;; the precedence ladder, and two small token helpers. Chapter 17's compiler and chapter 18's
;; both load this, so the ladder is written once and the two eras cannot drift apart.

(:wat::load-file! "scanner.wat")

;; Nystrom's Precedence enum, as the integers a Pratt parser actually compares. Chapter 17 only
;; reaches TERM, FACTOR and UNARY; the rest are here because the ladder is the thing being
;; ported, and chapters 21-23 fill them in.
(:wat::core::defn :lox::PREC-NONE [] -> :wat::core::i64 0)
(:wat::core::defn :lox::PREC-ASSIGNMENT [] -> :wat::core::i64 1)
(:wat::core::defn :lox::PREC-OR [] -> :wat::core::i64 2)
(:wat::core::defn :lox::PREC-AND [] -> :wat::core::i64 3)
(:wat::core::defn :lox::PREC-EQUALITY [] -> :wat::core::i64 4)
(:wat::core::defn :lox::PREC-COMPARISON [] -> :wat::core::i64 5)
(:wat::core::defn :lox::PREC-TERM [] -> :wat::core::i64 6)
(:wat::core::defn :lox::PREC-FACTOR [] -> :wat::core::i64 7)
(:wat::core::defn :lox::PREC-UNARY [] -> :wat::core::i64 8)
(:wat::core::defn :lox::PREC-CALL [] -> :wat::core::i64 9)
(:wat::core::defn :lox::PREC-PRIMARY [] -> :wat::core::i64 10)

;; `:lox::eof?` is written as a 38-arm match because it answers a question about ONE variant.
;; Asking about a kind by name is the same question with one line, and a compiler asks it of
;; twenty different kinds; the name is the honest key here.
(:wat::core::defn :lox::kind-is? [t <- :lox::Token name <- :wat::core::String] -> :wat::core::bool
  (:wat::core::= (:lox::tok-name (:lox::Token/kind t)) name))

(:wat::core::defn :lox::blank-token [] -> :lox::Token
  (:lox::Token :kind (:lox::Tok.Eof {}) :text "" :line 0))

