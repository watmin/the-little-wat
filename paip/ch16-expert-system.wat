;; PAIP chapter 16 (expert systems: certainty factors), in wat.
;;
;; Certainty factors run from -100 (certainly false) to 100 (certainly true), scaled by 100 so the
;; arithmetic is exact integers and neither implementation can disagree about rounding.
;;
;; The chapter's substance is that the combining rules are deliberately **not ordinary logic**:
;; `and` is a minimum, `or` is a maximum, and combining two pieces of evidence for the SAME
;; conclusion is neither addition nor probability. Its awkward cases are what the tests press:
;;
;;   two supporting facts reinforce but never reach certainty from below it -- 90 with 90 gives
;;   **99**, not 100, and the chapter asserts `< 100`;
;;   two opposing facts reinforce downward the same way -- -50 with -50 gives **-75**;
;;   CONTRADICTORY evidence cancels toward the middle -- 70 with -70 gives **0**, and 80 with -20
;;   gives **75**, which is the rule nobody guesses right;
;;   certainty absorbs everything -- 100 with -50 is still **100**.
;;
;; **The wat observation is about the cutoff, and it is a gap in the type system rather than in the
;; language.** A certainty factor is an integer constrained to [-100, 100], and nothing in wat can
;; say so: `:wat::core::i64` admits 5000, every combining rule would silently produce nonsense from
;; it, and the only defence is that no caller writes one. This is the **newtype** question from
;; F-106 with the second half missing in a different place -- there, `newtype` gave distinctness
;; without sealing; here what is wanted is neither, but a RANGE. A language that annotates every
;; parameter has an obvious place to put `-100..100` and no way to write it.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch16-expert-system.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch16-expert-system.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defn :paip::cutoff [] -> :wat::core::i64 20)

(:wat::core::defn :paip::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))
(:wat::core::defn :paip::imax2 [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))
(:wat::core::defn :paip::iabs2 [a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a 0) (:wat::core::- 0 a) a))

(:wat::core::defn :paip::cf-and [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:paip::imin a b))
(:wat::core::defn :paip::cf-or [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:paip::imax2 a b))

;; combining two certainty factors for the SAME conclusion
(:wat::core::defn :paip::cf-combine [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::and (:wat::core::> a 0) (:wat::core::> b 0))
    ;; both support: approach 100 without reaching it
    (:wat::core::- (:wat::core::+ a b) (:wat::i64::quot (:wat::core::* a b) 100))
    (:wat::core::if (:wat::core::and (:wat::core::< a 0) (:wat::core::< b 0))
      (:wat::core::+ (:wat::core::+ a b) (:wat::i64::quot (:wat::core::* a b) 100))
      ;; contradictory: scale by how much room the weaker one leaves
      (:wat::core::let [d (:wat::core::- 100 (:paip::imin (:paip::iabs2 a) (:paip::iabs2 b)))]
        (:wat::core::if (:wat::core::= d 0) 0
          (:wat::i64::quot (:wat::core::* (:wat::core::+ a b) 100) d))))))

(:wat::core::defn :paip::believable? [cf <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::> cf (:paip::cutoff)))

;; a rule's conclusion is limited by its premise's certainty
(:wat::core::defn :paip::apply-rule [premise <- :wat::core::i64 strength <- :wat::core::i64] -> :wat::core::i64
  (:wat::i64::quot (:wat::core::* premise strength) 100))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:paip::check-chapter "oracle/paip/ch16-expert-system.expected"
                          "paip ch16 expert system"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:paip::cf-and 70 50))
                            (int (:paip::cf-or 70 50))
                            (int (:paip::cf-and -30 50))
                            (int (:paip::cf-or -30 50))
                            ;; supporting evidence reinforces, but never reaches certainty
                            (int (:paip::cf-combine 50 50))
                            (int (:paip::cf-combine 50 80))
                            (int (:paip::cf-combine 90 90))
                            (:paip::b (:wat::core::< (:paip::cf-combine 90 90) 100))
                            (int (:paip::cf-combine -50 -50))
                            ;; contradictory evidence cancels toward the middle
                            (int (:paip::cf-combine 70 -70))
                            (int (:paip::cf-combine 80 -20))
                            (int (:paip::cf-combine 20 -80))
                            ;; certainty absorbs everything
                            (int (:paip::cf-combine 100 -50))
                            (int (:paip::cf-combine 100 50))
                            ;; a rule chain
                            (int (:paip::apply-rule 60 80))
                            (int (:paip::apply-rule 100 80))
                            (int (:paip::apply-rule 20 80))
                            (:paip::b (:paip::believable? (:paip::apply-rule 20 80)))
                            (:paip::b (:paip::believable? (:paip::apply-rule 60 80)))
                            (int (:paip::cf-combine (:paip::apply-rule 60 80) (:paip::apply-rule 50 60)))))))
