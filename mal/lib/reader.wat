;; mal/lib/reader.wat: mal's reader. A line of text becomes tokens, and tokens become a value.
;; Needs lib/types.wat. No main. Keyword spelling throughout.
;;
;; wat has no regular expressions and no character access, so the tokenizer walks the String
;; one one-character substring at a time.

;; ---- tokens

(:wat::core::defn :mal::space? [c <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= c " ")
    (:wat::core::or (:wat::core::= c ",")
      (:wat::core::or (:wat::core::= c "\n")
        (:wat::core::or (:wat::core::= c "\t") (:wat::core::= c "\r"))))))

(:wat::core::defn :mal::special? [c <- :wat::core::String] -> :wat::core::bool
  (:wat::string::contains? "[]{}()'`~^@" c))

(:wat::core::defn :mal::delimiter? [c <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:mal::space? c)
    (:wat::core::or (:mal::special? c)
      (:wat::core::or (:wat::core::= c ";") (:wat::core::= c "\"")))))

;; the index just past a string's closing quote, or the end if it has none
(:wat::core::defn :mal::string-end [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    n
    (:wat::core::let [c (:mal::char-at s i)]
      (:wat::core::if (:wat::core::= c "\\")
        (:mal::string-end s (:wat::core::+ i 2) n)
        (:wat::core::if (:wat::core::= c "\"") (:wat::core::+ i 1) (:mal::string-end s (:wat::core::+ i 1) n))))))

(:wat::core::defn :mal::atom-end [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    n
    (:wat::core::if (:mal::delimiter? (:mal::char-at s i)) i (:mal::atom-end s (:wat::core::+ i 1) n))))

(:wat::core::defn :mal::line-end [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    n
    (:wat::core::if (:wat::core::= (:mal::char-at s i) "\n") i (:mal::line-end s (:wat::core::+ i 1) n))))

(:wat::core::defn :mal::tokens-from [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :mal::Strs] -> :mal::Strs
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:wat::core::let [c (:mal::char-at s i)]
      (:wat::core::cond
        ((:mal::space? c) (:mal::tokens-from s (:wat::core::+ i 1) n acc))
        ((:wat::core::= c ";") (:mal::tokens-from s (:mal::line-end s i n) n acc))
        ((:wat::core::and (:wat::core::= c "~")
                          (:wat::core::and (:wat::core::< (:wat::core::+ i 1) n) (:wat::core::= (:mal::char-at s (:wat::core::+ i 1)) "@")))
          (:mal::tokens-from s (:wat::core::+ i 2) n (:wat::core::conj acc "~@")))
        ((:mal::special? c) (:mal::tokens-from s (:wat::core::+ i 1) n (:wat::core::conj acc c)))
        ((:wat::core::= c "\"")
          (:wat::core::let [j (:mal::string-end s (:wat::core::+ i 1) n)]
            (:mal::tokens-from s j n (:wat::core::conj acc (:wat::string::subs s i j)))))
        (:else
          (:wat::core::let [j (:mal::atom-end s i n)]
            (:mal::tokens-from s j n (:wat::core::conj acc (:wat::string::subs s i j)))))))))

(:wat::core::defn :mal::tokenize [s <- :wat::core::String] -> :mal::Strs
  (:mal::tokens-from s 0 (:wat::string::length s) (:wat::core::Vector :- [:wat::core::String])))

;; ---- forms

;; A read: a value and the index of the token after it, a failure, or nothing at all (a line
;; of only whitespace and comments).
(:wat::core::defenum :mal::Read :wat::enum::Impure
  :Got    [v <- :mal::Val  next <- :wat::core::i64]
  :Failed [msg <- :wat::core::String]
  :Empty  [])

(:wat::core::defn :mal::got [v <- :mal::Val next <- :wat::core::i64] -> :mal::Read (:mal::Read.Got {:v v :next next}))
(:wat::core::defn :mal::failed [msg <- :wat::core::String] -> :mal::Read (:mal::Read.Failed {:msg msg}))

;; does a string token end with its closing quote? (the first unescaped quote is its last char)
(:wat::core::defn :mal::closed-at? [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i n)
    false
    (:wat::core::let [c (:mal::char-at s i)]
      (:wat::core::if (:wat::core::= c "\\")
        (:mal::closed-at? s (:wat::core::+ i 2) n)
        (:wat::core::if (:wat::core::= c "\"") (:wat::core::= (:wat::core::+ i 1) n) (:mal::closed-at? s (:wat::core::+ i 1) n))))))

;; a string token's text, its escapes undone
(:wat::core::defn :mal::unescape-from [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:wat::core::let [c (:mal::char-at s i)]
      (:wat::core::if (:wat::core::and (:wat::core::= c "\\") (:wat::core::< (:wat::core::+ i 1) n))
        (:wat::core::let [d (:mal::char-at s (:wat::core::+ i 1))]
          (:mal::unescape-from s (:wat::core::+ i 2) n (:wat::string::concat acc (:wat::core::if (:wat::core::= d "n") "\n" d))))
        (:mal::unescape-from s (:wat::core::+ i 1) n (:wat::string::concat acc c))))))

(:wat::core::defn :mal::read-atom [t <- :wat::core::String next <- :wat::core::i64] -> :mal::Read
  (:wat::core::let [n (:wat::string::length t)
                    c (:mal::char-at t 0)]
    (:wat::core::cond
      ((:wat::core::= c "\"")
        (:wat::core::if (:wat::core::and (:wat::core::>= n 2) (:mal::closed-at? t 1 n))
          (:mal::got (:mal::str (:mal::unescape-from t 1 (:wat::core::- n 1) "")) next)
          (:mal::failed "expected '\"', got EOF")))
      ((:wat::core::= c ":") (:mal::got (:mal::kw (:wat::string::subs t 1 n)) next))
      ((:wat::core::= t "nil") (:mal::got (:mal::nil) next))
      ((:wat::core::= t "true") (:mal::got (:mal::true) next))
      ((:wat::core::= t "false") (:mal::got (:mal::false) next))
      (:else
        (:wat::core::match (:wat::string::to-i64 t)
          [:wat::core::Option.Some {:value k} (:mal::got (:mal::int k) next)]
          [:wat::core::Option.None {} (:mal::got (:mal::sym t) next)])))))

(:wat::core::defn :mal::make-seq [kind <- :wat::core::keyword items <- :mal::Vals] -> :mal::Val
  (:wat::core::cond
    ((:wat::core::= kind :vec) (:mal::vec items))
    ((:wat::core::= kind :map) (:mal::map items))
    (:else (:mal::list items))))

(:wat::core::defn :mal::read-seq [toks <- :mal::Strs i <- :wat::core::i64 close <- :wat::core::String acc <- :mal::Vals kind <- :wat::core::keyword] -> :mal::Read
  (:wat::core::if (:wat::core::>= i (:wat::core::length toks))
    (:mal::failed (:wat::string::concat "expected '" close "', got EOF"))
    (:wat::core::if (:wat::core::= (:wat::core::nth toks i) close)
      (:mal::got (:mal::make-seq kind acc) (:wat::core::+ i 1))
      (:wat::core::match (:mal::read-form toks i)
        [:mal::Read.Got {:v v :next j} (:mal::read-seq toks j close (:wat::core::conj acc v) kind)]
        [:mal::Read.Failed {:msg m} (:mal::failed m)]
        [:mal::Read.Empty {} (:mal::failed (:wat::string::concat "expected '" close "', got EOF"))]))))

;; 'x is (quote x), and likewise for ` ~ ~@ @
(:wat::core::defn :mal::read-wrap [toks <- :mal::Strs i <- :wat::core::i64 name <- :wat::core::String] -> :mal::Read
  (:wat::core::match (:mal::read-form toks i)
    [:mal::Read.Got {:v v :next j} (:mal::got (:mal::list (:wat::core::Vector :- [:mal::Val] (:mal::sym name) v)) j)]
    [:mal::Read.Failed {:msg m} (:mal::failed m)]
    [:mal::Read.Empty {} (:mal::failed "expected a form, got EOF")]))

;; ^m x is (with-meta x m)
(:wat::core::defn :mal::read-meta [toks <- :mal::Strs i <- :wat::core::i64] -> :mal::Read
  (:wat::core::match (:mal::read-form toks i)
    [:mal::Read.Got {:v m :next j}
      (:wat::core::match (:mal::read-form toks j)
        [:mal::Read.Got {:v v :next k} (:mal::got (:mal::list (:wat::core::Vector :- [:mal::Val] (:mal::sym "with-meta") v m)) k)]
        [:mal::Read.Failed {:msg msg} (:mal::failed msg)]
        [:mal::Read.Empty {} (:mal::failed "expected a form, got EOF")])]
    [:mal::Read.Failed {:msg msg} (:mal::failed msg)]
    [:mal::Read.Empty {} (:mal::failed "expected a form, got EOF")]))

(:wat::core::defn :mal::read-form [toks <- :mal::Strs i <- :wat::core::i64] -> :mal::Read
  (:wat::core::if (:wat::core::>= i (:wat::core::length toks))
    (:mal::failed "expected a form, got EOF")
    (:wat::core::let [t (:wat::core::nth toks i)
                      j (:wat::core::+ i 1)]
      (:wat::core::cond
        ((:wat::core::= t "(") (:mal::read-seq toks j ")" (:wat::core::Vector :- [:mal::Val]) :list))
        ((:wat::core::= t "[") (:mal::read-seq toks j "]" (:wat::core::Vector :- [:mal::Val]) :vec))
        ((:wat::core::= t "{") (:mal::read-seq toks j "}" (:wat::core::Vector :- [:mal::Val]) :map))
        ((:wat::core::= t ")") (:mal::failed "unexpected ')'"))
        ((:wat::core::= t "]") (:mal::failed "unexpected ']'"))
        ((:wat::core::= t "}") (:mal::failed "unexpected '}'"))
        ((:wat::core::= t "'") (:mal::read-wrap toks j "quote"))
        ((:wat::core::= t "`") (:mal::read-wrap toks j "quasiquote"))
        ((:wat::core::= t "~") (:mal::read-wrap toks j "unquote"))
        ((:wat::core::= t "~@") (:mal::read-wrap toks j "splice-unquote"))
        ((:wat::core::= t "@") (:mal::read-wrap toks j "deref"))
        ((:wat::core::= t "^") (:mal::read-meta toks j))
        (:else (:mal::read-atom t j))))))

;; the first form of a line
(:wat::core::defn :mal::read-str [s <- :wat::core::String] -> :mal::Read
  (:wat::core::let [toks (:mal::tokenize s)]
    (:wat::core::if (:wat::core::empty? toks) (:mal::Read.Empty {}) (:mal::read-form toks 0))))
