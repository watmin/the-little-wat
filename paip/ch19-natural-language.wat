;; PAIP chapter 19 (an introduction to natural language), in wat.
;;
;; A context-free grammar and a top-down parser that returns EVERY parse, because the interesting
;; fact about natural language is that sentences are ambiguous and a grammar cannot choose:
;;
;;     "the man saw the telescope"              1 parse
;;     "I saw the man with the telescope"       2 parses -- and the trees differ
;;     "the man saw a park in the park"         2 parses
;;     "the saw man"                            0
;;
;; The two readings of the second differ only in where the prepositional phrase attaches, and the
;; chapter checks that the trees are **not equal** rather than merely counting them — a parser that
;; returned the same tree twice would pass a count and fail that.
;;
;; **The wat note is that ambiguity is what makes the return type interesting.** A parser that
;; answers "the parse" wants an `Option`; one that answers "every parse" wants a Vector, and the
;; empty Vector then means *ungrammatical* while a one-element Vector means *unambiguous*. Those
;; are three different facts about a sentence and the type carries all three without a sentinel.
;; That is the same reason `Fail` had to be a distinct variant from "matched with no bindings" in
;; ELIZA (C-083) — it is the one design pressure this repository has now met in four chapters, and
;; wat's enums answer it every time.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch19-natural-language.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch19-natural-language.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Words (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defenum :paip::Tree :wat::enum::Pure
  :Leaf [word <- :wat::core::String]
  :Node [cat <- :wat::core::String  kids <- (:wat::core::Vector :- [:paip::Tree])])

(:wat::core::typealias :paip::Trees (:wat::core::Vector :- [:paip::Tree]))

;; one way a category can begin the input: a tree, and where the input continues
(:wat::core::defenum :paip::PR :wat::enum::Pure
  :R [tree <- :paip::Tree  next <- :wat::core::i64])

(:wat::core::typealias :paip::PRs (:wat::core::Vector :- [:paip::PR]))

;; a sequence result: the trees so far, and where the input continues
(:wat::core::defenum :paip::SR :wat::enum::Pure
  :S [trees <- :paip::Trees  next <- :wat::core::i64])

(:wat::core::typealias :paip::SRs (:wat::core::Vector :- [:paip::SR]))

;; ---- the grammar, as data
(:wat::core::typealias :paip::Rhs (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::typealias :paip::Rhss (:wat::core::Vector :- [:paip::Rhs]))

(:wat::core::defn :paip::r1 [a <- :wat::core::String] -> :paip::Rhs
  (:wat::core::Vector :- [:wat::core::String] a))
(:wat::core::defn :paip::r2 [a <- :wat::core::String b <- :wat::core::String] -> :paip::Rhs
  (:wat::core::Vector :- [:wat::core::String] a b))
(:wat::core::defn :paip::r3 [a <- :wat::core::String b <- :wat::core::String c <- :wat::core::String] -> :paip::Rhs
  (:wat::core::Vector :- [:wat::core::String] a b c))

(:wat::core::defn :paip::rules-for [cat <- :wat::core::String] -> :paip::Rhss
  (:wat::core::if (:wat::core::= cat "S") (:wat::core::Vector :- [:paip::Rhs] (:paip::r2 "NP" "VP"))
    (:wat::core::if (:wat::core::= cat "NP")
      (:wat::core::Vector :- [:paip::Rhs] (:paip::r2 "D" "N") (:paip::r3 "D" "N" "PP") (:paip::r1 "Pro"))
      (:wat::core::if (:wat::core::= cat "VP")
        (:wat::core::Vector :- [:paip::Rhs] (:paip::r2 "V" "NP") (:paip::r3 "V" "NP" "PP"))
        (:wat::core::if (:wat::core::= cat "PP") (:wat::core::Vector :- [:paip::Rhs] (:paip::r2 "P" "NP"))
          (:wat::core::if (:wat::core::= cat "D")
            (:wat::core::Vector :- [:paip::Rhs] (:paip::r1 "the") (:paip::r1 "a"))
            (:wat::core::if (:wat::core::= cat "N")
              (:wat::core::Vector :- [:paip::Rhs] (:paip::r1 "man") (:paip::r1 "telescope") (:paip::r1 "park"))
              (:wat::core::if (:wat::core::= cat "Pro") (:wat::core::Vector :- [:paip::Rhs] (:paip::r1 "I"))
                (:wat::core::if (:wat::core::= cat "V") (:wat::core::Vector :- [:paip::Rhs] (:paip::r1 "saw"))
                  (:wat::core::if (:wat::core::= cat "P")
                    (:wat::core::Vector :- [:paip::Rhs] (:paip::r1 "with") (:paip::r1 "in"))
                    (:wat::core::Vector :- [:paip::Rhs])))))))))))

(:wat::core::defn :paip::terminal? [x <- :wat::core::String] -> :wat::core::bool
  (:wat::core::empty? (:paip::rules-for x)))

;; ---- the parser
(:wat::core::defn :paip::parse [cat <- :wat::core::String w <- :paip::Words pos <- :wat::core::i64] -> :paip::PRs
  (:wat::core::if (:paip::terminal? cat)
    (:wat::core::if (:wat::core::and (:wat::core::< pos (:wat::core::length w))
                      (:wat::core::= (:wat::core::nth w pos) cat))
      (:wat::core::Vector :- [:paip::PR]
        (:paip::PR.R {:tree (:paip::Tree.Leaf {:word cat}) :next (:wat::core::+ pos 1)}))
      (:wat::core::Vector :- [:paip::PR]))
    (:paip::try-rhss cat (:paip::rules-for cat) 0 w pos (:wat::core::Vector :- [:paip::PR]))))

(:wat::core::defn :paip::try-rhss
  [cat <- :wat::core::String rs <- :paip::Rhss i <- :wat::core::i64 w <- :paip::Words pos <- :wat::core::i64
   acc <- :paip::PRs] -> :paip::PRs
  (:wat::core::if (:wat::core::>= i (:wat::core::length rs)) acc
    (:paip::try-rhss cat rs (:wat::core::+ i 1) w pos
      (:wat::core::concat acc (:paip::parse-rhs cat (:wat::core::nth rs i) w pos)))))

(:wat::core::defn :paip::parse-rhs [cat <- :wat::core::String rhs <- :paip::Rhs w <- :paip::Words pos <- :wat::core::i64] -> :paip::PRs
  (:wat::core::mapv (:wat::core::fn [sr <- :paip::SR] -> :paip::PR
                      (:wat::core::match sr
                        [:paip::SR.S {:trees ts :next n}
                          (:paip::PR.R {:tree (:paip::Tree.Node {:cat cat :kids ts}) :next n})]))
    (:paip::parse-seq rhs 0 w pos)))

;; every way a SEQUENCE of categories can begin the input
(:wat::core::defn :paip::parse-seq [rhs <- :paip::Rhs i <- :wat::core::i64 w <- :paip::Words pos <- :wat::core::i64] -> :paip::SRs
  (:wat::core::if (:wat::core::>= i (:wat::core::length rhs))
    (:wat::core::Vector :- [:paip::SR] (:paip::SR.S {:trees (:wat::core::Vector :- [:paip::Tree]) :next pos}))
    (:paip::seq-loop rhs i w (:paip::parse (:wat::core::nth rhs i) w pos) 0
      (:wat::core::Vector :- [:paip::SR]))))

(:wat::core::defn :paip::seq-loop
  [rhs <- :paip::Rhs i <- :wat::core::i64 w <- :paip::Words heads <- :paip::PRs k <- :wat::core::i64 acc <- :paip::SRs]
  -> :paip::SRs
  (:wat::core::if (:wat::core::>= k (:wat::core::length heads)) acc
    (:wat::core::match (:wat::core::nth heads k)
      [:paip::PR.R {:tree t :next n}
        (:paip::seq-loop rhs i w heads (:wat::core::+ k 1)
          (:wat::core::concat acc
            (:wat::core::mapv (:wat::core::fn [sr <- :paip::SR] -> :paip::SR
                                (:wat::core::match sr
                                  [:paip::SR.S {:trees ts :next n2}
                                    (:paip::SR.S {:trees (:wat::core::concat
                                                           (:wat::core::Vector :- [:paip::Tree] t) ts)
                                                  :next n2})]))
              (:paip::parse-seq rhs (:wat::core::+ i 1) w n))))])))

;; only the parses that consumed every word
(:wat::core::defn :paip::parses-of [w <- :paip::Words] -> :paip::PRs
  (:wat::core::filterv (:wat::core::fn [r <- :paip::PR] -> :wat::core::bool
                         (:wat::core::match r
                           [:paip::PR.R {:tree t :next n} (:wat::core::= n (:wat::core::length w))]))
    (:paip::parse "S" w 0)))

;; ---- printing
(:wat::core::defn :paip::show-tree [t <- :paip::Tree] -> :wat::core::String
  (:wat::core::match t
    [:paip::Tree.Leaf {:word x} x]
    [:paip::Tree.Node {:cat c :kids ks}
      (:wat::string::concat "(" c " "
        (:wat::string::join " " (:wat::core::mapv :paip::show-tree ks)) ")")]))

(:wat::core::defn :paip::tree-of [r <- :paip::PR] -> :wat::core::String
  (:wat::core::match r [:paip::PR.R {:tree t :next n} (:paip::show-tree t)]))

(:wat::core::defn :paip::ws [s <- :wat::core::String] -> :paip::Words (:wat::string::split s " "))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    s1 (:paip::ws "the man saw the telescope")
                    s2 (:paip::ws "I saw the man with the telescope")
                    s3 (:paip::ws "the man saw a park in the park")
                    p2 (:paip::parses-of s2)]
    (:paip::check-chapter "oracle/paip/ch19-natural-language.expected"
                          "paip ch19 natural language"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:wat::core::length (:paip::parses-of s1)))
                            (:paip::tree-of (:wat::core::nth (:paip::parses-of s1) 0))
                            ;; the classic ambiguity: two readings, and the grammar cannot choose
                            (int (:wat::core::length p2))
                            (int (:wat::core::length (:paip::parses-of s3)))
                            (int (:wat::core::length (:paip::parses-of (:paip::ws "the saw man"))))
                            (int (:wat::core::length (:paip::parses-of (:paip::ws "man"))))
                            (int (:wat::core::length (:paip::parse "NP" s1 0)))
                            (int (:wat::core::length (:paip::parse "NP" (:paip::ws "the man with the telescope") 0)))
                            (int (:wat::core::length (:paip::parse "Pro" (:paip::ws "I saw") 0)))
                            (int (:wat::core::length (:paip::parse "V" (:paip::ws "saw the man") 0)))
                            (int (:wat::core::length (:paip::parse "V" (:paip::ws "the man") 0)))
                            ;; the two readings differ: counting them is not enough
                            (:paip::b (:wat::core::= (:paip::tree-of (:wat::core::nth p2 0))
                                                     (:paip::tree-of (:wat::core::nth p2 1))))
                            (int (:wat::core::length (:paip::parse "S" s2 0)))))))
