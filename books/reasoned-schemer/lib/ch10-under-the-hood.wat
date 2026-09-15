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

;; (conde [g …] …): each line is a conjunction, the lines a disjunction.
(wat.core/defn rs/conde [lines :- (wat.type/Vector :- [(wat.type/Vector :- [:rs::Goal])])] :- :rs::Goal
  (rs/disj (wat.core/into [] (:wat::core::map (wat.core/fn [line :- (wat.type/Vector :- [:rs::Goal])] :- :rs::Goal (rs/conj line))
                                              lines))))

;; fresh: f receives new variables and returns the goal that uses them.
(wat.core/defn rs/fresh [f :- [:rs::Term :-> :rs::Goal]] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream
    (wat.core/let [c (:rs::State/c st)]
      ((f (rs/var c)) (:rs::State :s (:rs::State/s st) :c (wat.core/+ c 1))))))

(wat.core/defn rs/fresh2 [f :- [:rs::Term :rs::Term :-> :rs::Goal]] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream
    (wat.core/let [c (:rs::State/c st)]
      ((f (rs/var c) (rs/var (wat.core/+ c 1))) (:rs::State :s (:rs::State/s st) :c (wat.core/+ c 2))))))

(wat.core/defn rs/fresh3 [f :- [:rs::Term :rs::Term :rs::Term :-> :rs::Goal]] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream
    (wat.core/let [c (:rs::State/c st)]
      ((f (rs/var c) (rs/var (wat.core/+ c 1)) (rs/var (wat.core/+ c 2)))
       (:rs::State :s (:rs::State/s st) :c (wat.core/+ c 3))))))

;; The book's defrel: a relation's body is built only when the goal runs, behind a
;; suspension. Without it, a recursive relation would build its goal tree forever before
;; running at all.
(wat.core/defn rs/delay [body :- [:-> :rs::Goal]] :- :rs::Goal
  (wat.core/fn [st :- :rs::State] :- :rs::Stream
    (:wat::stream::lazy
      (:wat::stream::cons :wat::core::Option.None (:wat::stream::lazy ((body) st))))))

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

;; (run n q g): the first n values of the query variable q, as a quoted list. q is variable 0.
(wat.core/defn rs/run [n :- wat.type/i64 f :- [:rs::Term :-> :rs::Goal]] :- :wat::WatAST
  (wat.core/let [q (rs/var 0)
                 sts (rs/take n [] ((f q) (rs/start)))]
    (:wat::core::foldl (wat.core/fn [acc :- :wat::WatAST st :- :rs::State] :- :wat::WatAST
                         (wat.core/quasiquote (~@acc ~(rs/reify q st))))
                       '() sts)))

(wat.core/defn rs/run* [f :- [:rs::Term :-> :rs::Goal]] :- :wat::WatAST
  (rs/run -1 f))

;; (run n (x y) g): each value is the list (x y).
(wat.core/defn rs/run2 [n :- wat.type/i64 f :- [:rs::Term :rs::Term :-> :rs::Goal]] :- :wat::WatAST
  (rs/run n (wat.core/fn [q :- :rs::Term] :- :rs::Goal
              (rs/fresh2 (:wat::core::fn [x <- :rs::Term y <- :rs::Term] -> :rs::Goal
                           (rs/conj [(rs/== q (rs/list [x y])) (f x y)]))))))
