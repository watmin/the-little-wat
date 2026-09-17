;; PAIP chapter 21 (a grammar of English), in wat.
;;
;; Chapter 19 (C-090) showed ambiguity and chapter 20 showed agreement. This one shows the two
;; things a toy grammar always gets wrong:
;;
;;   SUBCATEGORIZATION  a verb takes the complements it takes and no others. The lexicon carries
;;                      each verb's subcategory, so the grammar never names a verb:
;;                        "the dog slept"                  accepted
;;                        "the dog slept the bone"         REJECTED  (intransitive, given an object)
;;                        "the man saw"                    REJECTED  (transitive, given none)
;;                        "the man gave the dog"           REJECTED  (ditransitive, given one)
;;                        "the man gave the dog the bone"  accepted
;;   RELATIVE CLAUSES   a noun phrase can contain a sentence, so the grammar is recursive through
;;                      itself -- and the embedded clause obeys subcategorization too:
;;                        "the man that saw the dog that barked slept"  accepted (two levels)
;;                        "the dog that slept the bone slept"           REJECTED
;;
;; **One honest note about ambiguity.** This grammar attaches a prepositional phrase only INSIDE a
;; noun phrase, so "the man saw the dog in the park" has exactly **one** parse here, where chapter
;; 19's grammar -- which also had `VP -> V NP PP` -- gave it two. Ambiguity is a property of the
;; grammar, not of English, and the chapter records the count rather than implying the reverse.
;;
;; Nothing in wat is stressed. What is worth recording is what the port does NOT need: the whole
;; grammar is five mutually recursive functions over an index into the sentence, and wat took the
;; mutual recursion without a forward declaration or a fixpoint -- which C-061 already noted for
;; `Val`/`Env` and is by now simply true.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch21-english-grammar.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch21-english-grammar.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Words (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::typealias :paip::Pos (:wat::core::Vector :- [:wat::core::i64]))

;; the lexicon carries each verb's SUBCATEGORY, so the grammar need not name verbs at all
(:wat::core::defn :paip::cat-of [word <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::or (:wat::core::= word "the") (:wat::core::= word "a")) "D"
    (:wat::core::if (:wat::core::or (:wat::core::= word "man")
                      (:wat::core::or (:wat::core::= word "dog")
                        (:wat::core::or (:wat::core::= word "bone") (:wat::core::= word "park")))) "N"
      (:wat::core::if (:wat::core::or (:wat::core::= word "slept") (:wat::core::= word "barked")) "V-intrans"
        (:wat::core::if (:wat::core::or (:wat::core::= word "saw") (:wat::core::= word "chased")) "V-trans"
          (:wat::core::if (:wat::core::= word "gave") "V-ditrans"
            (:wat::core::if (:wat::core::= word "that") "Rel"
              (:wat::core::if (:wat::core::or (:wat::core::= word "in") (:wat::core::= word "with")) "P"
                ""))))))))

(:wat::core::defn :paip::p-word [cat <- :wat::core::String w <- :paip::Words pos <- :wat::core::i64] -> :paip::Pos
  (:wat::core::if (:wat::core::and (:wat::core::< pos (:wat::core::length w))
                    (:wat::core::= (:paip::cat-of (:wat::core::nth w pos)) cat))
    (:wat::core::Vector :- [:wat::core::i64] (:wat::core::+ pos 1))
    (:wat::core::Vector :- [:wat::core::i64])))

;; flat-map a position set through a parser
(:wat::core::defn :paip::through
  [ps <- :paip::Pos i <- :wat::core::i64 w <- :paip::Words f <- [:paip::Words :wat::core::i64 :-> :paip::Pos]
   acc <- :paip::Pos] -> :paip::Pos
  (:wat::core::if (:wat::core::>= i (:wat::core::length ps)) acc
    (:paip::through ps (:wat::core::+ i 1) w f
      (:wat::core::concat acc (f w (:wat::core::nth ps i))))))

;; NP -> D N | D N RelClause | D N PP
(:wat::core::defn :paip::p-np [w <- :paip::Words pos <- :wat::core::i64] -> :paip::Pos
  (:paip::np-after (:paip::through (:paip::p-word "D" w pos) 0 w
                     (:wat::core::fn [w2 <- :paip::Words p <- :wat::core::i64] -> :paip::Pos
                       (:paip::p-word "N" w2 p))
                     (:wat::core::Vector :- [:wat::core::i64]))
    0 w (:wat::core::Vector :- [:wat::core::i64])))

;; after "D N" the noun phrase may simply stop, or continue with a relative clause or a PP
(:wat::core::defn :paip::np-after [ps <- :paip::Pos i <- :wat::core::i64 w <- :paip::Words acc <- :paip::Pos] -> :paip::Pos
  (:wat::core::if (:wat::core::>= i (:wat::core::length ps)) acc
    (:wat::core::let [p (:wat::core::nth ps i)]
      (:paip::np-after ps (:wat::core::+ i 1) w
        (:wat::core::concat acc
          (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] p)
            (:wat::core::concat (:paip::p-rel w p) (:paip::p-pp w p))))))))

;; Rel -> "that" VP: a relative clause is a VP with the noun as its subject
(:wat::core::defn :paip::p-rel [w <- :paip::Words pos <- :wat::core::i64] -> :paip::Pos
  (:paip::through (:paip::p-word "Rel" w pos) 0 w :paip::p-vp (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :paip::p-pp [w <- :paip::Words pos <- :wat::core::i64] -> :paip::Pos
  (:paip::through (:paip::p-word "P" w pos) 0 w :paip::p-np (:wat::core::Vector :- [:wat::core::i64])))

;; the verb's subcategory decides what may follow it, and nothing else does
(:wat::core::defn :paip::p-vp [w <- :paip::Words pos <- :wat::core::i64] -> :paip::Pos
  (:wat::core::concat (:paip::p-word "V-intrans" w pos)
    (:wat::core::concat
      (:paip::through (:paip::p-word "V-trans" w pos) 0 w :paip::p-np (:wat::core::Vector :- [:wat::core::i64]))
      (:paip::through
        (:paip::through (:paip::p-word "V-ditrans" w pos) 0 w :paip::p-np (:wat::core::Vector :- [:wat::core::i64]))
        0 w :paip::p-np (:wat::core::Vector :- [:wat::core::i64])))))

(:wat::core::defn :paip::p-s [w <- :paip::Words pos <- :wat::core::i64] -> :paip::Pos
  (:paip::through (:paip::p-np w pos) 0 w :paip::p-vp (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :paip::complete [w <- :paip::Words] -> :paip::Pos
  (:wat::core::filterv (:wat::core::fn [p <- :wat::core::i64] -> :wat::core::bool
                         (:wat::core::= p (:wat::core::length w)))
    (:paip::p-s w 0)))

(:wat::core::defn :paip::ok? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::not (:wat::core::empty? (:paip::complete (:wat::string::split s " ")))))

(:wat::core::defn :paip::count-of [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::length (:paip::complete (:wat::string::split s " "))))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:paip::check-chapter "oracle/paip/ch21-english-grammar.expected"
                          "paip ch21 english grammar"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:paip::b (:paip::ok? "the dog slept"))
                            (:paip::b (:paip::ok? "the man saw the dog"))
                            (:paip::b (:paip::ok? "the man gave the dog the bone"))
                            ;; an intransitive verb given an object
                            (:paip::b (:paip::ok? "the dog slept the bone"))
                            ;; a transitive verb given none
                            (:paip::b (:paip::ok? "the man saw"))
                            ;; a ditransitive verb given only one, and given three
                            (:paip::b (:paip::ok? "the man gave the dog"))
                            (:paip::b (:paip::ok? "the man gave the dog the bone the park"))
                            ;; relative clauses
                            (:paip::b (:paip::ok? "the dog that barked slept"))
                            (:paip::b (:paip::ok? "the man that saw the dog slept"))
                            (:paip::b (:paip::ok? "the man that saw the dog that barked slept"))
                            ;; the embedded clause obeys subcategorization too
                            (:paip::b (:paip::ok? "the dog that slept the bone slept"))
                            (:paip::b (:paip::ok? "the man in the park slept"))
                            (int (:paip::count-of "the man saw the dog in the park"))
                            (:paip::b (:wat::core::> (:paip::count-of "the man saw the dog in the park") 1))
                            (int (:paip::count-of "the dog slept"))))))
