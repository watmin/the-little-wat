;; Norvig's PAIP, chapter 12 (Compiling Logic Programs): a Prolog on chapter 11's unifier.
;;
;; A clause is a quoted list — head first, then the goals that must hold for it — and the
;; database is a Vector of them, built once and only read. Proving a goal tries every clause
;; whose head unifies with it, and proves that clause's body under the resulting substitution.
;; A clause's variables are renamed apart before each attempt, or a rule that calls itself
;; collides with itself; `ancestor` is exactly that rule, and the last query here is what
;; catches a renaming that doesn't work.
;;
;; PAIP's membership clauses are NOT here. Both of their heads carry a list with a variable
;; tail, ((member ?i (?i . ?rest))), and wat's reader has no dotted pair: it reads (?i . ?rest)
;; as a three-element list whose middle element is a symbol named "." (F-059,
;; probes/paip/dotted-pattern.wat). That is where quoted data runs out, and it is the answer to
;; NEXT.md §5's question — see paip/README.md.
;;
;; The results must be guile's, in order (oracle/paip/ch12-prolog.scm, run by
;; tools/paip-oracle.sh). Our own Scheme and our own wat, both written from the algorithm:
;; Norvig's code is not read or copied.
;;
;; Run from the repository root (it reads the expected file by path):
;;   wat paip/ch12-prolog.wat

(:wat::load-file! "lib/check.wat")
(:wat::load-file! "lib/unify.wat")
(:wat::load-file! "lib/prolog.wat")

;; a small family tree: facts, then rules that join and recurse
(:wat::core::defn :paip::db [] -> :paip::Clauses
  (:wat::core::Vector :- [:wat::WatAST]
    (:wat::core::quote ((parent tom bob)))
    (:wat::core::quote ((parent tom liz)))
    (:wat::core::quote ((parent bob ann)))
    (:wat::core::quote ((parent bob pat)))
    (:wat::core::quote ((parent pat jim)))
    (:wat::core::quote ((female liz)))
    (:wat::core::quote ((female ann)))
    (:wat::core::quote ((female pat)))
    (:wat::core::quote ((male tom)))
    (:wat::core::quote ((male bob)))
    (:wat::core::quote ((male jim)))
    (:wat::core::quote ((grandparent ?x ?z) (parent ?x ?y) (parent ?y ?z)))
    (:wat::core::quote ((sibling ?x ?y) (parent ?p ?x) (parent ?p ?y)))
    (:wat::core::quote ((mother ?x ?y) (parent ?x ?y) (female ?x)))
    (:wat::core::quote ((ancestor ?x ?y) (parent ?x ?y)))
    (:wat::core::quote ((ancestor ?x ?y) (parent ?x ?z) (ancestor ?z ?y)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [db (:paip::db)
                    q  (:wat::core::fn [query <- :wat::WatAST] -> (:wat::core::Vector :- [:wat::core::String])
                         (:paip::query-lines query db))]
    (:paip::check-chapter "oracle/paip/ch12-prolog.expected"
                          "paip ch12 prolog"
                          (:wat::core::concat
                            (:wat::core::concat
                              (:wat::core::concat
                                ;; a ground query: true or not
                                (:wat::core::concat (q (:wat::core::quote (parent tom bob)))
                                                    (q (:wat::core::quote (parent bob tom))))
                                ;; one variable
                                (:wat::core::concat (q (:wat::core::quote (parent tom ?who)))
                                                    (:wat::core::concat (q (:wat::core::quote (parent ?who ann)))
                                                                        (q (:wat::core::quote (parent ann ?who))))))
                              ;; rules that join
                              (:wat::core::concat
                                (:wat::core::concat (q (:wat::core::quote (grandparent tom ?who)))
                                                    (q (:wat::core::quote (grandparent ?who jim))))
                                (:wat::core::concat (q (:wat::core::quote (mother ?who pat)))
                                                    (:wat::core::concat (q (:wat::core::quote (mother ?m ?c)))
                                                                        (q (:wat::core::quote (sibling ann ?who)))))))
                            ;; recursion, and the renaming it depends on
                            (:wat::core::concat
                              (:wat::core::concat (q (:wat::core::quote (ancestor tom ?who)))
                                                  (q (:wat::core::quote (ancestor ?who jim))))
                              (:wat::core::concat (q (:wat::core::quote (grandparent ?g ?c)))
                                                  (q (:wat::core::quote (ancestor ?a ?d)))))))))
