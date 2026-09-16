;; paip/lib/unify.wat: PAIP chapter 11's unifier, over quoted data.
;;
;; Our own implementation of what the chapter builds; Norvig's code is not read or copied.
;;
;; Representation — this is the point of the chapter, and the road The Reasoned Schemer did not
;; take. There is NO term enum here. A pattern is an ordinary quoted form, a :wat::WatAST, and a
;; variable is a symbol whose text begins with a question mark:
;;
;;   (:wat::core::quote (?x + 1))
;;
;; The pieces that makes possible (measured in probes/paip/ast-as-data.wat):
;;   - ast-kind is total and says "symbol", "list", "int", …
;;   - ast-name gives a symbol's verbatim text, but RAISES on a node that is not a
;;     Symbol/Keyword/StringLit, so every ?-test must check the kind first;
;;   - ast->children decomposes a list and yields nothing for a leaf;
;;   - with-children rebuilds a node of the same kind from new children;
;;   - = is structural, nested and all;
;;   - ast->source prints a node back as source, and prints (2 + 1) exactly as guile does.
;;
;; A substitution maps a variable's NAME to a term, not a node to a term: two ?x nodes read from
;; two different quoted forms are different AST nodes but the same variable. It is a
;; PersistentMap, which shares structure where a HashMap copies on every insert (F-057) — a
;; unifier extends its substitution once per variable it meets.
;;
;; Failure is Option.None. PAIP uses the symbol `fail`; wat has no failure marker, and an enum
;; of two cases would be the typed representation this chapter exists to avoid.

(:wat::core::typealias :paip::Subst (:wat::core::PersistentMap :- [:wat::core::String :wat::WatAST]))
(:wat::core::typealias :paip::Answer (:wat::core::Option :- [:paip::Subst]))
(:wat::core::typealias :paip::Nodes (:wat::core::Vector :- [:wat::WatAST]))

(:wat::core::defn :paip::no-bindings [] -> :paip::Subst
  (:wat::core::PersistentMap :- [:wat::core::String :wat::WatAST]))

(:wat::core::defn :paip::ok [s <- :paip::Subst] -> :paip::Answer
  (:wat::core::Option.Some {:value s}))

(:wat::core::defn :paip::fail [] -> :paip::Answer
  (:wat::core::Option.None {}))

;; ---- variables

;; A variable is a symbol whose text begins with "?". The kind test comes first: ast-name raises
;; on a list or a number.
(:wat::core::defn :paip::variable? [x <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::if (:wat::core::= (:wat::core::ast-kind x) "symbol")
    (:wat::string::starts-with? (:wat::core::ast-name x) "?")
    false))

(:wat::core::defn :paip::var-name [x <- :wat::WatAST] -> :wat::core::String
  (:wat::core::ast-name x))

(:wat::core::defn :paip::bound? [s <- :paip::Subst x <- :wat::WatAST] -> :wat::core::bool
  (:wat::map::contains-key? s (:paip::var-name x)))

;; What a variable stands for. Only ever called on a variable known to be bound.
(:wat::core::defn :paip::lookup [s <- :paip::Subst x <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::match (:wat::map::get s (:paip::var-name x))
    [:wat::core::Option.Some {:value t} t]
    [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message (:wat::string::concat "unbound: " (:paip::var-name x)))]))

(:wat::core::defn :paip::extend [s <- :paip::Subst x <- :wat::WatAST t <- :wat::WatAST] -> :paip::Subst
  (:wat::map::assoc s (:paip::var-name x) t))

(:wat::core::defn :paip::list? [x <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::= (:wat::core::ast-kind x) "list"))

;; ---- the occurs check

(:wat::core::defn :paip::occurs-in-all? [s <- :paip::Subst v <- :wat::WatAST xs <- :paip::Nodes i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    false
    (:wat::core::if (:paip::occurs-in? s v (:wat::core::nth xs i))
      true
      (:paip::occurs-in-all? s v xs (:wat::core::+ i 1)))))

;; Does the variable v occur anywhere inside x, once x's own bindings are followed?
(:wat::core::defn :paip::occurs-in? [s <- :paip::Subst v <- :wat::WatAST x <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::if (:wat::core::= v x)
    true
    (:wat::core::if (:wat::core::and (:paip::variable? x) (:paip::bound? s x))
      (:paip::occurs-in? s v (:paip::lookup s x))
      (:wat::core::if (:paip::list? x)
        (:paip::occurs-in-all? s v (:wat::core::ast->children x) 0)
        false))))

;; ---- unification

(:wat::core::defn :paip::unify-variable [s <- :paip::Subst v <- :wat::WatAST x <- :wat::WatAST] -> :paip::Answer
  (:wat::core::if (:paip::bound? s v)
    (:paip::unify (:paip::lookup s v) x s)
    (:wat::core::if (:wat::core::and (:paip::variable? x) (:paip::bound? s x))
      (:paip::unify v (:paip::lookup s x) s)
      (:wat::core::if (:paip::occurs-in? s v x)
        (:paip::fail)
        (:paip::ok (:paip::extend s v x))))))

;; Two lists unify when they are the same length and unify element by element. PAIP recurses on
;; car and cdr; here the children are a Vector, so the length test stands in for the point where
;; one list runs out before the other.
(:wat::core::defn :paip::unify-all [xs <- :paip::Nodes ys <- :paip::Nodes i <- :wat::core::i64 s <- :paip::Subst] -> :paip::Answer
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    (:paip::ok s)
    (:wat::core::match (:paip::unify (:wat::core::nth xs i) (:wat::core::nth ys i) s)
      [:wat::core::Option.Some {:value s1} (:paip::unify-all xs ys (:wat::core::+ i 1) s1)]
      [:wat::core::Option.None {} (:paip::fail)])))

(:wat::core::defn :paip::unify [x <- :wat::WatAST y <- :wat::WatAST s <- :paip::Subst] -> :paip::Answer
  (:wat::core::if (:wat::core::= x y)
    (:paip::ok s)
    (:wat::core::if (:paip::variable? x)
      (:paip::unify-variable s x y)
      (:wat::core::if (:paip::variable? y)
        (:paip::unify-variable s y x)
        (:wat::core::if (:wat::core::and (:paip::list? x) (:paip::list? y))
          (:wat::core::let [xs (:wat::core::ast->children x)
                            ys (:wat::core::ast->children y)]
            (:wat::core::if (:wat::core::= (:wat::core::length xs) (:wat::core::length ys))
              (:paip::unify-all xs ys 0 s)
              (:paip::fail)))
          (:paip::fail))))))

(:wat::core::defn :paip::unify-top [x <- :wat::WatAST y <- :wat::WatAST] -> :paip::Answer
  (:paip::unify x y (:paip::no-bindings)))

;; ---- substituting a substitution through a pattern

(:wat::core::defn :paip::subst-all [s <- :paip::Subst xs <- :paip::Nodes i <- :wat::core::i64 acc <- :paip::Nodes] -> :paip::Nodes
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    acc
    (:paip::subst-all s xs (:wat::core::+ i 1)
      (:wat::core::conj acc (:paip::subst s (:wat::core::nth xs i))))))

;; Replace every bound variable in x by what it stands for, all the way down.
(:wat::core::defn :paip::subst [s <- :paip::Subst x <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::if (:wat::core::and (:paip::variable? x) (:paip::bound? s x))
    (:paip::subst s (:paip::lookup s x))
    (:wat::core::if (:paip::list? x)
      (:wat::core::with-children x (:paip::subst-all s (:wat::core::ast->children x) 0 (:wat::core::Vector :- [:wat::WatAST])))
      x)))

;; A substitution pushed through a pattern, when there is one: PAIP's subst-bindings, which
;; carries failure through rather than testing for it at each call site.
(:wat::core::defn :paip::subst-answer [a <- :paip::Answer x <- :wat::WatAST] -> (:wat::core::Option :- [:wat::WatAST])
  (:wat::core::match a
    [:wat::core::Option.Some {:value s} (:wat::core::Option.Some {:value (:paip::subst s x)})]
    [:wat::core::Option.None {} (:wat::core::Option.None {})]))

;; The unifier's answer: the two patterns made one, or nothing.
(:wat::core::defn :paip::unifier [x <- :wat::WatAST y <- :wat::WatAST] -> (:wat::core::Option :- [:wat::WatAST])
  (:wat::core::match (:paip::unify-top x y)
    [:wat::core::Option.Some {:value s} (:wat::core::Option.Some {:value (:paip::subst s x)})]
    [:wat::core::Option.None {} (:wat::core::Option.None {})]))

;; ---- printing, to be compared with guile's line

;; One binding, as (?var value).
(:wat::core::defn :paip::show-binding [s <- :paip::Subst name <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:wat::map::get s name)
    [:wat::core::Option.Some {:value t} (:wat::string::concat "(" name " " (:wat::core::ast->source t) ")")]
    [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message (:wat::string::concat "unbound: " name))]))

;; A substitution, sorted by variable name: ((?x 2) (?y 1)). Sorted because map::keys is
;; explicitly not deterministic in its order — "the trie has no meaningful order".
(:wat::core::defn :paip::show-subst [s <- :paip::Subst] -> :wat::core::String
  (:wat::core::let [names (:wat::core::sort (:wat::map::keys s))
                    parts (:wat::core::mapv (:wat::core::fn [n <- :wat::core::String] -> :wat::core::String (:paip::show-binding s n)) names)]
    (:wat::string::concat "(" (:wat::string::join " " parts) ")")))

;; An answer: the substitution, or PAIP's fail.
(:wat::core::defn :paip::show-answer [a <- :paip::Answer] -> :wat::core::String
  (:wat::core::match a
    [:wat::core::Option.Some {:value s} (:paip::show-subst s)]
    [:wat::core::Option.None {} "fail"]))

;; A term answer: the pattern, or fail.
(:wat::core::defn :paip::show-term [t <- (:wat::core::Option :- [:wat::WatAST])] -> :wat::core::String
  (:wat::core::match t
    [:wat::core::Option.Some {:value x} (:wat::core::ast->source x)]
    [:wat::core::Option.None {} "fail"]))

(:wat::core::defn :paip::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))
