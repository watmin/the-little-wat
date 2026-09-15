;; The Reasoned Schemer, chapter 10 (Under the Hood): the miniKanren engine that every other
;; chapter runs on. Our own implementation, following the book's design: a substitution with
;; an occurs check, streams that interleave through suspensions, and reification.
;; Needs ../little-schemer/lib/ch01-toys.wat (quoted-list primitives).
;;
;; Representation:
;; - A term is an :rs::Term: an atom (any quoted non-list), a logic variable (an i64 id), a
;;   pair, or the empty list. Quoted lists can't hold a pair with a variable tail, (a . d),
;;   so terms are their own enum.
;; - A substitution is a HashMap from variable id to term. A state is the substitution plus
;;   the next fresh variable id.
;; - A stream is a lazy stream of Option<State>. Some is an answer; None is a suspension (the
;;   book's thunk), the point where mplus swaps to its other stream. That is what keeps a
;;   divergent branch from starving the rest.
;; - A goal is a function from a state to a stream.

(:wat::core::defenum :rs::Term :wat::enum::Pure
  :Atom [v <- :wat::WatAST]
  :Var  [n <- :wat::core::i64]
  :Pair [a <- :rs::Term  d <- :rs::Term]
  :Nil  [])

(wat.core/typealias :rs::Subst (:wat::core::HashMap :- [:wat::core::i64 :rs::Term]))

(:wat::core::defstruct :rs::State
  [s <- :rs::Subst
   c <- :wat::core::i64])

(wat.core/typealias :rs::Stream (:wat::stream::Stream :- [(:wat::core::Option :- [:rs::State])]))
(wat.core/typealias :rs::Goal [:rs::State :-> :rs::Stream])

;; ---- constructors. Each declares :rs::Term (or Option<T>) as its return, which widens the
;; ---- constructed variant to its enum (F-019).

(wat.core/defn rs/some :- [T] [x :- T] :- (wat.type/Option :- [T])
  (:wat::core::Option.Some {:value x}))

(wat.core/defn rs/atom [v :- :wat::WatAST] :- :rs::Term (:rs::Term.Atom {:v v}))
(wat.core/defn rs/var [n :- wat.type/i64] :- :rs::Term (:rs::Term.Var {:n n}))
(wat.core/defn rs/cons [a :- :rs::Term d :- :rs::Term] :- :rs::Term (:rs::Term.Pair {:a a :d d}))
(wat.core/defn rs/nil [] :- :rs::Term (:rs::Term.Nil {}))

;; A quoted S-expression as a term: lists become pairs ending in Nil, anything else an atom.
(wat.core/defn rs/q [x :- :wat::WatAST] :- :rs::Term
  (wat.core/if (ls/atom? x)
    (rs/atom x)
    (wat.core/if (ls/null? x)
      (rs/nil)
      (rs/cons (rs/q (ls/car x)) (rs/q (ls/cdr x))))))

;; A proper list of terms, and a list ending in the term d (the book's (a b . d)).
(wat.core/defn rs/list* [xs :- (wat.type/Vector :- [:rs::Term]) d :- :rs::Term] :- :rs::Term
  (wat.core/if (wat.core/empty? xs)
    d
    (rs/cons (wat.core/first xs) (rs/list* (wat.core/rest xs) d))))

(wat.core/defn rs/list [xs :- (wat.type/Vector :- [:rs::Term])] :- :rs::Term
  (rs/list* xs (rs/nil)))

;; Quoted elements ending in the term d: (rs/q* '(a b) d) is the book's `(a b . ,d).
(wat.core/defn rs/q* [xs :- :wat::WatAST d :- :rs::Term] :- :rs::Term
  (wat.core/if (ls/null? xs)
    d
    (rs/cons (rs/q (ls/car xs)) (rs/q* (ls/cdr xs) d))))

;; ---- substitution

(wat.core/defn rs/walk [t :- :rs::Term s :- :rs::Subst] :- :rs::Term
  (:wat::core::match t
    [:rs::Term.Var {:n n}
      (:wat::core::match (wat.core/get s n)
        [:wat::core::Option.Some {:value v} (rs/walk v s)]
        [:wat::core::Option.None {} t])]
    [_ t]))

(wat.core/defn rs/occurs? [x :- wat.type/i64 v :- :rs::Term s :- :rs::Subst] :- wat.type/bool
  (:wat::core::match (rs/walk v s)
    [:rs::Term.Var {:n n} (wat.core/= n x)]
    [:rs::Term.Pair {:a a :d d} (wat.core/or (rs/occurs? x a s) (rs/occurs? x d s))]
    [_ false]))

(wat.core/defn rs/ext-s [x :- wat.type/i64 v :- :rs::Term s :- :rs::Subst] :- (wat.type/Option :- [:rs::Subst])
  (wat.core/if (rs/occurs? x v s)
    :wat::core::Option.None
    (rs/some (wat.core/assoc s x v))))

;; Both sides already walked, neither a variable.
(wat.core/defn rs/unify-values [u :- :rs::Term v :- :rs::Term s :- :rs::Subst] :- (wat.type/Option :- [:rs::Subst])
  (:wat::core::match u
    [:rs::Term.Pair {:a ua :d ud}
      (:wat::core::match v
        [:rs::Term.Pair {:a va :d vd}
          (rs/unify ud vd (:wat::core::Option/try (rs/unify ua va s)))]
        [_ :wat::core::Option.None])]
    [:rs::Term.Atom {:v x}
      (:wat::core::match v
        [:rs::Term.Atom {:v y} (wat.core/if (wat.core/= x y) (rs/some s) :wat::core::Option.None)]
        [_ :wat::core::Option.None])]
    [_ (:wat::core::match v
         [:rs::Term.Nil {} (rs/some s)]
         [_ :wat::core::Option.None])]))

(wat.core/defn rs/unify [u :- :rs::Term v :- :rs::Term s :- :rs::Subst] :- (wat.type/Option :- [:rs::Subst])
  (wat.core/let [uw (rs/walk u s)
                 vw (rs/walk v s)]
    (:wat::core::match uw
      [:rs::Term.Var {:n un}
        (:wat::core::match vw
          [:rs::Term.Var {:n vn} (wat.core/if (wat.core/= un vn) (rs/some s) (rs/ext-s un vw s))]
          [_ (rs/ext-s un vw s)])]
      [_ (:wat::core::match vw
           [:rs::Term.Var {:n vn} (rs/ext-s vn uw s)]
           [_ (rs/unify-values uw vw s)])])))

;; ---- streams

(wat.core/defn rs/unit [st :- :rs::State] :- :rs::Stream
  (:wat::stream::cons (rs/some st) (:wat::stream::empty)))

(wat.core/defn rs/mzero [] :- :rs::Stream
  (:wat::stream::empty))

;; Interleave: answers from s1 until it suspends, then swap (the book's append-inf).
(wat.core/defn rs/mplus [s1 :- :rs::Stream s2 :- :rs::Stream] :- :rs::Stream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next s1)
      [:wat::stream::NextOutcome.Exhausted {} s2]
      [:wat::stream::NextOutcome.Item {:value v :rest r}
        (:wat::core::match v
          [:wat::core::Option.Some {:value _st} (:wat::stream::cons v (rs/mplus r s2))]
          [:wat::core::Option.None {} (:wat::stream::cons v (rs/mplus s2 r))])])))

;; Run g on every answer of s, interleaving the results (the book's append-map-inf).
(wat.core/defn rs/bind [s :- :rs::Stream g :- :rs::Goal] :- :rs::Stream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
      [:wat::stream::NextOutcome.Item {:value v :rest r}
        (:wat::core::match v
          [:wat::core::Option.Some {:value st} (rs/mplus (g st) (rs/bind r g))]
          [:wat::core::Option.None {} (:wat::stream::cons v (rs/bind r g))])])))

;; ---- goals

(wat.core/defn rs/== [u :- :rs::Term v :- :rs::Term] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream
    (:wat::core::match (rs/unify u v (:rs::State/s st))
      [:wat::core::Option.Some {:value s2} (rs/unit (:rs::State :s s2 :c (:rs::State/c st)))]
      [:wat::core::Option.None {} (rs/mzero)])))

(wat.core/defn rs/succeed [] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream (rs/unit st)))

(wat.core/defn rs/fail [] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream (rs/mzero)))

(wat.core/defn rs/disj2 [g1 :- :rs::Goal g2 :- :rs::Goal] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream (rs/mplus (g1 st) (g2 st))))

(wat.core/defn rs/conj2 [g1 :- :rs::Goal g2 :- :rs::Goal] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream (rs/bind (g1 st) g2)))

;; Nested to the right, as the book's disj and conj macros nest; the nesting decides the
;; order answers come out in.
(wat.core/defn rs/disj [gs :- (wat.type/Vector :- [:rs::Goal])] :- :rs::Goal
  (wat.core/cond
    ((wat.core/empty? gs) (rs/fail))
    ((wat.core/empty? (wat.core/rest gs)) (wat.core/first gs))
    (:else (rs/disj2 (wat.core/first gs) (rs/disj (wat.core/rest gs))))))

(wat.core/defn rs/conj [gs :- (wat.type/Vector :- [:rs::Goal])] :- :rs::Goal
  (wat.core/cond
    ((wat.core/empty? gs) (rs/succeed))
    ((wat.core/empty? (wat.core/rest gs)) (wat.core/first gs))
    (:else (rs/conj2 (wat.core/first gs) (rs/conj (wat.core/rest gs))))))

;; call/fresh: f receives a new variable and returns the goal that uses it. The fresh macro
;; below nests one call per variable.
(wat.core/defn rs/call-fresh [f :- [:rs::Term :-> :rs::Goal]] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream
    (wat.core/let [c (:rs::State/c st)]
      ((f (rs/var c)) (:rs::State :s (:rs::State/s st) :c (wat.core/+ c 1))))))

;; The book's defrel: a relation's body is built only when the goal runs, behind a
;; suspension. Without it, a recursive relation would build its goal tree forever before
;; running at all.
(wat.core/defn rs/delay [body :- [:-> :rs::Goal]] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream
    (:wat::stream::lazy
      (:wat::stream::cons :wat::core::Option.None (:wat::stream::lazy ((body) st))))))

;; ---- ch 9's impure operators

;; If g1 has an answer, run g2 on all of g1's answers; otherwise run g3. Suspensions before
;; g1's first answer pass through, so a slow g1 does not block its siblings.
(wat.core/defn rs/ifte-loop [s :- :rs::Stream st :- :rs::State g2 :- :rs::Goal g3 :- :rs::Goal] :- :rs::Stream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} (g3 st)]
      [:wat::stream::NextOutcome.Item {:value v :rest r}
        (:wat::core::match v
          [:wat::core::Option.Some {:value _a} (rs/bind (:wat::stream::cons v r) g2)]
          [:wat::core::Option.None {} (:wat::stream::cons v (rs/ifte-loop r st g2 g3))])])))

(wat.core/defn rs/ifte [g1 :- :rs::Goal g2 :- :rs::Goal g3 :- :rs::Goal] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream (rs/ifte-loop (g1 st) st g2 g3)))

;; At most g's first answer.
(wat.core/defn rs/once-loop [s :- :rs::Stream] :- :rs::Stream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
      [:wat::stream::NextOutcome.Item {:value v :rest r}
        (:wat::core::match v
          [:wat::core::Option.Some {:value _a} (:wat::stream::cons v (:wat::stream::empty))]
          [:wat::core::Option.None {} (:wat::stream::cons v (rs/once-loop r))])])))

(wat.core/defn rs/once [g :- :rs::Goal] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream (rs/once-loop (g st))))

;; ---- running and reification

;; Up to n answers (n < 0: all of them), skipping suspensions.
(wat.core/defn rs/take [n :- wat.type/i64 acc :- (wat.type/Vector :- [:rs::State]) s :- :rs::Stream] :- (wat.type/Vector :- [:rs::State])
  (wat.core/if (wat.core/= n 0)
    acc
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} acc]
      [:wat::stream::NextOutcome.Item {:value v :rest r}
        (:wat::core::match v
          [:wat::core::Option.Some {:value st} (rs/take (wat.core/- n 1) (wat.core/conj acc st) r)]
          [:wat::core::Option.None {} (rs/take n acc r)])])))

(wat.core/defn rs/walk* [t :- :rs::Term s :- :rs::Subst] :- :rs::Term
  (wat.core/let [w (rs/walk t s)]
    (:wat::core::match w
      [:rs::Term.Pair {:a a :d d} (rs/cons (rs/walk* a s) (rs/walk* d s))]
      [_ w])))

;; Number the unbound variables of t in order of first appearance, left to right.
(wat.core/defn rs/name-vars [t :- :rs::Term names :- (wat.type/HashMap :- [wat.type/i64 wat.type/i64])]
  :- (wat.type/HashMap :- [wat.type/i64 wat.type/i64])
  (:wat::core::match t
    [:rs::Term.Var {:n n}
      (:wat::core::match (wat.core/get names n)
        [:wat::core::Option.Some {:value _k} names]
        [:wat::core::Option.None {} (wat.core/assoc names n (wat.core/length names))])]
    [:rs::Term.Pair {:a a :d d} (rs/name-vars d (rs/name-vars a names))]
    [_ names]))

(wat.core/defn rs/var-name [k :- wat.type/i64] :- :wat::WatAST
  (:wat::core::symbol-node (:wat::string::concat "_" (:wat::i64::to-string k))))

;; A walked term as quoted data. An improper tail prints as (a b & d), where the book
;; prints (a b . d).
(wat.core/defn rs/->ast [t :- :rs::Term names :- (wat.type/HashMap :- [wat.type/i64 wat.type/i64])] :- :wat::WatAST
  (:wat::core::match t
    [:rs::Term.Atom {:v v} v]
    [:rs::Term.Var {:n n}
      (:wat::core::match (wat.core/get names n)
        [:wat::core::Option.Some {:value k} (rs/var-name k)]
        [:wat::core::Option.None {} (rs/var-name -1)])]
    [:rs::Term.Pair {:a a :d d}
      (wat.core/let [aa (rs/->ast a names)
                     dd (rs/->ast d names)]
        (:wat::core::match d
          [:rs::Term.Pair {:a _a :d _d} (ls/cons aa dd)]
          [:rs::Term.Nil {} (ls/cons aa dd)]
          [_ (wat.core/quasiquote (~aa & ~dd))]))]
    [_ '()]))

(wat.core/defn rs/reify [t :- :rs::Term st :- :rs::State] :- :wat::WatAST
  (wat.core/let [w (rs/walk* t (:rs::State/s st))]
    (rs/->ast w (rs/name-vars w {}))))

(wat.core/defn rs/start [] :- :rs::State
  (:rs::State :s {} :c 1))

(wat.core/defn rs/answer? [o :- (wat.type/Option :- [:rs::State])] :- wat.type/bool
  (:wat::core::match o
    [:wat::core::Option.Some {:value _st} true]
    [:wat::core::Option.None {} false]))

;; An answer's value of the query variable (variable 0).
(wat.core/defn rs/reify-answer [o :- (wat.type/Option :- [:rs::State])] :- :wat::WatAST
  (:wat::core::match o
    [:wat::core::Option.Some {:value st} (rs/reify (rs/var 0) st)]
    [:wat::core::Option.None {} '()]))

;; The first n values (n < 0: all) of the query variable handed to f, as a quoted list. The
;; query is variable 0. The run and run* macros below are the book's spelling of this.
;; The answers go through the stdlib's lazy stream fns and one native into, which is linear.
;; Accumulating them by hand (rs/take's conj, a splice per answer) was quadratic: conj
;; copies a Vector (F-023).
(wat.core/defn rs/run-goal [n :- wat.type/i64 f :- [:rs::Term :-> :rs::Goal]] :- :wat::WatAST
  (wat.core/let [answers (:wat::core::map rs/reify-answer
                                          (:wat::core::filter rs/answer? ((f (rs/var 0)) (rs/start))))
                 v (wat.core/if (wat.core/< n 0)
                     (:wat::core::into [] answers)
                     (:wat::core::into [] (:wat::core::take answers n)))]
    (wat.core/quasiquote (~@v))))

;; ---- the book's surface: run, run*, fresh, conde, defrel, as macros
;;
;; Called with symbol heads like any fn, (rs/run* q g …). Rules learned in probes/mk/:
;; - A computed unquote ~(expr) in a template has the macro's params SUBSTITUTED into expr as
;;   code, so ~(first form) would evaluate form. Arguments are taken apart in a PROGRAM body
;;   (a let or if outside the template), where params are bound as data; the templates use
;;   only plain ~x and ~@xs.
;; - A macro may not call a user defn at expansion time (the F5 purity gate). A helper that
;;   walks a list is a second macro that recurses by expanding to itself.
;; - A program body's template may not introduce a literal binder (hygiene gate E), so run
;;   hands the several-variable case to a pure template macro, where q0 is renamed hygienically.
;; - In a program body, ~@ splices a list form but not a vector form [...] (F-021), so a
;;   parameter list is carried between expansions as a list.
;; - Nothing emits an empty () into code (F-004): each recursion stops one element early.

;; (run n q g …) or (run n (x …) g …)
(:wat::core::defmacro :rs::run
  [n <- :wat::WatAST q <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::if (:wat::core::List? q)
    `(:rs::run-vars ~n ~q ~@goals)
    `(rs/run-goal ~n (:wat::core::fn [~q <- :rs::Term] -> :rs::Goal (rs/conj [~@goals])))))

(:wat::core::defmacro :rs::run-vars
  [n <- :wat::WatAST vars <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  `(rs/run-goal ~n (:wat::core::fn [q0 <- :rs::Term] -> :rs::Goal
                     (:rs::fresh ~vars (rs/== q0 (rs/list [~@vars])) ~@goals))))

;; (run* q g …) or (run* (x …) g …)
(:wat::core::defmacro :rs::run*
  [q <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  `(:rs::run -1 ~q ~@goals))

;; (fresh (x …) g …)
(:wat::core::defmacro :rs::fresh
  [vars <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::if (:wat::core::empty? vars)
    `(rs/conj [~@goals])
    (:wat::core::let [v (:wat::core::first vars)
                      more (:wat::core::rest vars)]
      (:wat::core::if (:wat::core::empty? more)
        `(rs/call-fresh (:wat::core::fn [~v <- :rs::Term] -> :rs::Goal (rs/conj [~@goals])))
        `(rs/call-fresh (:wat::core::fn [~v <- :rs::Term] -> :rs::Goal (:rs::fresh ~more ~@goals)))))))

;; (conde (g …) …): each line a conjunction, the lines a disjunction.
(:wat::core::defmacro :rs::conde
  [& lines <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [conjs (:wat::core::foldl
                            (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::WatAST]) line <- :wat::WatAST]
                              -> (:wat::core::Vector :- [:wat::WatAST])
                              (:wat::core::conj acc `(rs/conj [~@line])))
                            [] lines)]
    `(rs/disj [~@conjs])))

;; (defrel (name arg …) g …): a defn whose body is built only when the goal runs.
(:wat::core::defmacro :rs::defrel
  [head <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [name (:wat::core::first head)
                    args (:wat::core::rest head)]
    (:wat::core::if (:wat::core::empty? args)
      `(:wat::core::defn ~name [] -> :rs::Goal
         (rs/delay (:wat::core::fn [] -> :rs::Goal (rs/conj [~@goals]))))
      `(:rs::defrel-params ~name (params) ~args ~@goals))))

;; Moves one arg at a time into the typed parameter list (params x <- :rs::Term …), then
;; emits the defn.
(:wat::core::defmacro :rs::defrel-params
  [name <- :wat::WatAST typed <- :wat::WatAST args <- :wat::WatAST
   & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [ps (:wat::core::rest typed)
                    a (:wat::core::first args)
                    more (:wat::core::rest args)]
    (:wat::core::if (:wat::core::empty? more)
      `(:wat::core::defn ~name [~@ps ~a <- :rs::Term] -> :rs::Goal
         (rs/delay (:wat::core::fn [] -> :rs::Goal (rs/conj [~@goals]))))
      `(:rs::defrel-params ~name (params ~@ps ~a <- :rs::Term) ~more ~@goals))))

;; (conda (g0 g …) …): the first line whose g0 succeeds is the only line tried.
(:wat::core::defmacro :rs::conda
  [& lines <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [line (:wat::core::first lines)
                    more (:wat::core::rest lines)
                    g0 (:wat::core::first line)
                    gs (:wat::core::rest line)]
    (:wat::core::if (:wat::core::empty? more)
      `(rs/conj [~@line])
      `(rs/ifte ~g0 (rs/conj [~@gs]) (:rs::conda ~@more)))))

;; (condu (g0 g …) …): conda, with each g0 limited to its first answer.
(:wat::core::defmacro :rs::condu
  [& lines <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [onced (:wat::core::foldl
                            (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::WatAST]) line <- :wat::WatAST]
                              -> (:wat::core::Vector :- [:wat::WatAST])
                              (:wat::core::let [g0 (:wat::core::first line)
                                                gs (:wat::core::rest line)]
                                (:wat::core::conj acc `((rs/once ~g0) ~@gs))))
                            [] lines)]
    `(:rs::conda ~@onced)))
