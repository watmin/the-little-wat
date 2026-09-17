;; PAIP chapter 20 (unification grammars), in wat.
;;
;; A grammar whose categories carry FEATURES, unified as the parse is built, so agreement is
;; enforced by the grammar rather than by extra rules. A category is `(name number)` where number
;; is `sg`, `pl`, the variable `?n`, or `*` for a fresh independent scope; a rule shares a variable
;; between its parts -- `S(?n) -> NP(?n) VP(?n)` -- so:
;;
;;     "the-sg man sees"                accepted        "the-sg man see"     rejected
;;     "the-pl men see"                 accepted        "the-pl men sees"    rejected
;;     "the-sg men sees"                rejected        (disagreement INSIDE the noun phrase)
;;     "the-sg man sees the-pl men"     accepted        (the object's number is independent)
;;     "the-sg man see the-pl men"      rejected        (the subject must still agree)
;;
;; The contrast with chapter 19 (C-090) is the chapter's whole argument: a plain CFG needs every
;; rule **twice**, once per number, and the count multiplies with every feature added.
;;
;; **The wat note is that the binding needs three states, not two**, and the type says so.
;; `Undecided` is not `Is("sg")` and neither is `Fail` -- a sentence whose number has not yet been
;; pinned is a different thing from one that is singular and from one that cannot be parsed. An
;; `Option<String>` would carry two of the three and force the third into a sentinel. That is the
;; fourth chapter in this repository where the same pressure appeared (ELIZA's `Fail` against
;; "matched with no bindings", C-083; STUDENT's `unbound`, C-085; ch19's empty-vector-means-
;; ungrammatical, C-090), and wat's enums answered it every time without a sentinel.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch20-unification-grammar.scm, run
;; by tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch20-unification-grammar.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Words (:wat::core::Vector :- [:wat::core::String]))

;; three states, and the type says so
(:wat::core::defenum :paip::Bnd :wat::enum::Pure
  :Undecided []
  :Is        [num <- :wat::core::String]
  :BFail     [])

(:wat::core::defstruct :paip::Cat [name <- :wat::core::String  num <- :wat::core::String])
(:wat::core::typealias :paip::Cats (:wat::core::Vector :- [:paip::Cat]))
(:wat::core::defstruct :paip::GRule [lhs <- :paip::Cat  rhs <- :paip::Cats])
(:wat::core::typealias :paip::GRules (:wat::core::Vector :- [:paip::GRule]))

;; a parse state: where the input continues, and what the number has been pinned to
(:wat::core::defenum :paip::PSt :wat::enum::Pure
  :P [next <- :wat::core::i64  bnd <- :paip::Bnd])

(:wat::core::typealias :paip::PSts (:wat::core::Vector :- [:paip::PSt]))

(:wat::core::defn :paip::var? [x <- :wat::core::String] -> :wat::core::bool (:wat::core::= x "?n"))

(:wat::core::defn :paip::unify-num [a <- :wat::core::String b <- :wat::core::String bnd <- :paip::Bnd] -> :paip::Bnd
  (:wat::core::match bnd
    [:paip::Bnd.BFail {} bnd]
    [:paip::Bnd.Undecided {}
      (:wat::core::if (:wat::core::and (:paip::var? a) (:paip::var? b)) bnd
        (:wat::core::if (:paip::var? a) (:paip::Bnd.Is {:num b})
          (:wat::core::if (:paip::var? b) (:paip::Bnd.Is {:num a})
            (:wat::core::if (:wat::core::= a b) bnd (:paip::Bnd.BFail {})))))]
    [:paip::Bnd.Is {:num n}
      (:wat::core::if (:wat::core::and (:paip::var? a) (:paip::var? b)) bnd
        (:wat::core::if (:paip::var? a)
          (:wat::core::if (:wat::core::= n b) bnd (:paip::Bnd.BFail {}))
          (:wat::core::if (:paip::var? b)
            (:wat::core::if (:wat::core::= n a) bnd (:paip::Bnd.BFail {}))
            (:wat::core::if (:wat::core::= a b) bnd (:paip::Bnd.BFail {})))))]))

;; ---- the grammar. The two determiners are spelled differently so that the GRAMMAR, not the
;; spelling, is what decides; a single "the" would be ambiguous and hide the point.
(:wat::core::defn :paip::c [n <- :wat::core::String num <- :wat::core::String] -> :paip::Cat
  (:paip::Cat :name n :num num))

(:wat::core::defn :paip::rule [lhs <- :paip::Cat rhs <- :paip::Cats] -> :paip::GRule
  (:paip::GRule :lhs lhs :rhs rhs))

(:wat::core::defn :paip::grammar [] -> :paip::GRules
  (:wat::core::Vector :- [:paip::GRule]
    (:paip::rule (:paip::c "S" "?n")
      (:wat::core::Vector :- [:paip::Cat] (:paip::c "NP" "?n") (:paip::c "VP" "?n")))
    (:paip::rule (:paip::c "NP" "?n")
      (:wat::core::Vector :- [:paip::Cat] (:paip::c "D" "?n") (:paip::c "N" "?n")))
    ;; `*` marks the object's number as a FRESH, independent scope
    (:paip::rule (:paip::c "VP" "?n")
      (:wat::core::Vector :- [:paip::Cat] (:paip::c "V" "?n") (:paip::c "NP" "*")))
    (:paip::rule (:paip::c "VP" "?n")
      (:wat::core::Vector :- [:paip::Cat] (:paip::c "V" "?n")))
    (:paip::rule (:paip::c "D" "sg") (:wat::core::Vector :- [:paip::Cat] (:paip::c "the-sg" "?n")))
    (:paip::rule (:paip::c "D" "pl") (:wat::core::Vector :- [:paip::Cat] (:paip::c "the-pl" "?n")))
    (:paip::rule (:paip::c "N" "sg") (:wat::core::Vector :- [:paip::Cat] (:paip::c "man" "?n")))
    (:paip::rule (:paip::c "N" "pl") (:wat::core::Vector :- [:paip::Cat] (:paip::c "men" "?n")))
    (:paip::rule (:paip::c "V" "sg") (:wat::core::Vector :- [:paip::Cat] (:paip::c "sees" "?n")))
    (:paip::rule (:paip::c "V" "pl") (:wat::core::Vector :- [:paip::Cat] (:paip::c "see" "?n")))))

(:wat::core::defn :paip::rules-for [name <- :wat::core::String] -> :paip::GRules
  (:wat::core::filterv (:wat::core::fn [r <- :paip::GRule] -> :wat::core::bool
                         (:wat::core::= name (:paip::Cat/name (:paip::GRule/lhs r)))) (:paip::grammar)))

(:wat::core::defn :paip::terminal? [name <- :wat::core::String] -> :wat::core::bool
  (:wat::core::empty? (:paip::rules-for name)))

;; ---- the parser
(:wat::core::defn :paip::gparse [cat <- :paip::Cat w <- :paip::Words pos <- :wat::core::i64 bnd <- :paip::Bnd] -> :paip::PSts
  (:wat::core::match bnd
    [:paip::Bnd.BFail {} (:wat::core::Vector :- [:paip::PSt])]
    [:paip::Bnd.Undecided {} (:paip::gparse-ok cat w pos bnd)]
    [:paip::Bnd.Is {:num n} (:paip::gparse-ok cat w pos bnd)]))

(:wat::core::defn :paip::gparse-ok [cat <- :paip::Cat w <- :paip::Words pos <- :wat::core::i64 bnd <- :paip::Bnd] -> :paip::PSts
  (:wat::core::let [name (:paip::Cat/name cat)]
    ;; `*` starts a FRESH binding scope, and whatever it settles on is discarded afterwards
    (:wat::core::if (:wat::core::= (:paip::Cat/num cat) "*")
      (:wat::core::mapv (:wat::core::fn [p <- :paip::PSt] -> :paip::PSt
                          (:wat::core::match p [:paip::PSt.P {:next n :bnd b} (:paip::PSt.P {:next n :bnd bnd})]))
        (:paip::gparse (:paip::c name "?n") w pos (:paip::Bnd.Undecided {})))
      (:wat::core::if (:paip::terminal? name)
        (:wat::core::if (:wat::core::and (:wat::core::< pos (:wat::core::length w))
                          (:wat::core::= (:wat::core::nth w pos) name))
          (:wat::core::Vector :- [:paip::PSt] (:paip::PSt.P {:next (:wat::core::+ pos 1) :bnd bnd}))
          (:wat::core::Vector :- [:paip::PSt]))
        (:paip::try-rules cat (:paip::rules-for name) 0 w pos bnd (:wat::core::Vector :- [:paip::PSt]))))))

(:wat::core::defn :paip::try-rules
  [cat <- :paip::Cat rs <- :paip::GRules i <- :wat::core::i64 w <- :paip::Words pos <- :wat::core::i64
   bnd <- :paip::Bnd acc <- :paip::PSts] -> :paip::PSts
  (:wat::core::if (:wat::core::>= i (:wat::core::length rs)) acc
    (:wat::core::let [r (:wat::core::nth rs i)
                      b2 (:paip::unify-num (:paip::Cat/num cat) (:paip::Cat/num (:paip::GRule/lhs r)) bnd)]
      (:paip::try-rules cat rs (:wat::core::+ i 1) w pos bnd
        (:wat::core::concat acc
          (:wat::core::match b2
            [:paip::Bnd.BFail {} (:wat::core::Vector :- [:paip::PSt])]
            [:paip::Bnd.Undecided {} (:paip::gparse-seq (:paip::GRule/rhs r) 0 w pos b2)]
            [:paip::Bnd.Is {:num n} (:paip::gparse-seq (:paip::GRule/rhs r) 0 w pos b2)]))))))

(:wat::core::defn :paip::gparse-seq [cats <- :paip::Cats i <- :wat::core::i64 w <- :paip::Words
                                     pos <- :wat::core::i64 bnd <- :paip::Bnd] -> :paip::PSts
  (:wat::core::if (:wat::core::>= i (:wat::core::length cats))
    (:wat::core::Vector :- [:paip::PSt] (:paip::PSt.P {:next pos :bnd bnd}))
    (:paip::seq-fold cats i w (:paip::gparse (:wat::core::nth cats i) w pos bnd) 0
      (:wat::core::Vector :- [:paip::PSt]))))

(:wat::core::defn :paip::seq-fold
  [cats <- :paip::Cats i <- :wat::core::i64 w <- :paip::Words heads <- :paip::PSts k <- :wat::core::i64 acc <- :paip::PSts]
  -> :paip::PSts
  (:wat::core::if (:wat::core::>= k (:wat::core::length heads)) acc
    (:wat::core::match (:wat::core::nth heads k)
      [:paip::PSt.P {:next n :bnd b}
        (:paip::seq-fold cats i w heads (:wat::core::+ k 1)
          (:wat::core::concat acc (:paip::gparse-seq cats (:wat::core::+ i 1) w n b)))])))

(:wat::core::defn :paip::parses [w <- :paip::Words] -> :paip::PSts
  (:wat::core::filterv (:wat::core::fn [p <- :paip::PSt] -> :wat::core::bool
                         (:wat::core::match p [:paip::PSt.P {:next n :bnd b} (:wat::core::= n (:wat::core::length w))]))
    (:paip::gparse (:paip::c "S" "?n") w 0 (:paip::Bnd.Undecided {}))))

(:wat::core::defn :paip::ok? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::not (:wat::core::empty? (:paip::parses (:wat::string::split s " ")))))

(:wat::core::defn :paip::settled [s <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [ps (:paip::parses (:wat::string::split s " "))]
    (:wat::core::if (:wat::core::empty? ps) "none"
      (:wat::core::match (:wat::core::nth ps 0)
        [:paip::PSt.P {:next n :bnd b}
          (:wat::core::match b
            [:paip::Bnd.Is {:num num} num]
            [:paip::Bnd.Undecided {} "undecided"]
            [:paip::Bnd.BFail {} "fail"])]))))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    cnt (:wat::core::fn [s <- :wat::core::String] -> :wat::core::String
                          (:wat::i64::to-string (:wat::core::length (:paip::parses (:wat::string::split s " ")))))]
    (:paip::check-chapter "oracle/paip/ch20-unification-grammar.expected"
                          "paip ch20 unification grammar"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:paip::b (:paip::ok? "the-sg man sees"))
                            (:paip::b (:paip::ok? "the-pl men see"))
                            ;; subject and verb disagree
                            (:paip::b (:paip::ok? "the-sg man see"))
                            (:paip::b (:paip::ok? "the-pl men sees"))
                            ;; disagreement INSIDE the noun phrase
                            (:paip::b (:paip::ok? "the-sg men sees"))
                            (:paip::b (:paip::ok? "the-pl man see"))
                            ;; transitive: the object's number is independent
                            (:paip::b (:paip::ok? "the-sg man sees the-pl men"))
                            (:paip::b (:paip::ok? "the-pl men see the-sg man"))
                            (:paip::b (:paip::ok? "the-sg man sees the-sg man"))
                            ;; but the subject must still agree
                            (:paip::b (:paip::ok? "the-sg man see the-pl men"))
                            (cnt "the-sg man sees")
                            (cnt "the-sg man sees the-pl men")
                            (cnt "the-sg man see")
                            ;; the binding that survives says which number the sentence settled on
                            (:paip::settled "the-sg man sees")
                            (:paip::settled "the-pl men see")))))
