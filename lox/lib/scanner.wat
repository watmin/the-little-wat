;; lox/lib/scanner.wat — Crafting Interpreters chapter 16: scanning on demand.
;;
;; Nystrom's scanner is three pointers into the source (`start`, `current`, `line`) and a
;; `scanToken()` the compiler pulls one token at a time. Nothing is allocated: a Token is the
;; token's type, a POINTER into the source, a length, and a line. The whole chapter is built on
;; being able to step a pointer through a char array.
;;
;; **wat has no char-indexed sequence, and that shapes everything below.**
;; `:wat::string::subs` is the only way to reach character i; `:wat::string::split` REFUSES an
;; empty separator (a runtime `MalformedForm`, "separator must not be empty"), so a String cannot
;; be exploded into a `Vector` of characters; and `:wat::core::char` -- the type exists -- is
;; produced by exactly one intrinsic, which takes a length-1 String, so it is a destination and
;; not a route. `probes/lox/char-access-cost.wat` prices the two shapes that remain:
;;
;;   INDEX    `(subs src i (i+1))`, the direct translation of Nystrom's `scanner.current`
;;   CONSUME  carry the unscanned remainder and re-cut it, `(subs rest 1 n)`
;;
;; and the result is the reason this file uses INDEX. CONSUME starts twice as FAST at 1 KB and
;; ends 1.5x SLOWER at 16 KB, because it copies the whole remaining source at every character;
;; INDEX stays within about a third of a `Vector` walk of the same length, because `subs` is
;; O(start) (it counts chars, then skips) but the interpreted loop around it costs more.
;;
;; **And the number that matters is what a scanner then costs.** Both shapes here are interpreted
;; per-character loops: the record-per-character one (Nystrom's, translated) runs at about 220
;; microseconds per character, the record-per-token one at about 80, and a bare walk that does
;; nothing but look at each character -- `probes/lox/char-access-cost.wat` -- at about 10. So the
;; floor is the loop, and the shape multiplies it. Chapter 15 (C-098) found a 30% win by hoisting
;; a chunk's arrays out of the dispatch loop; there is no equivalent hoist here, because there is
;; no indexable form of a String to hoist INTO.
;;
;; **A Token here copies its lexeme; Nystrom's does not.** His is `{type, start, length, line}`
;; with `start` pointing into the source that outlives it. The wat choices are a copied substring
;; or an `(i, len)` pair that is meaningless without the source beside it. This file copies,
;; because a token that cannot be printed without its source is a worse tool; the cost is one
;; String allocation per token, which is exactly the allocation Nystrom wrote the chapter to
;; avoid.

;; Nystrom's TokenType, whole. `:Str` rather than `:String` only because the variant would
;; otherwise read as the scalar type at every use site.
(:wat::core::defenum :lox::Tok :wat::enum::Pure
  :LeftParen [] :RightParen [] :LeftBrace [] :RightBrace []
  :Comma [] :Dot [] :Minus [] :Plus [] :Semicolon [] :Slash [] :Star []
  :Bang [] :BangEqual [] :Equal [] :EqualEqual []
  :Greater [] :GreaterEqual [] :Less [] :LessEqual []
  :Identifier [] :Str [] :Number []
  :And [] :Class [] :Else [] :False [] :For [] :Fun [] :If [] :Nil [] :Or []
  :Print [] :Return [] :Super [] :This [] :True [] :Var [] :While []
  :Error [] :Eof [])

(:wat::core::defrecord :lox::Token
  [kind <- :lox::Tok  text <- :wat::core::String  line <- :wat::core::i64])

(:wat::core::defrecord :lox::Scanner
  [src <- :wat::core::String  n <- :wat::core::i64
   start <- :wat::core::i64  current <- :wat::core::i64  line <- :wat::core::i64])

;; scanToken answers a token AND a moved scanner; wat has no out-parameter, so the pair is a
;; record. That is one more `defrecord` allocation per token on top of the lexeme copy.
(:wat::core::defrecord :lox::Scanned [sc <- :lox::Scanner  tok <- :lox::Token])

(:wat::core::defn :lox::new-scanner [src <- :wat::core::String] -> :lox::Scanner
  (:lox::Scanner :src src :n (:wat::string::length src) :start 0 :current 0 :line 1))

;; the character at i, or "" past the end -- Nystrom's '\0' sentinel, which wat has no char for
(:wat::core::defn :lox::char-at [src <- :wat::core::String n <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i n) "" (:wat::string::subs src i (:wat::core::+ i 1))))

(:wat::core::defn :lox::chr [sc <- :lox::Scanner i <- :wat::core::i64] -> :wat::core::String
  (:lox::char-at (:lox::Scanner/src sc) (:lox::Scanner/n sc) i))

(:wat::core::defn :lox::at-end? [sc <- :lox::Scanner] -> :wat::core::bool
  (:wat::core::>= (:lox::Scanner/current sc) (:lox::Scanner/n sc)))

(:wat::core::defn :lox::peek [sc <- :lox::Scanner] -> :wat::core::String
  (:lox::chr sc (:lox::Scanner/current sc)))

(:wat::core::defn :lox::peek-next [sc <- :lox::Scanner] -> :wat::core::String
  (:lox::chr sc (:wat::core::+ (:lox::Scanner/current sc) 1)))

(:wat::core::defn :lox::advance [sc <- :lox::Scanner] -> :lox::Scanner
  (:lox::Scanner :src (:lox::Scanner/src sc) :n (:lox::Scanner/n sc)
                 :start (:lox::Scanner/start sc)
                 :current (:wat::core::+ (:lox::Scanner/current sc) 1)
                 :line (:lox::Scanner/line sc)))

(:wat::core::defn :lox::bump-line [sc <- :lox::Scanner] -> :lox::Scanner
  (:lox::Scanner :src (:lox::Scanner/src sc) :n (:lox::Scanner/n sc)
                 :start (:lox::Scanner/start sc) :current (:lox::Scanner/current sc)
                 :line (:wat::core::+ (:lox::Scanner/line sc) 1)))

(:wat::core::defn :lox::mark [sc <- :lox::Scanner] -> :lox::Scanner
  (:lox::Scanner :src (:lox::Scanner/src sc) :n (:lox::Scanner/n sc)
                 :start (:lox::Scanner/current sc) :current (:lox::Scanner/current sc)
                 :line (:lox::Scanner/line sc)))

(:wat::core::defn :lox::lexeme [sc <- :lox::Scanner] -> :wat::core::String
  (:wat::string::subs (:lox::Scanner/src sc) (:lox::Scanner/start sc) (:lox::Scanner/current sc)))

(:wat::core::defn :lox::make [sc <- :lox::Scanner k <- :lox::Tok] -> :lox::Scanned
  (:lox::Scanned :sc sc
    :tok (:lox::Token :kind k :text (:lox::lexeme sc) :line (:lox::Scanner/line sc))))

(:wat::core::defn :lox::err-token [sc <- :lox::Scanner msg <- :wat::core::String] -> :lox::Scanned
  (:lox::Scanned :sc sc
    :tok (:lox::Token :kind (:lox::Tok.Error {}) :text msg :line (:lox::Scanner/line sc))))

;; ---- character classes. No ordering on characters either, so these are membership tests.
(:wat::core::defn :lox::digit? [c <- :wat::core::String] -> :wat::core::bool
  (:wat::core::and (:wat::core::not (:wat::string::empty? c))
                   (:wat::string::contains? "0123456789" c)))

(:wat::core::defn :lox::alpha? [c <- :wat::core::String] -> :wat::core::bool
  (:wat::core::and (:wat::core::not (:wat::string::empty? c))
    (:wat::string::contains? "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_" c)))

(:wat::core::defn :lox::alnum? [c <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:lox::alpha? c) (:lox::digit? c)))

;; ---- whitespace and comments (Nystrom's skipWhitespace)
(:wat::core::defn :lox::skip-ws [sc <- :lox::Scanner] -> :lox::Scanner
  (:wat::core::let [c (:lox::peek sc)]
    (:wat::core::cond
      ((:wat::core::or (:wat::core::= c " ") (:wat::core::or (:wat::core::= c "\t") (:wat::core::= c "\r")))
        (:lox::skip-ws (:lox::advance sc)))
      ((:wat::core::= c "\n") (:lox::skip-ws (:lox::bump-line (:lox::advance sc))))
      ((:wat::core::and (:wat::core::= c "/") (:wat::core::= (:lox::peek-next sc) "/"))
        (:lox::skip-line sc))
      (:else sc))))

(:wat::core::defn :lox::skip-line [sc <- :lox::Scanner] -> :lox::Scanner
  (:wat::core::cond
    ((:lox::at-end? sc) sc)
    ((:wat::core::= (:lox::peek sc) "\n") (:lox::skip-ws sc))
    (:else (:lox::skip-line (:lox::advance sc)))))

;; ---- string literals
(:wat::core::defn :lox::scan-str [sc <- :lox::Scanner] -> :lox::Scanned
  (:wat::core::cond
    ((:lox::at-end? sc) (:lox::err-token sc "Unterminated string."))
    ((:wat::core::= (:lox::peek sc) "\"") (:lox::make (:lox::advance sc) (:lox::Tok.Str {})))
    ((:wat::core::= (:lox::peek sc) "\n") (:lox::scan-str (:lox::bump-line (:lox::advance sc))))
    (:else (:lox::scan-str (:lox::advance sc)))))

;; ---- numbers
(:wat::core::defn :lox::digits [sc <- :lox::Scanner] -> :lox::Scanner
  (:wat::core::if (:lox::digit? (:lox::peek sc)) (:lox::digits (:lox::advance sc)) sc))

(:wat::core::defn :lox::scan-num [sc <- :lox::Scanner] -> :lox::Scanned
  (:wat::core::let [a (:lox::digits sc)]
    (:wat::core::if (:wat::core::and (:wat::core::= (:lox::peek a) ".")
                                     (:lox::digit? (:lox::peek-next a)))
      (:lox::make (:lox::digits (:lox::advance a)) (:lox::Tok.Number {}))
      (:lox::make a (:lox::Tok.Number {})))))

;; ---- identifiers and keywords. Nystrom hand-builds a trie here; this is the table that trie
;; encodes, written out. The trie is an optimisation for C's switch, and wat's `cond` over 16
;; string comparisons is the same decision made once rather than nested by hand.
(:wat::core::defn :lox::keyword-kind [t <- :wat::core::String] -> :lox::Tok
  (:wat::core::cond
    ((:wat::core::= t "and") (:lox::Tok.And {}))
    ((:wat::core::= t "class") (:lox::Tok.Class {}))
    ((:wat::core::= t "else") (:lox::Tok.Else {}))
    ((:wat::core::= t "false") (:lox::Tok.False {}))
    ((:wat::core::= t "for") (:lox::Tok.For {}))
    ((:wat::core::= t "fun") (:lox::Tok.Fun {}))
    ((:wat::core::= t "if") (:lox::Tok.If {}))
    ((:wat::core::= t "nil") (:lox::Tok.Nil {}))
    ((:wat::core::= t "or") (:lox::Tok.Or {}))
    ((:wat::core::= t "print") (:lox::Tok.Print {}))
    ((:wat::core::= t "return") (:lox::Tok.Return {}))
    ((:wat::core::= t "super") (:lox::Tok.Super {}))
    ((:wat::core::= t "this") (:lox::Tok.This {}))
    ((:wat::core::= t "true") (:lox::Tok.True {}))
    ((:wat::core::= t "var") (:lox::Tok.Var {}))
    ((:wat::core::= t "while") (:lox::Tok.While {}))
    (:else (:lox::Tok.Identifier {}))))

(:wat::core::defn :lox::scan-ident [sc <- :lox::Scanner] -> :lox::Scanned
  (:wat::core::if (:lox::alnum? (:lox::peek sc)) (:lox::scan-ident (:lox::advance sc))
    (:lox::make sc (:lox::keyword-kind (:lox::lexeme sc)))))

;; if the next character is `want`, take it and answer `yes`; otherwise answer `no`
(:wat::core::defn :lox::two [sc <- :lox::Scanner want <- :wat::core::String
                             yes <- :lox::Tok no <- :lox::Tok] -> :lox::Scanned
  (:wat::core::if (:wat::core::= (:lox::peek sc) want)
    (:lox::make (:lox::advance sc) yes)
    (:lox::make sc no)))

;; ---- scanToken itself. ONE token, and the scanner that produced it.
(:wat::core::defn :lox::scan-token [sc0 <- :lox::Scanner] -> :lox::Scanned
  (:wat::core::let [sc (:lox::mark (:lox::skip-ws sc0))]
    (:wat::core::if (:lox::at-end? sc) (:lox::make sc (:lox::Tok.Eof {}))
      (:wat::core::let [c (:lox::peek sc)
                        a (:lox::advance sc)]
        (:wat::core::cond
          ((:wat::core::= c "(") (:lox::make a (:lox::Tok.LeftParen {})))
          ((:wat::core::= c ")") (:lox::make a (:lox::Tok.RightParen {})))
          ((:wat::core::= c "{") (:lox::make a (:lox::Tok.LeftBrace {})))
          ((:wat::core::= c "}") (:lox::make a (:lox::Tok.RightBrace {})))
          ((:wat::core::= c ";") (:lox::make a (:lox::Tok.Semicolon {})))
          ((:wat::core::= c ",") (:lox::make a (:lox::Tok.Comma {})))
          ((:wat::core::= c ".") (:lox::make a (:lox::Tok.Dot {})))
          ((:wat::core::= c "-") (:lox::make a (:lox::Tok.Minus {})))
          ((:wat::core::= c "+") (:lox::make a (:lox::Tok.Plus {})))
          ((:wat::core::= c "/") (:lox::make a (:lox::Tok.Slash {})))
          ((:wat::core::= c "*") (:lox::make a (:lox::Tok.Star {})))
          ((:wat::core::= c "!") (:lox::two a "=" (:lox::Tok.BangEqual {}) (:lox::Tok.Bang {})))
          ((:wat::core::= c "=") (:lox::two a "=" (:lox::Tok.EqualEqual {}) (:lox::Tok.Equal {})))
          ((:wat::core::= c "<") (:lox::two a "=" (:lox::Tok.LessEqual {}) (:lox::Tok.Less {})))
          ((:wat::core::= c ">") (:lox::two a "=" (:lox::Tok.GreaterEqual {}) (:lox::Tok.Greater {})))
          ((:wat::core::= c "\"") (:lox::scan-str a))
          ((:lox::digit? c) (:lox::scan-num a))
          ((:lox::alpha? c) (:lox::scan-ident a))
          (:else (:lox::err-token a (:wat::string::concat "Unexpected character: " c))))))))

(:wat::core::defn :lox::tok-name [k <- :lox::Tok] -> :wat::core::String
  (:wat::core::match k
    [:lox::Tok.LeftParen {} "LEFT_PAREN"]    [:lox::Tok.RightParen {} "RIGHT_PAREN"]
    [:lox::Tok.LeftBrace {} "LEFT_BRACE"]    [:lox::Tok.RightBrace {} "RIGHT_BRACE"]
    [:lox::Tok.Comma {} "COMMA"]             [:lox::Tok.Dot {} "DOT"]
    [:lox::Tok.Minus {} "MINUS"]             [:lox::Tok.Plus {} "PLUS"]
    [:lox::Tok.Semicolon {} "SEMICOLON"]     [:lox::Tok.Slash {} "SLASH"]
    [:lox::Tok.Star {} "STAR"]               [:lox::Tok.Bang {} "BANG"]
    [:lox::Tok.BangEqual {} "BANG_EQUAL"]    [:lox::Tok.Equal {} "EQUAL"]
    [:lox::Tok.EqualEqual {} "EQUAL_EQUAL"]  [:lox::Tok.Greater {} "GREATER"]
    [:lox::Tok.GreaterEqual {} "GREATER_EQUAL"] [:lox::Tok.Less {} "LESS"]
    [:lox::Tok.LessEqual {} "LESS_EQUAL"]    [:lox::Tok.Identifier {} "IDENTIFIER"]
    [:lox::Tok.Str {} "STRING"]              [:lox::Tok.Number {} "NUMBER"]
    [:lox::Tok.And {} "AND"]                 [:lox::Tok.Class {} "CLASS"]
    [:lox::Tok.Else {} "ELSE"]               [:lox::Tok.False {} "FALSE"]
    [:lox::Tok.For {} "FOR"]                 [:lox::Tok.Fun {} "FUN"]
    [:lox::Tok.If {} "IF"]                   [:lox::Tok.Nil {} "NIL"]
    [:lox::Tok.Or {} "OR"]                   [:lox::Tok.Print {} "PRINT"]
    [:lox::Tok.Return {} "RETURN"]           [:lox::Tok.Super {} "SUPER"]
    [:lox::Tok.This {} "THIS"]               [:lox::Tok.True {} "TRUE"]
    [:lox::Tok.Var {} "VAR"]                 [:lox::Tok.While {} "WHILE"]
    [:lox::Tok.Error {} "ERROR"]             [:lox::Tok.Eof {} "EOF"]))

(:wat::core::defn :lox::eof? [t <- :lox::Token] -> :wat::core::bool
  (:wat::core::match (:lox::Token/kind t)
    [:lox::Tok.Eof {} true]
    [:lox::Tok.LeftParen {} false] [:lox::Tok.RightParen {} false]
    [:lox::Tok.LeftBrace {} false] [:lox::Tok.RightBrace {} false]
    [:lox::Tok.Comma {} false] [:lox::Tok.Dot {} false]
    [:lox::Tok.Minus {} false] [:lox::Tok.Plus {} false]
    [:lox::Tok.Semicolon {} false] [:lox::Tok.Slash {} false]
    [:lox::Tok.Star {} false] [:lox::Tok.Bang {} false]
    [:lox::Tok.BangEqual {} false] [:lox::Tok.Equal {} false]
    [:lox::Tok.EqualEqual {} false] [:lox::Tok.Greater {} false]
    [:lox::Tok.GreaterEqual {} false] [:lox::Tok.Less {} false]
    [:lox::Tok.LessEqual {} false] [:lox::Tok.Identifier {} false]
    [:lox::Tok.Str {} false] [:lox::Tok.Number {} false]
    [:lox::Tok.And {} false] [:lox::Tok.Class {} false]
    [:lox::Tok.Else {} false] [:lox::Tok.False {} false]
    [:lox::Tok.For {} false] [:lox::Tok.Fun {} false]
    [:lox::Tok.If {} false] [:lox::Tok.Nil {} false]
    [:lox::Tok.Or {} false] [:lox::Tok.Print {} false]
    [:lox::Tok.Return {} false] [:lox::Tok.Super {} false]
    [:lox::Tok.This {} false] [:lox::Tok.True {} false]
    [:lox::Tok.Var {} false] [:lox::Tok.While {} false]
    [:lox::Tok.Error {} false]))

;; the EAGER driver: pull until EOF. Chapter 16's whole argument is that the compiler does NOT
;; need this -- it is here to be checked against, and to be timed against `scan-n` below.
(:wat::core::defn :lox::scan-all [sc <- :lox::Scanner
                                  acc <- (:wat::core::Vector :- [:lox::Token])]
  -> (:wat::core::Vector :- [:lox::Token])
  (:wat::core::let [r (:lox::scan-token sc)
                    t (:lox::Scanned/tok r)]
    (:wat::core::if (:lox::eof? t) (:wat::core::conj acc t)
      (:lox::scan-all (:lox::Scanned/sc r) (:wat::core::conj acc t)))))

;; the ON-DEMAND driver: pull exactly k tokens and stop, whatever the rest of the file holds
(:wat::core::defn :lox::scan-n [sc <- :lox::Scanner k <- :wat::core::i64
                                acc <- (:wat::core::Vector :- [:lox::Token])]
  -> (:wat::core::Vector :- [:lox::Token])
  (:wat::core::if (:wat::core::= k 0) acc
    (:wat::core::let [r (:lox::scan-token sc)
                      t (:lox::Scanned/tok r)]
      (:wat::core::if (:lox::eof? t) (:wat::core::conj acc t)
        (:lox::scan-n (:lox::Scanned/sc r) (:wat::core::- k 1) (:wat::core::conj acc t))))))

;; =====================================================================================
;; THE SECOND SHAPE. Everything above is the direct translation of Nystrom's scanner, and it
;; is the REGISTERIZED shape chapter 15 (C-098) measured at 2.3-2.5x: `advance` reads five
;; `defrecord` fields and allocates a new `Scanner` FOR EVERY CHARACTER. At BASELINE.md's 6130 ns
;; per `defrecord` accessor that is about 30 microseconds of field reads per character before any
;; scanning happens.
;;
;; This is the same scanner with the record taken out of the inner loops: the per-character walks
;; take `src`, `n` and `i` as plain arguments and answer a plain index, and a record is built ONCE
;; PER TOKEN rather than once per character. The tokens it produces must be identical -- ch16
;; checks that on the corpus before it times anything.

(:wat::core::defrecord :lox::Flat [next <- :wat::core::i64  line <- :wat::core::i64  tok <- :lox::Token])

;; newlines in src[a, b) -- the line bump for a span that was skipped or consumed wholesale
(:wat::core::defn :lox::fnl [src <- :wat::core::String a <- :wat::core::i64 b <- :wat::core::i64
                             acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= a b) acc
    (:lox::fnl src (:wat::core::+ a 1) b
      (:wat::core::if (:wat::core::= (:wat::string::subs src a (:wat::core::+ a 1)) "\n")
        (:wat::core::+ acc 1) acc))))

(:wat::core::defn :lox::fws [src <- :wat::core::String n <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [c (:lox::char-at src n i)]
    (:wat::core::cond
      ((:wat::core::or (:wat::core::= c " ")
         (:wat::core::or (:wat::core::= c "\t") (:wat::core::or (:wat::core::= c "\r") (:wat::core::= c "\n"))))
        (:lox::fws src n (:wat::core::+ i 1)))
      ((:wat::core::and (:wat::core::= c "/") (:wat::core::= (:lox::char-at src n (:wat::core::+ i 1)) "/"))
        (:lox::fws src n (:lox::feol src n i)))
      (:else i))))

(:wat::core::defn :lox::feol [src <- :wat::core::String n <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i n) i)
    ((:wat::core::= (:lox::char-at src n i) "\n") i)
    (:else (:lox::feol src n (:wat::core::+ i 1)))))

(:wat::core::defn :lox::fdigits [src <- :wat::core::String n <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:lox::digit? (:lox::char-at src n i)) (:lox::fdigits src n (:wat::core::+ i 1)) i))

(:wat::core::defn :lox::fident [src <- :wat::core::String n <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:lox::alnum? (:lox::char-at src n i)) (:lox::fident src n (:wat::core::+ i 1)) i))

;; index one past the closing quote, or -1 when the string runs off the end
(:wat::core::defn :lox::fstr [src <- :wat::core::String n <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i n) -1)
    ((:wat::core::= (:lox::char-at src n i) "\"") (:wat::core::+ i 1))
    (:else (:lox::fstr src n (:wat::core::+ i 1)))))

;; the ONE record built per token
(:wat::core::defn :lox::flat-tok [src <- :wat::core::String start <- :wat::core::i64 e <- :wat::core::i64
                                  line <- :wat::core::i64 k <- :lox::Tok] -> :lox::Flat
  ;; Nystrom's makeToken reads `scanner.line` AFTER the lexeme is consumed, so a string spanning
  ;; two lines reports the line it ENDED on. `l` is that line.
  (:wat::core::let [l (:wat::core::+ line (:lox::fnl src start e 0))]
    (:lox::Flat :next e :line l
      :tok (:lox::Token :kind k :text (:wat::string::subs src start e) :line l))))

(:wat::core::defn :lox::flat-err [i <- :wat::core::i64 line <- :wat::core::i64 msg <- :wat::core::String] -> :lox::Flat
  (:lox::Flat :next i :line line :tok (:lox::Token :kind (:lox::Tok.Error {}) :text msg :line line)))

(:wat::core::defn :lox::ftwo [src <- :wat::core::String n <- :wat::core::i64 start <- :wat::core::i64
                              i <- :wat::core::i64 line <- :wat::core::i64 want <- :wat::core::String
                              yes <- :lox::Tok no <- :lox::Tok] -> :lox::Flat
  (:wat::core::if (:wat::core::= (:lox::char-at src n i) want)
    (:lox::flat-tok src start (:wat::core::+ i 1) line yes)
    (:lox::flat-tok src start i line no)))

(:wat::core::defn :lox::flat-scan-token [src <- :wat::core::String n <- :wat::core::i64
                                         i0 <- :wat::core::i64 line0 <- :wat::core::i64] -> :lox::Flat
  (:wat::core::let [start (:lox::fws src n i0)
                    line (:wat::core::+ line0 (:lox::fnl src i0 start 0))]
    (:wat::core::if (:wat::core::>= start n) (:lox::flat-tok src start start line (:lox::Tok.Eof {}))
      (:wat::core::let [c (:lox::char-at src n start)
                        a (:wat::core::+ start 1)]
        (:wat::core::cond
          ((:wat::core::= c "(") (:lox::flat-tok src start a line (:lox::Tok.LeftParen {})))
          ((:wat::core::= c ")") (:lox::flat-tok src start a line (:lox::Tok.RightParen {})))
          ((:wat::core::= c "{") (:lox::flat-tok src start a line (:lox::Tok.LeftBrace {})))
          ((:wat::core::= c "}") (:lox::flat-tok src start a line (:lox::Tok.RightBrace {})))
          ((:wat::core::= c ";") (:lox::flat-tok src start a line (:lox::Tok.Semicolon {})))
          ((:wat::core::= c ",") (:lox::flat-tok src start a line (:lox::Tok.Comma {})))
          ((:wat::core::= c ".") (:lox::flat-tok src start a line (:lox::Tok.Dot {})))
          ((:wat::core::= c "-") (:lox::flat-tok src start a line (:lox::Tok.Minus {})))
          ((:wat::core::= c "+") (:lox::flat-tok src start a line (:lox::Tok.Plus {})))
          ((:wat::core::= c "/") (:lox::flat-tok src start a line (:lox::Tok.Slash {})))
          ((:wat::core::= c "*") (:lox::flat-tok src start a line (:lox::Tok.Star {})))
          ((:wat::core::= c "!") (:lox::ftwo src n start a line "=" (:lox::Tok.BangEqual {}) (:lox::Tok.Bang {})))
          ((:wat::core::= c "=") (:lox::ftwo src n start a line "=" (:lox::Tok.EqualEqual {}) (:lox::Tok.Equal {})))
          ((:wat::core::= c "<") (:lox::ftwo src n start a line "=" (:lox::Tok.LessEqual {}) (:lox::Tok.Less {})))
          ((:wat::core::= c ">") (:lox::ftwo src n start a line "=" (:lox::Tok.GreaterEqual {}) (:lox::Tok.Greater {})))
          ((:wat::core::= c "\"")
            (:wat::core::let [e (:lox::fstr src n a)]
              (:wat::core::if (:wat::core::= e -1) (:lox::flat-err n line "Unterminated string.")
                (:lox::flat-tok src start e line (:lox::Tok.Str {})))))
          ((:lox::digit? c)
            (:wat::core::let [d (:lox::fdigits src n a)]
              (:wat::core::if (:wat::core::and (:wat::core::= (:lox::char-at src n d) ".")
                                               (:lox::digit? (:lox::char-at src n (:wat::core::+ d 1))))
                (:lox::flat-tok src start (:lox::fdigits src n (:wat::core::+ d 1)) line (:lox::Tok.Number {}))
                (:lox::flat-tok src start d line (:lox::Tok.Number {})))))
          ((:lox::alpha? c)
            (:wat::core::let [e (:lox::fident src n a)]
              (:lox::flat-tok src start e line (:lox::keyword-kind (:wat::string::subs src start e)))))
          (:else (:lox::flat-err a line (:wat::string::concat "Unexpected character: " c))))))))

(:wat::core::defn :lox::flat-scan-all [src <- :wat::core::String n <- :wat::core::i64
                                       i <- :wat::core::i64 line <- :wat::core::i64
                                       acc <- (:wat::core::Vector :- [:lox::Token])]
  -> (:wat::core::Vector :- [:lox::Token])
  (:wat::core::let [r (:lox::flat-scan-token src n i line)
                    t (:lox::Flat/tok r)]
    (:wat::core::if (:lox::eof? t) (:wat::core::conj acc t)
      (:lox::flat-scan-all src n (:lox::Flat/next r) (:lox::Flat/line r) (:wat::core::conj acc t)))))

(:wat::core::defn :lox::flat-of [src <- :wat::core::String] -> (:wat::core::Vector :- [:lox::Token])
  (:lox::flat-scan-all src (:wat::string::length src) 0 1 (:wat::core::Vector :- [:lox::Token])))
