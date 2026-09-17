;; PAIP chapter 5 (ELIZA), in wat.
;;
;; The chapter's real content is the MATCHER, not the psychiatry. A single variable `?x` matches
;; one word; a SEGMENT variable `?*x` matches zero or more, and matching one means trying every
;; split and BACKTRACKING when the rest of the pattern fails. So the tests below drive the matcher
;; directly as well as through the rules -- including the two cases a naive implementation gets
;; wrong: a segment matching NOTHING, and the same variable appearing twice.
;;
;; Two wat notes, and the first is the interesting one:
;;
;;   **F-062 decides the representation.** A wat String has no characters, no `index-of` and no
;;   `split-lines`, so recognising `?x` and `?*x` cannot be done by looking at characters the way
;;   the Scheme does (`string-ref s 0`). What works is `:wat::string::starts-with?`, which exists
;;   and is enough here. A pattern is a `Vector<String>` and the variable test is a prefix test.
;;   This is the least painful F-062 has been in this repository -- worth recording, because the
;;   finding's weight should track the workloads it actually blocks, and this one it did not.
;;
;;   Bindings map a name to a LIST of words, since a segment variable binds several. `Fail` is a
;;   distinct outcome from "matched with no bindings", which is the distinction the Scheme makes
;;   with the symbol `fail` against `'()` and which an `Option` would blur.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch05-eliza.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch05-eliza.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Words (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defenum :paip::Binds :wat::enum::Pure
  :BNil  []
  :BCons [name <- :wat::core::String  words <- :paip::Words  rest <- :paip::Binds])

;; `Fail` is not the same as "matched, no bindings" -- an Option would lose that
(:wat::core::defenum :paip::MRes :wat::enum::Pure
  :Ok   [b <- :paip::Binds]
  :Fail [])

;; F-062: no characters, so the variable test is a PREFIX test rather than a character test
(:wat::core::defn :paip::segment-var? [x <- :wat::core::String] -> :wat::core::bool
  (:wat::string::starts-with? x "?*"))

(:wat::core::defn :paip::single-var? [x <- :wat::core::String] -> :wat::core::bool
  (:wat::core::and (:wat::string::starts-with? x "?")
                   (:wat::core::not (:wat::string::starts-with? x "?*"))))

(:wat::core::defn :paip::seg-name [x <- :wat::core::String] -> :wat::core::String
  (:wat::string::subs x 2 (:wat::string::length x)))

(:wat::core::defn :paip::var-name [x <- :wat::core::String] -> :wat::core::String
  (:wat::string::subs x 1 (:wat::string::length x)))

(:wat::core::defn :paip::lookup [name <- :wat::core::String b <- :paip::Binds]
  -> (:wat::core::Option :- [:paip::Words])
  (:wat::core::match b
    [:paip::Binds.BNil {} (:wat::core::Option.None {})]
    [:paip::Binds.BCons {:name n :words w :rest rest}
      (:wat::core::if (:wat::core::= n name) (:wat::core::Option.Some {:value w})
        (:paip::lookup name rest))]))

(:wat::core::defn :paip::same-words? [a <- :paip::Words b <- :paip::Words] -> :wat::core::bool
  (:wat::core::and (:wat::core::= (:wat::core::length a) (:wat::core::length b))
    (:wat::core::= (:wat::string::join " " a) (:wat::string::join " " b))))

(:wat::core::defn :paip::head-n [v <- :paip::Words n <- :wat::core::i64 i <- :wat::core::i64 acc <- :paip::Words] -> :paip::Words
  (:wat::core::if (:wat::core::>= i n) acc
    (:paip::head-n v n (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth v i)))))

(:wat::core::defn :paip::tail-from [v <- :paip::Words i <- :wat::core::i64 acc <- :paip::Words] -> :paip::Words
  (:wat::core::if (:wat::core::>= i (:wat::core::length v)) acc
    (:paip::tail-from v (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth v i)))))

(:wat::core::defn :paip::drop1 [v <- :paip::Words] -> :paip::Words
  (:paip::tail-from v 1 (:wat::core::Vector :- [:wat::core::String])))

(:wat::core::defn :paip::pat-match [pattern <- :paip::Words input <- :paip::Words b <- :paip::Binds] -> :paip::MRes
  (:wat::core::if (:wat::core::empty? pattern)
    (:wat::core::if (:wat::core::empty? input) (:paip::MRes.Ok {:b b}) (:paip::MRes.Fail {}))
    (:wat::core::let [p0 (:wat::core::nth pattern 0)]
      (:wat::core::if (:paip::segment-var? p0)
        (:paip::segment-match pattern input b 0)
        (:wat::core::if (:paip::single-var? p0)
          (:wat::core::if (:wat::core::empty? input) (:paip::MRes.Fail {})
            (:wat::core::let [n (:paip::var-name p0)
                              one (:wat::core::Vector :- [:wat::core::String] (:wat::core::nth input 0))]
              (:wat::core::match (:paip::lookup n b)
                [:wat::core::Option.Some {:value old}
                  (:wat::core::if (:paip::same-words? old one)
                    (:paip::pat-match (:paip::drop1 pattern) (:paip::drop1 input) b)
                    (:paip::MRes.Fail {}))]
                [:wat::core::Option.None {}
                  (:paip::pat-match (:paip::drop1 pattern) (:paip::drop1 input)
                    (:paip::Binds.BCons {:name n :words one :rest b}))])))
          (:wat::core::if (:wat::core::and (:wat::core::not (:wat::core::empty? input))
                                           (:wat::core::= p0 (:wat::core::nth input 0)))
            (:paip::pat-match (:paip::drop1 pattern) (:paip::drop1 input) b)
            (:paip::MRes.Fail {})))))))

;; try every split, shortest first, and backtrack when the rest of the pattern fails
(:wat::core::defn :paip::segment-match
  [pattern <- :paip::Words input <- :paip::Words b <- :paip::Binds start <- :wat::core::i64] -> :paip::MRes
  (:wat::core::if (:wat::core::> start (:wat::core::length input)) (:paip::MRes.Fail {})
    (:wat::core::let [n (:paip::seg-name (:wat::core::nth pattern 0))
                      seg (:paip::head-n input start 0 (:wat::core::Vector :- [:wat::core::String]))
                      rest (:paip::tail-from input start (:wat::core::Vector :- [:wat::core::String]))]
      (:wat::core::match (:paip::lookup n b)
        [:wat::core::Option.Some {:value old}
          (:wat::core::if (:wat::core::not (:paip::same-words? old seg))
            (:paip::segment-match pattern input b (:wat::core::+ start 1))
            (:wat::core::match (:paip::pat-match (:paip::drop1 pattern) rest b)
              [:paip::MRes.Ok {:b b2} (:paip::MRes.Ok {:b b2})]
              [:paip::MRes.Fail {} (:paip::segment-match pattern input b (:wat::core::+ start 1))]))]
        [:wat::core::Option.None {}
          (:wat::core::match (:paip::pat-match (:paip::drop1 pattern) rest
                               (:paip::Binds.BCons {:name n :words seg :rest b}))
            [:paip::MRes.Ok {:b b2} (:paip::MRes.Ok {:b b2})]
            [:paip::MRes.Fail {} (:paip::segment-match pattern input b (:wat::core::+ start 1))])]))))

;; ---- rules and replies
(:wat::core::defn :paip::substitute-in [template <- :paip::Words b <- :paip::Binds i <- :wat::core::i64 acc <- :paip::Words] -> :paip::Words
  (:wat::core::if (:wat::core::>= i (:wat::core::length template)) acc
    (:wat::core::let [t (:wat::core::nth template i)]
      (:paip::substitute-in template b (:wat::core::+ i 1)
        (:wat::core::if (:paip::segment-var? t)
          (:wat::core::match (:paip::lookup (:paip::seg-name t) b)
            [:wat::core::Option.Some {:value v} (:wat::core::concat acc v)]
            [:wat::core::Option.None {} (:wat::core::conj acc t)])
          (:wat::core::if (:paip::single-var? t)
            (:wat::core::match (:paip::lookup (:paip::var-name t) b)
              [:wat::core::Option.Some {:value v} (:wat::core::concat acc v)]
              [:wat::core::Option.None {} (:wat::core::conj acc t)])
            (:wat::core::conj acc t)))))))

(:wat::core::defstruct :paip::Rule [pattern <- :paip::Words  reply <- :paip::Words])

(:wat::core::defn :paip::ws [s <- :wat::core::String] -> :paip::Words (:wat::string::split s " "))

(:wat::core::defn :paip::rules [] -> (:wat::core::Vector :- [:paip::Rule])
  (:wat::core::Vector :- [:paip::Rule]
    (:paip::Rule :pattern (:paip::ws "?*x i need ?*y") :reply (:paip::ws "why do you need ?*y ?"))
    (:paip::Rule :pattern (:paip::ws "?*x i am ?*y") :reply (:paip::ws "how long have you been ?*y ?"))
    (:paip::Rule :pattern (:paip::ws "?*x hello ?*y") :reply (:paip::ws "hello there what brings you here ?"))
    (:paip::Rule :pattern (:paip::ws "?*x") :reply (:paip::ws "please go on"))))

(:wat::core::defn :paip::eliza-from [input <- :paip::Words i <- :wat::core::i64] -> :paip::Words
  (:wat::core::let [rs (:paip::rules)]
    (:wat::core::if (:wat::core::>= i (:wat::core::length rs)) (:paip::ws "i am not sure what you mean")
      (:wat::core::let [r (:wat::core::nth rs i)]
        (:wat::core::match (:paip::pat-match (:paip::Rule/pattern r) input (:paip::Binds.BNil {}))
          [:paip::MRes.Fail {} (:paip::eliza-from input (:wat::core::+ i 1))]
          [:paip::MRes.Ok {:b b}
            (:paip::substitute-in (:paip::Rule/reply r) b 0 (:wat::core::Vector :- [:wat::core::String]))])))))

(:wat::core::defn :paip::eliza [input <- :paip::Words] -> :paip::Words (:paip::eliza-from input 0))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :paip::show-words [ws <- :paip::Words] -> :wat::core::String
  (:wat::string::concat "(" (:wat::string::join " " ws) ")"))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :paip::matched? [p <- :wat::core::String in <- :wat::core::String] -> :wat::core::bool
  (:wat::core::match (:paip::pat-match (:paip::ws p) (:paip::ws in) (:paip::Binds.BNil {}))
    [:paip::MRes.Ok {:b b} true]
    [:paip::MRes.Fail {} false]))

(:wat::core::defn :paip::bound [p <- :wat::core::String in <- :wat::core::String name <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:paip::pat-match (:paip::ws p) (:paip::ws in) (:paip::Binds.BNil {}))
    [:paip::MRes.Fail {} "(fail)"]
    [:paip::MRes.Ok {:b b}
      (:wat::core::match (:paip::lookup name b)
        [:wat::core::Option.Some {:value v} (:paip::show-words v)]
        [:wat::core::Option.None {} "()"])]))

;; the empty pattern against empty input needs a Vector of no words, which `split` cannot make
(:wat::core::defn :paip::empty-matches? [] -> :wat::core::bool
  (:wat::core::match (:paip::pat-match (:wat::core::Vector :- [:wat::core::String])
                       (:wat::core::Vector :- [:wat::core::String]) (:paip::Binds.BNil {}))
    [:paip::MRes.Ok {:b b} true]
    [:paip::MRes.Fail {} false]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:paip::check-chapter "oracle/paip/ch05-eliza.expected"
                        "paip ch05 eliza"
                        (:wat::core::Vector :- [:wat::core::String]
                          (:paip::b (:paip::matched? "i need a ?x" "i need a vacation"))
                          (:paip::bound "i need a ?x" "i need a vacation" "x")
                          (:paip::b (:wat::core::not (:paip::matched? "i need a ?x" "i really need a vacation")))
                          (:paip::bound "?*x need a ?y" "i really need a vacation" "x")
                          (:paip::bound "?*x need a ?y" "i really need a vacation" "y")
                          ;; a segment matching NOTHING
                          (:paip::bound "?*x need a ?y" "need a break" "x")
                          ;; two segments: the first is as SHORT as possible, splits tried in order
                          (:paip::bound "?*x is ?*y" "a b is c d" "x")
                          (:paip::bound "?*x is ?*y" "a b is c d" "y")
                          ;; the same variable twice must match the same words
                          (:paip::b (:wat::core::not (:paip::matched? "?x and ?x" "cats and dogs")))
                          (:paip::bound "?x and ?x" "cats and cats" "x")
                          (:paip::b (:wat::core::not (:paip::matched? "hello" "goodbye")))
                          (:paip::b (:paip::empty-matches?))
                          (:paip::show-words (:paip::eliza (:paip::ws "i need a vacation")))
                          (:paip::show-words (:paip::eliza (:paip::ws "well i need a long holiday")))
                          (:paip::show-words (:paip::eliza (:paip::ws "i am feeling sad")))
                          (:paip::show-words (:paip::eliza (:paip::ws "hello there")))
                          (:paip::show-words (:paip::eliza (:paip::ws "the weather is fine"))))))
