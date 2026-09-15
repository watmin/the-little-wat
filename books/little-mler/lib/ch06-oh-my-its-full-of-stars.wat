;; The Little MLer, chapter 6 (Oh My, It's Full of Stars!): trees of fruit, and S-expressions
;; as two mutually recursive generic datatypes. Our own code. Every match names every
;; variant; where ML matches a nested pattern such as Scons(An_atom(b), y), we bind the field
;; and match it in its own match (nested arms never count as coverage, F-028).

(:wat::core::defenum :ml::Fruit :wat::enum::Pure :Peach [] :Apple [] :Pear [] :Lemon [] :Fig [])

;; datatype tree = Bud | Flat of fruit * tree | Split of tree * tree
(:wat::core::defenum :ml::Tree :wat::enum::Pure
  :Bud   []
  :Flat  [f <- :ml::Fruit  t <- :ml::Tree]
  :Split [l <- :ml::Tree  r <- :ml::Tree])

(wat.core/defn ml/fruit [name :- :wat::WatAST] :- :ml::Fruit
  (wat.core/cond
    ((wat.core/= name 'peach) (:ml::Fruit.Peach {}))
    ((wat.core/= name 'apple) (:ml::Fruit.Apple {}))
    ((wat.core/= name 'pear) (:ml::Fruit.Pear {}))
    ((wat.core/= name 'lemon) (:ml::Fruit.Lemon {}))
    ((wat.core/= name 'fig) (:ml::Fruit.Fig {}))
    (:else (:wat::kernel::assertion-failed! :message "fruit: unknown fruit"))))

(wat.core/defn ml/bud [] :- :ml::Tree (:ml::Tree.Bud {}))
(wat.core/defn ml/flat [f :- :ml::Fruit t :- :ml::Tree] :- :ml::Tree (:ml::Tree.Flat {:f f :t t}))
(wat.core/defn ml/split [l :- :ml::Tree r :- :ml::Tree] :- :ml::Tree (:ml::Tree.Split {:l l :r r}))

(wat.core/defn ml/flat-only [t :- :ml::Tree] :- wat.type/bool
  (:wat::core::match t
    [:ml::Tree.Bud {} true]
    [:ml::Tree.Flat {:f _f :t rest} (ml/flat-only rest)]
    [:ml::Tree.Split {:l _l :r _r} false]))

(wat.core/defn ml/split-only [t :- :ml::Tree] :- wat.type/bool
  (:wat::core::match t
    [:ml::Tree.Bud {} true]
    [:ml::Tree.Flat {:f _f :t _rest} false]
    [:ml::Tree.Split {:l l :r r} (wat.core/and (ml/split-only l) (ml/split-only r))]))

(wat.core/defn ml/contains-fruit [t :- :ml::Tree] :- wat.type/bool
  (:wat::core::match t
    [:ml::Tree.Bud {} false]
    [:ml::Tree.Flat {:f _f :t _rest} true]
    [:ml::Tree.Split {:l l :r r} (wat.core/or (ml/contains-fruit l) (ml/contains-fruit r))]))

(wat.core/defn ml/larger-of [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/> a b) a b))

(wat.core/defn ml/height [t :- :ml::Tree] :- wat.type/i64
  (:wat::core::match t
    [:ml::Tree.Bud {} 0]
    [:ml::Tree.Flat {:f _f :t rest} (wat.core/+ 1 (ml/height rest))]
    [:ml::Tree.Split {:l l :r r} (wat.core/+ 1 (ml/larger-of (ml/height l) (ml/height r)))]))

;; Replace every fruit a by n.
(wat.core/defn ml/subst-in-tree [n :- :ml::Fruit a :- :ml::Fruit t :- :ml::Tree] :- :ml::Tree
  (:wat::core::match t
    [:ml::Tree.Bud {} (ml/bud)]
    [:ml::Tree.Flat {:f f :t rest}
      (ml/flat (wat.core/if (wat.core/= f a) n f) (ml/subst-in-tree n a rest))]
    [:ml::Tree.Split {:l l :r r} (ml/split (ml/subst-in-tree n a l) (ml/subst-in-tree n a r))]))

;; How many times fruit a occurs.
(wat.core/defn ml/occurs [a :- :ml::Fruit t :- :ml::Tree] :- wat.type/i64
  (:wat::core::match t
    [:ml::Tree.Bud {} 0]
    [:ml::Tree.Flat {:f f :t rest} (wat.core/+ (wat.core/if (wat.core/= f a) 1 0) (ml/occurs a rest))]
    [:ml::Tree.Split {:l l :r r} (wat.core/+ (ml/occurs a l) (ml/occurs a r))]))

;; datatype 'a slist = Empty | Scons of ('a sexp) * ('a slist)
;; and      'a sexp  = An_atom of 'a | A_slist of ('a slist)
(:wat::core::defenum :ml::Slist :- [A] :wat::enum::Pure
  :Empty []
  :Scons [head <- (:ml::Sexp :- [A])  tail <- (:ml::Slist :- [A])])

(:wat::core::defenum :ml::Sexp :- [A] :wat::enum::Pure
  :AnAtom [v <- A]
  :ASlist [l <- (:ml::Slist :- [A])])

(wat.core/defn ml/empty :- [A] [] :- (:ml::Slist :- [A]) (:ml::Slist.Empty {}))
(wat.core/defn ml/scons :- [A] [h :- (:ml::Sexp :- [A]) t :- (:ml::Slist :- [A])] :- (:ml::Slist :- [A])
  (:ml::Slist.Scons {:head h :tail t}))
(wat.core/defn ml/an-atom :- [A] [v :- A] :- (:ml::Sexp :- [A]) (:ml::Sexp.AnAtom {:v v}))
(wat.core/defn ml/a-slist :- [A] [l :- (:ml::Slist :- [A])] :- (:ml::Sexp :- [A]) (:ml::Sexp.ASlist {:l l}))

;; A fruit slist from quoted data: '(fig (apple fig) peach).
(wat.core/defn ml/fruit-sexp [x :- :wat::WatAST] :- (:ml::Sexp :- [:ml::Fruit])
  (wat.core/if (wat.core/= (wat.core/ast-kind x) "list")
    (ml/a-slist (ml/fruit-slist x))
    (ml/an-atom (ml/fruit x))))

(wat.core/defn ml/fruit-slist [xs :- :wat::WatAST] :- (:ml::Slist :- [:ml::Fruit])
  (wat.core/if (wat.core/empty? xs)
    (ml/empty)
    (ml/scons (ml/fruit-sexp (wat.core/first xs)) (ml/fruit-slist (wat.core/rest xs)))))

(wat.core/defn ml/occurs-in-slist :- [A] [a :- A l :- (:ml::Slist :- [A])] :- wat.type/i64
  (:wat::core::match l
    [:ml::Slist.Empty {} 0]
    [:ml::Slist.Scons {:head h :tail t} (wat.core/+ (ml/occurs-in-sexp a h) (ml/occurs-in-slist a t))]))

(wat.core/defn ml/occurs-in-sexp :- [A] [a :- A s :- (:ml::Sexp :- [A])] :- wat.type/i64
  (:wat::core::match s
    [:ml::Sexp.AnAtom {:v v} (wat.core/if (wat.core/= v a) 1 0)]
    [:ml::Sexp.ASlist {:l l} (ml/occurs-in-slist a l)]))

(wat.core/defn ml/subst-in-slist :- [A] [n :- A a :- A l :- (:ml::Slist :- [A])] :- (:ml::Slist :- [A])
  (:wat::core::match l
    [:ml::Slist.Empty {} (ml/empty)]
    [:ml::Slist.Scons {:head h :tail t} (ml/scons (ml/subst-in-sexp n a h) (ml/subst-in-slist n a t))]))

(wat.core/defn ml/subst-in-sexp :- [A] [n :- A a :- A s :- (:ml::Sexp :- [A])] :- (:ml::Sexp :- [A])
  (:wat::core::match s
    [:ml::Sexp.AnAtom {:v v} (ml/an-atom (wat.core/if (wat.core/= v a) n v))]
    [:ml::Sexp.ASlist {:l l} (ml/a-slist (ml/subst-in-slist n a l))]))

;; Remove every atom a, at any depth. ML matches Scons(An_atom(b), y) and
;; Scons(A_slist(x), y) as two nested arms; here the head is bound and matched on its own.
(wat.core/defn ml/rem-from-slist :- [A] [a :- A l :- (:ml::Slist :- [A])] :- (:ml::Slist :- [A])
  (:wat::core::match l
    [:ml::Slist.Empty {} (ml/empty)]
    [:ml::Slist.Scons {:head h :tail t}
      (:wat::core::match h
        [:ml::Sexp.AnAtom {:v v}
          (wat.core/if (wat.core/= v a)
            (ml/rem-from-slist a t)
            (ml/scons h (ml/rem-from-slist a t)))]
        [:ml::Sexp.ASlist {:l inner}
          (ml/scons (ml/a-slist (ml/rem-from-slist a inner)) (ml/rem-from-slist a t))])]))
