;; Norvig's PAIP, chapter 11 (Logic Programming): unification over quoted S-expressions.
;;
;; NEXT.md §5 asks where "quoted data versus typed data gets decided". The Reasoned Schemer
;; answered for typed data: :rs::Term is an enum, and rs/q converts a quoted form into it at
;; once. This chapter answers the other way. A pattern here is an ordinary quoted form and a
;; variable is the symbol ?x; nothing is converted, and paip/lib/unify.wat walks :wat::WatAST
;; itself.
;;
;; The results must be guile's, in order (oracle/paip/ch11-unification.scm, run by
;; tools/paip-oracle.sh). Our own Scheme and our own wat, both written from the algorithm:
;; Norvig's code is not read or copied.
;;
;; Run from the repository root (it reads the expected file by path):
;;   wat paip/ch11-unification.wat

(:wat::load-file! "lib/check.wat")
(:wat::load-file! "lib/unify.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [no (:paip::no-bindings)]
    (:paip::check-chapter "oracle/paip/ch11-unification.expected"
                          "paip ch11 unification"
                          (:wat::core::Vector :- [:wat::core::String]

                            ;; what counts as a variable
                            (:paip::show-bool (:paip::variable? (:wat::core::quote ?x)))
                            (:paip::show-bool (:paip::variable? (:wat::core::quote x)))
                            (:paip::show-bool (:paip::variable? (:wat::core::quote ?)))
                            (:paip::show-bool (:paip::variable? (:wat::core::quote 42)))

                            ;; atoms unify with themselves and nothing else
                            (:paip::show-answer (:paip::unify (:wat::core::quote a) (:wat::core::quote a) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote a) (:wat::core::quote b) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote 1) (:wat::core::quote 1) no))

                            ;; a variable takes the other side
                            (:paip::show-answer (:paip::unify (:wat::core::quote ?x) (:wat::core::quote a) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote a) (:wat::core::quote ?x) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote ?x) (:wat::core::quote ?y) no))

                            ;; lists unify element by element
                            (:paip::show-answer (:paip::unify (:wat::core::quote (?x + 1)) (:wat::core::quote (2 + ?y)) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote (?x ?y)) (:wat::core::quote (?y ?x)) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote (f ?x)) (:wat::core::quote (f a)) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote (f ?x)) (:wat::core::quote (g a)) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote (f ?x ?y)) (:wat::core::quote (f a)) no))

                            ;; a variable bound twice must agree
                            (:paip::show-answer (:paip::unify (:wat::core::quote (?x ?x)) (:wat::core::quote (a a)) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote (?x ?x)) (:wat::core::quote (a b)) no))

                            ;; nesting
                            (:paip::show-answer (:paip::unify (:wat::core::quote (?x (f ?y))) (:wat::core::quote ((g ?y) (f b))) no))

                            ;; the occurs check: ?x cannot stand for something containing ?x
                            (:paip::show-answer (:paip::unify (:wat::core::quote ?x) (:wat::core::quote (f ?x)) no))
                            (:paip::show-answer (:paip::unify (:wat::core::quote (?x ?y)) (:wat::core::quote ((f ?y) ?x)) no))

                            ;; substituting a substitution through a pattern
                            (:paip::show-term (:paip::subst-answer (:paip::unify (:wat::core::quote (?x + 1)) (:wat::core::quote (2 + ?y)) no)
                                                                   (:wat::core::quote (?x and ?y))))
                            (:paip::show-term (:paip::subst-answer (:paip::unify (:wat::core::quote (?x ?y)) (:wat::core::quote ((f a) b)) no)
                                                                   (:wat::core::quote (?x ?y ?z))))

                            ;; the unifier: both patterns made one
                            (:paip::show-term (:paip::unifier (:wat::core::quote (?x + 1)) (:wat::core::quote (2 + ?y))))
                            (:paip::show-term (:paip::unifier (:wat::core::quote (?x ?y a)) (:wat::core::quote (?y ?x ?x))))
                            (:paip::show-term (:paip::unifier (:wat::core::quote (f ?x)) (:wat::core::quote (g a))))))))
