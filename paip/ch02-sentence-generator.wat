;; PAIP chapter 2 (a simple Lisp program: the sentence generator), in wat.
;;
;; The chapter's lesson is that the GRAMMAR IS DATA: adding a rule adds sentences without touching
;; the generator. It does two things with that grammar -- generate ONE sentence at random, and
;; GENERATE-ALL, enumerating the whole finite language.
;;
;; The first is where wat is missing something, and the chapter walks straight into it:
;;
;;   **F-036 — there are no random numbers, not even a seeded generator.**
;;
;; Nothing in `:wat::` produces one (`random::int`, `rand::int`, `core::random`, `math::random`
;; are all unresolved; `grep -r rand wat-rs/src wat-rs/wat` finds nothing but an unrelated rete
;; name). So the generator below drives a hand-written linear congruential generator, and so does
;; the Scheme oracle, which is the only way the two can be compared at all.
;;
;; That turns out to be worth more than a complaint. Threading the seed makes `generate` a
;; FUNCTION -- the same seed gives the same sentence, checked below -- where Norvig's version is
;; an effect on a hidden generator and cannot be tested that way. wat's missing primitive forced
;; the better testable shape. What it costs is that a user wanting an unpredictable sentence has
;; nowhere to get the seed: `:wat::uuid::v4` exists, but turning one into an integer is not a
;; route anything documents. The ask stands.
;;
;; `generate-all` needs no randomness and is the stronger test of the grammar: 2 articles x 4
;; nouns x 4 verbs x 2 articles x 4 nouns = 256 sentences, every one five words long.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch02-sentence-generator.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch02-sentence-generator.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Words (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::typealias :paip::Rules (:wat::core::Vector :- [:paip::Words]))
(:wat::core::typealias :paip::Sentences (:wat::core::Vector :- [:paip::Words]))

;; ---- the LCG that stands in for F-036's missing primitive
(:wat::core::defn :paip::lcg-next [seed <- :wat::core::i64] -> :wat::core::i64
  (:wat::i64::rem (:wat::core::+ (:wat::core::* 1103515245 seed) 12345) 2147483648))

(:wat::core::defn :paip::lcg-pick [seed <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::i64::rem (:wat::i64::quot seed 65536) n))

;; ---- the grammar, as data
(:wat::core::defn :paip::w [s <- :wat::core::String] -> :paip::Words
  (:wat::core::Vector :- [:wat::core::String] s))

(:wat::core::defn :paip::w2 [a <- :wat::core::String b <- :wat::core::String] -> :paip::Words
  (:wat::core::Vector :- [:wat::core::String] a b))

(:wat::core::defn :paip::rules-for [cat <- :wat::core::String] -> :paip::Rules
  (:wat::core::if (:wat::core::= cat "sentence")
    (:wat::core::Vector :- [:paip::Words] (:paip::w2 "noun-phrase" "verb-phrase"))
    (:wat::core::if (:wat::core::= cat "noun-phrase")
      (:wat::core::Vector :- [:paip::Words] (:paip::w2 "Article" "Noun"))
      (:wat::core::if (:wat::core::= cat "verb-phrase")
        (:wat::core::Vector :- [:paip::Words] (:paip::w2 "Verb" "noun-phrase"))
        (:wat::core::if (:wat::core::= cat "Article")
          (:wat::core::Vector :- [:paip::Words] (:paip::w "the") (:paip::w "a"))
          (:wat::core::if (:wat::core::= cat "Noun")
            (:wat::core::Vector :- [:paip::Words] (:paip::w "man") (:paip::w "ball")
                                                  (:paip::w "woman") (:paip::w "table"))
            (:wat::core::if (:wat::core::= cat "Verb")
              (:wat::core::Vector :- [:paip::Words] (:paip::w "hit") (:paip::w "took")
                                                    (:paip::w "saw") (:paip::w "liked"))
              (:wat::core::Vector :- [:paip::Words]))))))))

(:wat::core::defn :paip::category? [x <- :wat::core::String] -> :wat::core::bool
  (:wat::core::not (:wat::core::empty? (:paip::rules-for x))))

;; ---- generate one sentence. The seed is THREADED, so this is a function of (symbol, seed).
(:wat::core::defenum :paip::Gen :wat::enum::Pure
  :G [words <- :paip::Words  seed <- :wat::core::i64])

(:wat::core::defn :paip::generate [x <- :wat::core::String seed <- :wat::core::i64] -> :paip::Gen
  (:wat::core::if (:paip::category? x)
    (:wat::core::let [rs (:paip::rules-for x)
                      s1 (:paip::lcg-next seed)
                      choice (:wat::core::nth rs (:paip::lcg-pick s1 (:wat::core::length rs)))]
      (:paip::generate-list choice 0 s1 (:wat::core::Vector :- [:wat::core::String])))
    (:paip::Gen.G {:words (:paip::w x) :seed seed})))

(:wat::core::defn :paip::generate-list
  [xs <- :paip::Words i <- :wat::core::i64 seed <- :wat::core::i64 acc <- :paip::Words] -> :paip::Gen
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs)) (:paip::Gen.G {:words acc :seed seed})
    (:wat::core::match (:paip::generate (:wat::core::nth xs i) seed)
      [:paip::Gen.G {:words ws :seed s2}
        (:paip::generate-list xs (:wat::core::+ i 1) s2 (:wat::core::concat acc ws))])))

;; ---- generate-all: every sentence the grammar admits, no randomness needed
(:wat::core::defn :paip::combine-all [xs <- :paip::Sentences ys <- :paip::Sentences] -> :paip::Sentences
  (:paip::combine-from xs ys 0 (:wat::core::Vector :- [:paip::Words])))

(:wat::core::defn :paip::combine-from
  [xs <- :paip::Sentences ys <- :paip::Sentences j <- :wat::core::i64 acc <- :paip::Sentences] -> :paip::Sentences
  (:wat::core::if (:wat::core::>= j (:wat::core::length ys)) acc
    (:paip::combine-from xs ys (:wat::core::+ j 1)
      (:paip::append-each xs (:wat::core::nth ys j) 0 acc))))

(:wat::core::defn :paip::append-each
  [xs <- :paip::Sentences y <- :paip::Words i <- :wat::core::i64 acc <- :paip::Sentences] -> :paip::Sentences
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs)) acc
    (:paip::append-each xs y (:wat::core::+ i 1)
      (:wat::core::conj acc (:wat::core::concat (:wat::core::nth xs i) y)))))

(:wat::core::defn :paip::generate-all [x <- :wat::core::String] -> :paip::Sentences
  (:wat::core::if (:paip::category? x)
    (:paip::all-rules (:paip::rules-for x) 0 (:wat::core::Vector :- [:paip::Words]))
    (:wat::core::Vector :- [:paip::Words] (:paip::w x))))

(:wat::core::defn :paip::all-rules [rs <- :paip::Rules i <- :wat::core::i64 acc <- :paip::Sentences] -> :paip::Sentences
  (:wat::core::if (:wat::core::>= i (:wat::core::length rs)) acc
    (:paip::all-rules rs (:wat::core::+ i 1)
      (:wat::core::concat acc (:paip::generate-all-list (:wat::core::nth rs i) 0)))))

(:wat::core::defn :paip::generate-all-list [xs <- :paip::Words i <- :wat::core::i64] -> :paip::Sentences
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    (:wat::core::Vector :- [:paip::Words] (:wat::core::Vector :- [:wat::core::String]))
    (:paip::combine-all (:paip::generate-all (:wat::core::nth xs i))
                        (:paip::generate-all-list xs (:wat::core::+ i 1)))))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :paip::show-words [ws <- :paip::Words] -> :wat::core::String
  (:wat::string::concat "(" (:wat::string::join " " ws) ")"))

(:wat::core::defn :paip::show-sentences [ss <- :paip::Sentences] -> :wat::core::String
  (:wat::string::concat "(" (:wat::string::join " " (:wat::core::mapv :paip::show-words ss)) ")"))

(:wat::core::defn :paip::gen-words [x <- :wat::core::String seed <- :wat::core::i64] -> :paip::Words
  (:wat::core::match (:paip::generate x seed) [:paip::Gen.G {:words ws :seed s} ws]))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :paip::same-words? [a <- :paip::Words b <- :paip::Words] -> :wat::core::bool
  (:wat::core::= (:paip::show-words a) (:paip::show-words b)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:paip::check-chapter "oracle/paip/ch02-sentence-generator.expected"
                          "paip ch02 sentence generator"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:paip::show-words (:paip::gen-words "sentence" 1))
                            (:paip::show-words (:paip::gen-words "sentence" 2))
                            (:paip::show-words (:paip::gen-words "sentence" 3))
                            (:paip::show-words (:paip::gen-words "sentence" 12345))
                            ;; the same seed gives the same sentence: a function, not an effect
                            (:paip::b (:paip::same-words? (:paip::gen-words "sentence" 7)
                                                          (:paip::gen-words "sentence" 7)))
                            (:paip::show-words (:paip::gen-words "noun-phrase" 99))
                            (:paip::show-words (:paip::gen-words "Verb" 5))
                            (int (:wat::core::length (:paip::generate-all "Article")))
                            (int (:wat::core::length (:paip::generate-all "Noun")))
                            (int (:wat::core::length (:paip::generate-all "noun-phrase")))
                            (int (:wat::core::length (:paip::generate-all "sentence")))
                            (:paip::show-sentences (:paip::generate-all "Article"))
                            (:paip::show-words (:wat::core::nth (:paip::generate-all "noun-phrase") 0))
                            (:paip::show-words (:wat::core::nth (:paip::generate-all "sentence") 0))
                            (:paip::b (:wat::core::= (:wat::core::length (:paip::generate-all "sentence")) 256))
                            (int (:wat::core::length (:wat::core::nth (:paip::generate-all "sentence") 0)))))))
