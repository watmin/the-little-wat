;; paip/lib/prolog.wat: PAIP chapter 12's Prolog, on chapter 11's unifier.
;;
;; Our own implementation of what the chapter builds; Norvig's code is not read or copied.
;; Needs lib/unify.wat, whose unify, subst, variable? and show-subst this reuses whole — which
;; is the point of having built chapter 11 first.
;;
;; A clause is a quoted list: its first element is the head (the conclusion), the rest are the
;; goals that must hold for it. A fact is a clause of one element. The database is a Vector of
;; clauses, built once and only read — so it is a VALUE, not a service. C-014 puts mutable state
;; on services, but nothing here mutates, and a message costs about 224 µs against a function
;; call's two (F-051); a Prolog asks its database thousands of times.
;;
;; Proving a goal: for each clause whose head unifies with the goal, prove that clause's body
;; under the resulting substitution. Every solution is collected — this is eager, a Vector of
;; substitutions rather than a lazy stream. The databases here are small, and a wat stream does
;; not remember what it forced (F-053), so laziness would buy nothing back.
;;
;; Renaming: a clause's variables are renamed apart before each attempt, or a rule that calls
;; itself collides with itself — ancestor is exactly that rule. ?x becomes ?x-1, ?x-2, … The
;; separator is "-" and not PAIP's ".", because a dot carries reader meaning inside a list:
;; (?i . ?rest) reads as three children with a symbol named "." in the middle (F-059).
;;
;; The counter is threaded, not kept. wat has no mutable variable, and the two honest routes are
;; threading a number through the recursion or keeping one on a counter service (C-014). The
;; recursion already carries a substitution, so carrying a number beside it costs nothing and
;; keeps this library a value.

(:wat::core::typealias :paip::Clauses (:wat::core::Vector :- [:wat::WatAST]))
(:wat::core::typealias :paip::Substs (:wat::core::Vector :- [:paip::Subst]))

;; a set of solutions and the counter left over, since proving renames as it goes
(:wat::core::defstruct :paip::Proof
  [solutions <- :paip::Substs
   n         <- :wat::core::i64])

(:wat::core::defn :paip::clause-head [c <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::first (:wat::core::ast->children c)))

(:wat::core::defn :paip::clause-body [c <- :wat::WatAST] -> :paip::Nodes
  (:wat::core::rest (:wat::core::ast->children c)))

;; ---- renaming a clause's variables apart

;; every variable in x, by name, first appearance first
(:wat::core::defn :paip::vars-in-all [xs <- :paip::Nodes i <- :wat::core::i64 acc <- (:wat::core::Vector :- [:wat::core::String])] -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    acc
    (:paip::vars-in-all xs (:wat::core::+ i 1) (:paip::vars-in (:wat::core::nth xs i) acc))))

(:wat::core::defn :paip::vars-in [x <- :wat::WatAST acc <- (:wat::core::Vector :- [:wat::core::String])] -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::if (:paip::variable? x)
    (:wat::core::if (:wat::core::contains? acc (:paip::var-name x))
      acc
      (:wat::core::conj acc (:paip::var-name x)))
    (:wat::core::if (:paip::list? x)
      (:paip::vars-in-all (:wat::core::ast->children x) 0 acc)
      acc)))

;; ?x under renaming number n is ?x-n
(:wat::core::defn :paip::renamed [name <- :wat::core::String n <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::symbol-node (:wat::string::concat name "-" (:wat::i64::to-string n))))

(:wat::core::defn :paip::rename-all [xs <- :paip::Nodes i <- :wat::core::i64 n <- :wat::core::i64 acc <- :paip::Nodes] -> :paip::Nodes
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    acc
    (:paip::rename-all xs (:wat::core::+ i 1) n (:wat::core::conj acc (:paip::rename (:wat::core::nth xs i) n)))))

;; every variable in x, renamed apart by n
(:wat::core::defn :paip::rename [x <- :wat::WatAST n <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::if (:paip::variable? x)
    (:paip::renamed (:paip::var-name x) n)
    (:wat::core::if (:paip::list? x)
      (:wat::core::with-children x (:paip::rename-all (:wat::core::ast->children x) 0 n (:wat::core::Vector :- [:wat::WatAST])))
      x)))

;; ---- proving

(:wat::core::defn :paip::no-solutions [] -> :paip::Substs
  (:wat::core::Vector :- [:paip::Subst]))

;; try each clause of the database against the goal, gathering every solution
(:wat::core::defn :paip::prove-clauses [goal <- :wat::WatAST s <- :paip::Subst db <- :paip::Clauses
                                        i <- :wat::core::i64 n <- :wat::core::i64 acc <- :paip::Substs] -> :paip::Proof
  (:wat::core::if (:wat::core::>= i (:wat::core::length db))
    (:paip::Proof :solutions acc :n n)
    (:wat::core::let [c  (:paip::rename (:wat::core::nth db i) n)
                      n1 (:wat::core::+ n 1)]
      (:wat::core::match (:paip::unify goal (:paip::clause-head c) s)
        [:wat::core::Option.Some {:value s1}
          (:wat::core::let [p (:paip::prove-all (:paip::clause-body c) 0 s1 db n1 (:paip::no-solutions))]
            (:paip::prove-clauses goal s db (:wat::core::+ i 1) (:paip::Proof/n p)
                                  (:wat::core::concat acc (:paip::Proof/solutions p))))]
        [:wat::core::Option.None {}
          (:paip::prove-clauses goal s db (:wat::core::+ i 1) n1 acc)]))))

;; every way of proving one goal
(:wat::core::defn :paip::prove [goal <- :wat::WatAST s <- :paip::Subst db <- :paip::Clauses n <- :wat::core::i64] -> :paip::Proof
  (:paip::prove-clauses goal s db 0 n (:paip::no-solutions)))

;; carry the remaining goals across every solution the first goal gave
(:wat::core::defn :paip::prove-rest [goals <- :paip::Nodes i <- :wat::core::i64 ss <- :paip::Substs j <- :wat::core::i64
                                     db <- :paip::Clauses n <- :wat::core::i64 acc <- :paip::Substs] -> :paip::Proof
  (:wat::core::if (:wat::core::>= j (:wat::core::length ss))
    (:paip::Proof :solutions acc :n n)
    (:wat::core::let [p (:paip::prove-all goals (:wat::core::+ i 1) (:wat::core::nth ss j) db n (:paip::no-solutions))]
      (:paip::prove-rest goals i ss (:wat::core::+ j 1) db (:paip::Proof/n p)
                         (:wat::core::concat acc (:paip::Proof/solutions p))))))

;; every way of proving all the goals from i on, left to right
(:wat::core::defn :paip::prove-all [goals <- :paip::Nodes i <- :wat::core::i64 s <- :paip::Subst
                                    db <- :paip::Clauses n <- :wat::core::i64 acc <- :paip::Substs] -> :paip::Proof
  (:wat::core::if (:wat::core::>= i (:wat::core::length goals))
    (:paip::Proof :solutions (:wat::core::conj acc s) :n n)
    (:wat::core::let [p (:paip::prove (:wat::core::nth goals i) s db n)]
      (:paip::prove-rest goals i (:paip::Proof/solutions p) 0 db (:paip::Proof/n p) acc))))

;; every solution to one query
(:wat::core::defn :paip::solve [query <- :wat::WatAST db <- :paip::Clauses] -> :paip::Substs
  (:paip::Proof/solutions
    (:paip::prove-all (:wat::core::Vector :- [:wat::WatAST] query) 0 (:paip::no-bindings) db 1 (:paip::no-solutions))))

;; ---- printing an answer

;; the query's OWN variables, resolved through the substitution, sorted by name: the renamed
;; ones are plumbing and never appear.
(:wat::core::defn :paip::show-query-answer [query <- :wat::WatAST s <- :paip::Subst] -> :wat::core::String
  (:wat::core::let [names (:wat::core::sort (:paip::vars-in query (:wat::core::Vector :- [:wat::core::String])))]
    (:wat::core::if (:wat::core::empty? names)
      "yes"
      (:wat::string::concat "("
        (:wat::string::join " "
          (:wat::core::mapv (:wat::core::fn [nm <- :wat::core::String] -> :wat::core::String
                              (:wat::string::concat "(" nm " " (:wat::core::ast->source (:paip::subst s (:wat::core::symbol-node nm))) ")"))
                            names))
        ")"))))

;; every solution to a query, one line each, or PAIP's fail when there are none
(:wat::core::defn :paip::query-lines [query <- :wat::WatAST db <- :paip::Clauses] -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::let [ss (:paip::solve query db)]
    (:wat::core::if (:wat::core::empty? ss)
      (:wat::core::Vector :- [:wat::core::String] "fail")
      (:wat::core::mapv (:wat::core::fn [s <- :paip::Subst] -> :wat::core::String (:paip::show-query-answer query s)) ss))))
