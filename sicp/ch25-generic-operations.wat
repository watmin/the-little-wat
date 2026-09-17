;; SICP §2.5 (systems with generic operations), in wat.
;;
;; One `add` and one `mul` over integers, rationals and complex numbers, with a TOWER of types --
;; int below rat below complex -- and coercion by RAISING an operand up the tower until the two
;; meet. The tower is the section's actual idea: it keeps the number of rules linear in the number
;; of types instead of quadratic in the number of PAIRS of types.
;;
;; What the port changes, and it is the chapter's own argument arriving from the other side:
;;
;;   SICP's dispatch table is open. Any package may `put` a new (operation, type) entry, and
;;   nothing anywhere records that it did. That is the freedom the section is selling, and the
;;   reason `apply-generic` has to end in an error for the case where no entry was ever put.
;;
;;   wat's `Num` is a closed enum, so `add-same` is checked EXHAUSTIVE and `raise-1` is checked
;;   exhaustive, and adding a fourth level is a compile error at every site that must learn about
;;   it -- which is precisely the list of sites SICP asks you to remember by hand. The freedom is
;;   gone; so is the class of bug the section spends its last pages on (§2.5.2's "coercion is not
;;   a table you can complete").
;;
;; Neither is better in general. What is worth recording is that the tower survives intact either
;; way -- `raise-to` and `level` are unchanged from the Scheme, and only the dispatch beneath them
;; differs.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch25-generic-operations.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order. guile's `write` quotes strings.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch25-generic-operations.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defn :sicp::my-gcd [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= b 0) a (:sicp::my-gcd b (:wat::i64::rem a b))))

(:wat::core::defn :sicp::iabs [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< n 0) (:wat::core::- 0 n) n))

;; the tower, as a closed enum
(:wat::core::defenum :sicp::Num :wat::enum::Pure
  :Int     [n <- :wat::core::i64]
  :Rat     [n <- :wat::core::i64  d <- :wat::core::i64]
  :Complex [re <- :wat::core::i64  im <- :wat::core::i64])

(:wat::core::defn :sicp::make-rat [n <- :wat::core::i64 d <- :wat::core::i64] -> :sicp::Num
  (:wat::core::let [g (:sicp::my-gcd (:sicp::iabs n) (:sicp::iabs d))
                    s (:wat::core::if (:wat::core::< (:wat::core::* n d) 0) -1 1)]
    (:sicp::Num.Rat {:n (:wat::core::* s (:wat::i64::quot (:sicp::iabs n) g))
                     :d (:wat::i64::quot (:sicp::iabs d) g)})))

(:wat::core::defn :sicp::level [x <- :sicp::Num] -> :wat::core::i64
  (:wat::core::match x
    [:sicp::Num.Int {:n n} 0]
    [:sicp::Num.Rat {:n n :d d} 1]
    [:sicp::Num.Complex {:re re :im im} 2]))

;; one level up, and no further -- exhaustive, so a fourth level would be a compile error here
(:wat::core::defn :sicp::raise-1 [x <- :sicp::Num] -> :sicp::Num
  (:wat::core::match x
    [:sicp::Num.Int {:n n} (:sicp::make-rat n 1)]
    [:sicp::Num.Rat {:n n :d d} (:sicp::Num.Complex {:re (:wat::i64::quot n d) :im 0})]
    [:sicp::Num.Complex {:re re :im im} x]))

(:wat::core::defn :sicp::raise-to [x <- :sicp::Num n <- :wat::core::i64] -> :sicp::Num
  (:wat::core::if (:wat::core::>= (:sicp::level x) n) x (:sicp::raise-to (:sicp::raise-1 x) n)))

;; ---- the rules for two operands already at the same level
(:wat::core::defn :sicp::add-same [a <- :sicp::Num b <- :sicp::Num] -> :sicp::Num
  (:wat::core::match a
    [:sicp::Num.Int {:n an}
      (:wat::core::match b
        [:sicp::Num.Int {:n bn} (:sicp::Num.Int {:n (:wat::core::+ an bn)})]
        [:sicp::Num.Rat {:n bn :d bd} a]
        [:sicp::Num.Complex {:re bre :im bim} a])]
    [:sicp::Num.Rat {:n an :d ad}
      (:wat::core::match b
        [:sicp::Num.Rat {:n bn :d bd}
          (:sicp::make-rat (:wat::core::+ (:wat::core::* an bd) (:wat::core::* bn ad))
                           (:wat::core::* ad bd))]
        [:sicp::Num.Int {:n bn} a]
        [:sicp::Num.Complex {:re bre :im bim} a])]
    [:sicp::Num.Complex {:re are :im aim}
      (:wat::core::match b
        [:sicp::Num.Complex {:re bre :im bim}
          (:sicp::Num.Complex {:re (:wat::core::+ are bre) :im (:wat::core::+ aim bim)})]
        [:sicp::Num.Int {:n bn} a]
        [:sicp::Num.Rat {:n bn :d bd} a])]))

(:wat::core::defn :sicp::mul-same [a <- :sicp::Num b <- :sicp::Num] -> :sicp::Num
  (:wat::core::match a
    [:sicp::Num.Int {:n an}
      (:wat::core::match b
        [:sicp::Num.Int {:n bn} (:sicp::Num.Int {:n (:wat::core::* an bn)})]
        [:sicp::Num.Rat {:n bn :d bd} a]
        [:sicp::Num.Complex {:re bre :im bim} a])]
    [:sicp::Num.Rat {:n an :d ad}
      (:wat::core::match b
        [:sicp::Num.Rat {:n bn :d bd}
          (:sicp::make-rat (:wat::core::* an bn) (:wat::core::* ad bd))]
        [:sicp::Num.Int {:n bn} a]
        [:sicp::Num.Complex {:re bre :im bim} a])]
    [:sicp::Num.Complex {:re are :im aim}
      (:wat::core::match b
        [:sicp::Num.Complex {:re bre :im bim}
          (:sicp::Num.Complex {:re (:wat::core::- (:wat::core::* are bre) (:wat::core::* aim bim))
                               :im (:wat::core::+ (:wat::core::* are bim) (:wat::core::* aim bre))})]
        [:sicp::Num.Int {:n bn} a]
        [:sicp::Num.Rat {:n bn :d bd} a])]))

(:wat::core::defn :sicp::imax [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))

;; ---- generic: raise both to the higher level, then use that level's rule
(:wat::core::defn :sicp::generic-add [a <- :sicp::Num b <- :sicp::Num] -> :sicp::Num
  (:wat::core::let [n (:sicp::imax (:sicp::level a) (:sicp::level b))]
    (:sicp::add-same (:sicp::raise-to a n) (:sicp::raise-to b n))))

(:wat::core::defn :sicp::generic-mul [a <- :sicp::Num b <- :sicp::Num] -> :sicp::Num
  (:wat::core::let [n (:sicp::imax (:sicp::level a) (:sicp::level b))]
    (:sicp::mul-same (:sicp::raise-to a n) (:sicp::raise-to b n))))

;; ---- printing, as the Scheme oracle prints (guile's `write` quotes strings)
(:wat::core::defn :sicp::q [s <- :wat::core::String] -> :wat::core::String
  (:wat::string::concat "\"" s "\""))

(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::show-num [x <- :sicp::Num] -> :wat::core::String
  (:sicp::q (:wat::core::match x
              [:sicp::Num.Int {:n n} (:wat::i64::to-string n)]
              [:sicp::Num.Rat {:n n :d d}
                (:wat::string::concat (:wat::i64::to-string n) "/" (:wat::i64::to-string d))]
              [:sicp::Num.Complex {:re re :im im}
                (:wat::string::concat (:wat::i64::to-string re) "+" (:wat::i64::to-string im) "i")])))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))
                    i7 (:sicp::Num.Int {:n 7})
                    i1 (:sicp::Num.Int {:n 1})
                    i2 (:sicp::Num.Int {:n 2})
                    i3 (:sicp::Num.Int {:n 3})
                    i4 (:sicp::Num.Int {:n 4})
                    half (:sicp::make-rat 1 2)
                    third (:sicp::make-rat 1 3)
                    c12 (:sicp::Num.Complex {:re 1 :im 2})
                    c34 (:sicp::Num.Complex {:re 3 :im 4})
                    c00 (:sicp::Num.Complex {:re 0 :im 0})]
    (:sicp::check-chapter "oracle/sicp/ch25-generic-operations.expected"
                          "sicp ch25 generic operations"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::show-num i7)
                            (:sicp::show-num (:sicp::make-rat 6 9))
                            (:sicp::show-num c34)
                            (:sicp::show-num (:sicp::raise-1 i7))
                            (:sicp::show-num (:sicp::raise-1 (:sicp::raise-1 i7)))
                            (int (:sicp::level i1))
                            (int (:sicp::level half))
                            (int (:sicp::level (:sicp::Num.Complex {:re 1 :im 1})))
                            (:sicp::show-num (:sicp::generic-add i3 i4))
                            (:sicp::show-num (:sicp::generic-mul i3 i4))
                            (:sicp::show-num (:sicp::generic-add half third))
                            (:sicp::show-num (:sicp::generic-mul half (:sicp::make-rat 2 3)))
                            (:sicp::show-num (:sicp::generic-add c12 c34))
                            (:sicp::show-num (:sicp::generic-mul c12 c34))
                            (:sicp::show-num (:sicp::generic-add i1 half))
                            (:sicp::show-num (:sicp::generic-add half i1))
                            (:sicp::show-num (:sicp::generic-add i1 c34))
                            (:sicp::show-num (:sicp::generic-mul i2 (:sicp::make-rat 3 4)))
                            (:sicp::b (:wat::core::= 3 3))
                            (int (:sicp::level (:sicp::generic-add i1 c00)))))))
