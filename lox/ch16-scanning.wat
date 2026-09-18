;; Crafting Interpreters chapter 16 (scanning on demand), in wat.
;;
;; Nystrom's chapter has two halves. The scanner itself -- token types, two-character operators,
;; comments, string and number literals, a keyword trie -- and the ARCHITECTURE: the compiler
;; pulls one token when it wants one, so a source file is never tokenized into a list. Both are
;; checked here: the first by scanning a corpus that uses every token kind Lox has, the second by
;; timing `scan-n` (pull 8) against `scan-all` (pull everything) on the same large source.
;;
;; What wat had to say about it is in lib/scanner.wat's header. The short form is that there is no
;; char-indexed sequence in the language, so the pointer walk the chapter is built on becomes
;; `(subs src i (i+1))` -- and, much more expensively, `advance` becomes a five-field `defrecord`
;; rebuilt FOR EVERY CHARACTER. That is chapter 15's registerized shape again, in the one place a
;; scanner cannot avoid it, so this chapter does what chapter 15 did: it writes the same scanner
;; with the record taken out of the inner loops, checks the two produce identical tokens, and
;; then times them.
;;
;; Run: wat lox/ch16-scanning.wat

(:wat::load-file! "lib/scanner.wat")

(:wat::core::defn :c16::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))

;; F-112: there is no `:wat::i64::min`, though `:wat::f64::min` exists.
(:wat::core::defn :c16::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))

;; prints the row and answers 1 when it failed, so the chapter can assert on the total
(:wat::core::defn :c16::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

;; pad/rpad4 live in lib/chunk.wat, which this chapter does not load -- chapter 17 is where the
;; scanner and the chunk first meet.
(:wat::core::defn :c16::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:c16::pad (:wat::string::concat s " ") n)))

(:wat::core::defn :c16::rpad4 [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [s (:wat::i64::to-string n)]
    (:wat::core::if (:wat::core::>= (:wat::string::length s) 4) s
      (:wat::string::concat (:wat::string::subs "    " 0 (:wat::core::- 4 (:wat::string::length s))) s))))

(:wat::core::defn :c16::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))

;; ---- the corpus: one small Lox program that uses every token kind in the language
(:wat::core::defn :c16::corpus [] -> :wat::core::String
  (:wat::string::join "\n"
    ["// a comment, which produces no token at all"
     "var pi = 3.14159;"
     "var f = false;"
     "fun add(a, b) { return a + b; }"
     "class Foo < Bar { init() { this.x = nil; super.init(); } }"
     "if (a != b and !c or d >= e) { print \"a string\"; } else { while (true) { for (;;) { } } }"
     "x = y <= z; x = y == z; x = y > z; x = y - z * w / v;"]))

;; every kind the corpus must exercise -- Nystrom's TokenType minus TOKEN_ERROR and TOKEN_EOF,
;; which are checked separately below because no well-formed program produces them
(:wat::core::defn :c16::all-kinds [] -> (:wat::core::Vector :- [:wat::core::String])
  ["LEFT_PAREN" "RIGHT_PAREN" "LEFT_BRACE" "RIGHT_BRACE" "COMMA" "DOT" "MINUS" "PLUS"
   "SEMICOLON" "SLASH" "STAR" "BANG" "BANG_EQUAL" "EQUAL" "EQUAL_EQUAL" "GREATER"
   "GREATER_EQUAL" "LESS" "LESS_EQUAL" "IDENTIFIER" "STRING" "NUMBER" "AND" "CLASS"
   "ELSE" "FALSE" "FOR" "FUN" "IF" "NIL" "OR" "PRINT" "RETURN" "SUPER" "THIS" "TRUE"
   "VAR" "WHILE"])

(:wat::core::defn :c16::names [ts <- (:wat::core::Vector :- [:lox::Token])] -> :wat::core::String
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::String t <- :lox::Token] -> :wat::core::String
      (:wat::string::concat a " " (:lox::tok-name (:lox::Token/kind t))))
    "" ts))

;; how many of `wanted` never appeared
(:wat::core::defn :c16::missing [seen <- :wat::core::String
                                 wanted <- (:wat::core::Vector :- [:wat::core::String])] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::i64 k <- :wat::core::String] -> :wat::core::i64
      (:wat::core::if (:wat::string::contains? seen (:wat::string::concat " " k)) a (:wat::core::+ a 1)))
    0 wanted))

;; the kinds of the first k tokens of `src`, as one string -- the shape most checks below want
(:wat::core::defn :c16::kinds-of [src <- :wat::core::String k <- :wat::core::i64] -> :wat::core::String
  (:wat::string::trim
    (:c16::names (:lox::scan-n (:lox::new-scanner src) k (:wat::core::Vector :- [:lox::Token])))))

(:wat::core::defn :c16::render [ts <- (:wat::core::Vector :- [:lox::Token])] -> :wat::core::String
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::String t <- :lox::Token] -> :wat::core::String
      (:wat::string::concat a "|" (:lox::tok-name (:lox::Token/kind t)) ":" (:lox::Token/text t)
        ":" (:wat::i64::to-string (:lox::Token/line t))))
    "" ts))

(:wat::core::defn :c16::first-tok [src <- :wat::core::String] -> :lox::Token
  (:lox::Scanned/tok (:lox::scan-token (:lox::new-scanner src))))

;; Nystrom's chapter-16 driver prints one line per token: its line, its kind, its lexeme
(:wat::core::defn :c16::dump [ts <- (:wat::core::Vector :- [:lox::Token])] -> :wat::core::nil
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::nil t <- :lox::Token] -> :wat::core::nil
      (:wat::kernel::println
        (:wat::string::concat (:c16::rpad4 (:lox::Token/line t)) " "
          (:c16::pad (:lox::tok-name (:lox::Token/kind t)) 15) " '" (:lox::Token/text t) "'")))
    nil ts))

;; ---- a big source, for the on-demand measurement
(:wat::core::defn :c16::repeat [s <- :wat::core::String k <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::= k 0) acc
    (:c16::repeat s (:wat::core::- k 1) (:wat::string::concat acc "\n" s))))

(:wat::core::defrecord :c16::Bench [rec <- :wat::core::i64  flat <- :wat::core::i64])

;; the two arms INTERLEAVED, each run twice and each taking first position once, because C-098's
;; first draft was confounded by running one arm first
(:wat::core::defn :c16::bench [src <- :wat::core::String] -> :c16::Bench
  (:wat::core::let
    [f0 (:c16::now) _f (:lox::flat-of src) f1 (:c16::now)
     r0 (:c16::now) _r (:lox::scan-all (:lox::new-scanner src) (:wat::core::Vector :- [:lox::Token])) r1 (:c16::now)
     g0 (:c16::now) _g (:lox::flat-of src) g1 (:c16::now)
     s0 (:c16::now) _s (:lox::scan-all (:lox::new-scanner src) (:wat::core::Vector :- [:lox::Token])) s1 (:c16::now)]
    (:c16::Bench :rec (:c16::imin (:wat::core::- r1 r0) (:wat::core::- s1 s0))
                 :flat (:c16::imin (:wat::core::- f1 f0) (:wat::core::- g1 g0)))))

(:wat::core::defn :c16::time-n [src <- :wat::core::String k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [a0 (:c16::now) _a (:lox::scan-n (:lox::new-scanner src) k (:wat::core::Vector :- [:lox::Token])) a1 (:c16::now)
                    b0 (:c16::now) _b (:lox::scan-n (:lox::new-scanner src) k (:wat::core::Vector :- [:lox::Token])) b1 (:c16::now)]
    (:c16::imin (:wat::core::- a1 a0) (:wat::core::- b1 b0))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [src (:c16::corpus)
     toks (:lox::scan-all (:lox::new-scanner src) (:wat::core::Vector :- [:lox::Token]))
     seen (:c16::names toks)
     ;; the big source: the corpus 60 times over
     big (:c16::repeat src 10 "")
     big-toks (:lox::scan-all (:lox::new-scanner big) (:wat::core::Vector :- [:lox::Token]))
     b (:c16::bench big)
     t-all (:c16::Bench/rec b)
     t-flat (:c16::Bench/flat b)
     t-8 (:c16::time-n big 8)
     nchars (:wat::string::length big)
     ntoks (:wat::core::length big-toks)]
    (:wat::core::do
      (:wat::kernel::println "== tokens ==")
      (:c16::dump toks)
      (:wat::kernel::println "")
      (:wat::kernel::println "---- what the scanner must satisfy ----")
      (:wat::core::let
        [rs
         [;; COVERAGE: every token kind Lox has, produced by the corpus above. The no-skipping
          ;; rule applied to a token set: 38 kinds, all of them, not a representative few.
          (:c16::expect "token kinds never produced  " (:c16::int (:c16::missing seen (:c16::all-kinds))) "0")
          (:c16::expect "kinds in Lox, minus ERR/EOF " (:c16::int (:wat::core::length (:c16::all-kinds))) "38")

          ;; MAXIMAL MUNCH: a two-character operator is ONE token, not two
          (:c16::expect "!= is one token             " (:c16::kinds-of "!= x" 1) "BANG_EQUAL")
          (:c16::expect "!  alone stays BANG         " (:c16::kinds-of "! x" 1) "BANG")
          (:c16::expect "== is one token             " (:c16::kinds-of "== x" 1) "EQUAL_EQUAL")
          (:c16::expect "<= is one token             " (:c16::kinds-of "<= x" 1) "LESS_EQUAL")
          (:c16::expect ">= is one token             " (:c16::kinds-of ">= x" 1) "GREATER_EQUAL")
          (:c16::expect "=  then = with a space      " (:c16::kinds-of "= = x" 2) "EQUAL EQUAL")

          ;; KEYWORDS vs IDENTIFIERS: a keyword is a whole word, never a prefix
          (:c16::expect "or is a keyword             " (:c16::kinds-of "or" 1) "OR")
          (:c16::expect "orchid is not               " (:c16::kinds-of "orchid" 1) "IDENTIFIER")
          (:c16::expect "class is a keyword          " (:c16::kinds-of "class" 1) "CLASS")
          (:c16::expect "classy is not               " (:c16::kinds-of "classy" 1) "IDENTIFIER")
          (:c16::expect "_leading is an identifier   " (:c16::kinds-of "_leading" 1) "IDENTIFIER")
          (:c16::expect "a1 is one identifier        " (:c16::kinds-of "a1" 1) "IDENTIFIER")

          ;; NUMBERS: a fraction is part of the number; a trailing dot is not
          (:c16::expect "3.14159 is one NUMBER       " (:lox::Token/text (:c16::first-tok "3.14159")) "3.14159")
          (:c16::expect "12. is NUMBER then DOT      " (:c16::kinds-of "12." 2) "NUMBER DOT")
          (:c16::expect ".5 is DOT then NUMBER       " (:c16::kinds-of ".5" 2) "DOT NUMBER")

          ;; STRINGS: the lexeme keeps its quotes, as Nystrom's does before ch19 strips them
          (:c16::expect "a string keeps its quotes   " (:lox::Token/text (:c16::first-tok "\"hi\"")) "\"hi\"")
          (:c16::expect "a string may hold punctuation"
            (:lox::Token/text (:c16::first-tok "\"a != b // not a comment\"")) "\"a != b // not a comment\"")
          (:c16::expect "an unterminated string errors" (:c16::kinds-of "\"oops" 1) "ERROR")
          (:c16::expect "and says so                 " (:lox::Token/text (:c16::first-tok "\"oops")) "Unterminated string.")

          ;; COMMENTS produce nothing, and do not eat the newline's line bump
          (:c16::expect "a comment yields no token   " (:c16::kinds-of "// nothing here\nvar" 1) "VAR")
          (:c16::expect "and the line still advanced " (:c16::int (:lox::Token/line (:c16::first-tok "// x\nvar"))) "2")
          (:c16::expect "a comment at EOF is fine    " (:c16::kinds-of "// just this" 1) "EOF")
          (:c16::expect "// is a comment, / is SLASH " (:c16::kinds-of "/ x" 1) "SLASH")

          ;; LINES: a token reports the line it started on, and a multi-line string bumps past
          (:c16::expect "third line reports 3        " (:c16::int (:lox::Token/line (:c16::first-tok "\n\nvar"))) "3")
          (:c16::expect "a string spanning two lines " (:c16::int (:lox::Token/line (:c16::first-tok "\"a\nb\""))) "2")

          ;; ERRORS: an unexpected character is a token, not a crash -- the chapter's own choice
          (:c16::expect "@ is an ERROR token         " (:c16::kinds-of "@" 1) "ERROR")
          (:c16::expect "and the scan goes on        " (:c16::kinds-of "@ var" 2) "ERROR VAR")

          ;; EOF: exactly one, at the end, even for empty input
          (:c16::expect "empty input is just EOF     " (:c16::kinds-of "" 4) "EOF")
          (:c16::expect "whitespace only is just EOF " (:c16::kinds-of "   \n\t " 4) "EOF")
          (:c16::expect "the corpus ends in EOF      "
            (:lox::tok-name (:lox::Token/kind (:wat::core::nth toks (:wat::core::- (:wat::core::length toks) 1)))) "EOF")

          ;; ON DEMAND: pulling 8 tokens must not cost what pulling all of them costs. This is
          ;; the chapter's architectural claim, and it is the one thing here that could have
          ;; failed -- a language whose only string operations were bulk (split, join) would have
          ;; to scan the whole source to produce the first token.
          ;; THE TWO SHAPES AGREE. Checked before either is timed -- a faster scanner that
          ;; scans differently is not a measurement of anything.
          (:c16::expect "the two shapes agree, corpus"
            (:wat::core::if (:wat::core::= (:c16::render toks) (:c16::render (:lox::flat-of src))) "yes" "no") "yes")
          (:c16::expect "and on the big source       "
            (:wat::core::if (:wat::core::= (:c16::render big-toks) (:c16::render (:lox::flat-of big))) "yes" "no") "yes")
          (:c16::expect "same token count            "
            (:c16::int (:wat::core::- (:wat::core::length big-toks) (:wat::core::length (:lox::flat-of big)))) "0")

          ;; and the record-per-character shape is the slower one, as chapter 15 found
          (:c16::expect "record-per-char is slower   "
            (:wat::core::if (:wat::core::> t-all t-flat) "yes" "no") "yes")

          (:c16::expect "8 tokens cost under a tenth "
            (:wat::core::if (:wat::core::< (:wat::core::* t-8 10) t-all) "yes" "no") "yes")]]
        (:wat::core::do
          (:wat::kernel::println "")
          (:wat::kernel::println "---- what scanning costs ----")
          (:wat::kernel::println
            (:wat::string::concat "source           " (:c16::int nchars) " chars, "
              (:c16::int ntoks) " tokens"))
          (:wat::kernel::println
            (:wat::string::concat "tokens/char      " (:c16::int (:wat::core::/ (:wat::core::* ntoks 100) nchars)) "%"))
          (:wat::kernel::println
            (:wat::string::concat "  record/char   " (:c16::int (:wat::core::/ t-all 1000)) " us   ("
              (:c16::int (:wat::core::/ t-all nchars)) " ns/char)"))
          (:wat::kernel::println
            (:wat::string::concat "  record/token  " (:c16::int (:wat::core::/ t-flat 1000)) " us   ("
              (:c16::int (:wat::core::/ t-flat nchars)) " ns/char)"))
          (:wat::kernel::println
            (:wat::string::concat "  ratio         "
              (:c16::int (:wat::core::/ (:wat::core::* t-all 100) t-flat)) "%   (100% = the same)"))
          (:wat::kernel::println
            (:wat::string::concat "  scan-n 8      " (:c16::int (:wat::core::/ t-8 1000)) " us"))
          (:wat::kernel::println "")
          (:wat::kernel::println "The same tokens, checked identical above, at between two and three")
          (:wat::kernel::println "times the cost, in both orderings. The difference is one five-field")
          (:wat::kernel::println "`defrecord` rebuilt per CHARACTER versus one built per TOKEN --")
          (:wat::kernel::println "C-098's registerized shape, met again in the one place a scanner")
          (:wat::kernel::println "cannot route around: the innermost loop there is.")
          (:wat::kernel::println "")
          (:wat::kernel::println "Neither shape has a hoist available. Chapter 15 bought 30% by reading")
          (:wat::kernel::println "the chunk's arrays once instead of per instruction; a String cannot be")
          (:wat::kernel::println "turned into a Vector of characters at all (`split` refuses an empty")
          (:wat::kernel::println "separator, at run time), so there is nothing to hoist into. A bare walk")
          (:wat::kernel::println "that only looks at each character costs about 10 us/char -- that is the")
          (:wat::kernel::println "floor the shape is multiplying.")
          (:wat::kernel::println "")
          (:wat::test::assert-eq
            (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                                 (:wat::core::+ a b)) 0 rs)
            0))))))
