;; eopl/ch01-inductive-sets.wat — EOPL chapter 1: inductive sets of data.
;;
;; The chapter's method, and the only thing it really teaches, is FOLLOW THE GRAMMAR: write one
;; clause per production, and recur exactly where the grammar recurs. Every later chapter is that
;; discipline applied to bigger grammars.
;;
;; It ports to wat almost too cleanly, and the reason is worth naming: an inductive definition IS
;; a `defenum`, and "one clause per production" IS an exhaustive `match`. wat's refusal of a `_`
;; wildcard (this repository's own house rule, and the checker's non-exhaustive error) turns the
;; chapter's advice into something the compiler enforces. C-059's note on annotations is the same
;; observation from the other end.

;;   Lc-exp ::= Identifier | (lambda (Identifier) Lc-exp) | (Lc-exp Lc-exp)
(:wat::core::defenum :c1::Lc :wat::enum::Pure
  :Var [name <- :wat::core::String]
  :Lam [bound <- :wat::core::String  body <- :c1::Lc]
  :App [rator <- :c1::Lc  rand <- :c1::Lc])

;; occurs-free? — EOPL 1.2.4. One clause per production; the `lambda` clause is the only one that
;; does anything but recur, and it is where variable binding lives.
(:wat::core::defn :c1::occurs-free? [x <- :wat::core::String e <- :c1::Lc] -> :wat::core::bool
  (:wat::core::match e
    [:c1::Lc.Var {:name n} (:wat::core::= n x)]
    [:c1::Lc.Lam {:bound b :body body}
      (:wat::core::and (:wat::core::not (:wat::core::= b x)) (:c1::occurs-free? x body))]
    [:c1::Lc.App {:rator rator :rand rand}
      (:wat::core::or (:c1::occurs-free? x rator) (:c1::occurs-free? x rand))]))

(:wat::core::defn :c1::show [e <- :c1::Lc] -> :wat::core::String
  (:wat::core::match e
    [:c1::Lc.Var {:name n} n]
    [:c1::Lc.Lam {:bound b :body body}
      (:wat::string::concat "(lambda (" b ") " (:c1::show body) ")")]
    [:c1::Lc.App {:rator rator :rand rand}
      (:wat::string::concat "(" (:c1::show rator) " " (:c1::show rand) ")")]))

;;   List-of-Int ::= () | (Int . List-of-Int)      -- the chapter's other running grammar
(:wat::core::defenum :c1::Ints :wat::enum::Pure
  :Empty [] :Cons [head <- :wat::core::i64  tail <- :c1::Ints])

(:wat::core::defn :c1::list-length [l <- :c1::Ints] -> :wat::core::i64
  (:wat::core::match l
    [:c1::Ints.Empty {} 0]
    [:c1::Ints.Cons {:head h :tail t} (:wat::core::+ 1 (:c1::list-length t))]))

;; nth-element — EOPL 1.2.2, including the book's insistence on a REPORTING error rather than a
;; silent wrong answer. wat has no exceptions here, so it answers an Option, which is the same
;; discipline with a type behind it.
(:wat::core::defn :c1::nth-element [l <- :c1::Ints n <- :wat::core::i64]
  -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match l
    [:c1::Ints.Empty {} (:wat::core::Option.None {})]
    [:c1::Ints.Cons {:head h :tail t}
      (:wat::core::if (:wat::core::= n 0)
        (:wat::core::Option.Some {:value h})
        (:c1::nth-element t (:wat::core::- n 1)))]))

;; remove-first — EOPL 1.2.3
(:wat::core::defn :c1::remove-first [x <- :wat::core::i64 l <- :c1::Ints] -> :c1::Ints
  (:wat::core::match l
    [:c1::Ints.Empty {} l]
    [:c1::Ints.Cons {:head h :tail t}
      (:wat::core::if (:wat::core::= h x) t
        (:c1::Ints.Cons {:head h :tail (:c1::remove-first x t)}))]))

(:wat::core::defn :c1::show-ints [l <- :c1::Ints] -> :wat::core::String
  (:wat::core::match l
    [:c1::Ints.Empty {} "()"]
    [:c1::Ints.Cons {:head h :tail t}
      (:wat::string::concat "(" (:wat::i64::to-string h) " . " (:c1::show-ints t) ")")]))

;; subst — EOPL 1.2.5, over a list rather than an Lc-exp, because the chapter's point there is
;; that a grammar with TWO non-terminals wants TWO procedures, not one with a flag.
(:wat::core::defn :c1::subst [new <- :wat::core::i64 old <- :wat::core::i64 l <- :c1::Ints] -> :c1::Ints
  (:wat::core::match l
    [:c1::Ints.Empty {} l]
    [:c1::Ints.Cons {:head h :tail t}
      (:c1::Ints.Cons {:head (:c1::subst-in-item new old h) :tail (:c1::subst new old t)})]))

(:wat::core::defn :c1::subst-in-item [new <- :wat::core::i64 old <- :wat::core::i64 h <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= h old) new h))

(:wat::core::defn :c1::ints3 [a <- :wat::core::i64 b <- :wat::core::i64 c <- :wat::core::i64] -> :c1::Ints
  (:c1::Ints.Cons {:head a :tail (:c1::Ints.Cons {:head b :tail (:c1::Ints.Cons {:head c :tail (:c1::Ints.Empty {})})})}))

(:wat::core::defn :c1::yes [label <- :wat::core::String got <- :wat::core::bool want <- :wat::core::bool] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " (:wat::core::if got "true " "false")
      (:wat::core::if (:wat::core::= got want) "   PASS" "   FAIL"))))

(:wat::core::defn :c1::num [label <- :wat::core::String got <- :wat::core::i64 want <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " (:wat::i64::to-string got)
      (:wat::core::if (:wat::core::= got want) "   PASS" "   FAIL"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [;; (lambda (x) (x y))   -- y free, x bound
                    e1 (:c1::Lc.Lam {:bound "x"
                                     :body (:c1::Lc.App {:rator (:c1::Lc.Var {:name "x"})
                                                         :rand (:c1::Lc.Var {:name "y"})})})
                    ;; (lambda (y) (lambda (x) (x y)))  -- nothing free
                    e2 (:c1::Lc.Lam {:bound "y" :body e1})
                    l (:c1::ints3 4 7 4)]
    (:wat::core::do
      (:wat::kernel::println "---- EOPL ch1: follow the grammar ----")
      (:wat::kernel::println (:wat::string::concat "e1 = " (:c1::show e1)))
      (:wat::kernel::println (:wat::string::concat "e2 = " (:c1::show e2)))
      (:c1::yes "occurs-free? y e1 " (:c1::occurs-free? "y" e1) true)
      (:c1::yes "occurs-free? x e1 " (:c1::occurs-free? "x" e1) false)
      (:c1::yes "occurs-free? y e2 " (:c1::occurs-free? "y" e2) false)

      (:wat::kernel::println "---- lists ----")
      (:wat::kernel::println (:wat::string::concat "l = " (:c1::show-ints l)))
      (:c1::num "list-length       " (:c1::list-length l) 3)
      (:c1::num "nth-element 1     "
        (:wat::core::match (:c1::nth-element l 1)
          [:wat::core::Option.Some {:value v} v]
          [:wat::core::Option.None {} -1]) 7)
      ;; out of range REPORTS rather than guessing -- EOPL 1.2.2's whole point about nth-element
      (:c1::num "nth-element 9     "
        (:wat::core::match (:c1::nth-element l 9)
          [:wat::core::Option.Some {:value v} v]
          [:wat::core::Option.None {} -1]) -1)
      (:wat::kernel::println (:wat::string::concat "remove-first 4    " (:c1::show-ints (:c1::remove-first 4 l))))
      (:wat::kernel::println (:wat::string::concat "subst 9 for 4     " (:c1::show-ints (:c1::subst 9 4 l))))

      (:wat::kernel::println "---- why this chapter is short in wat ----")
      (:wat::kernel::println "  an inductive definition IS a defenum; one clause per production IS")
      (:wat::kernel::println "  an exhaustive match. The checker rejects a missing clause, so the")
      (:wat::kernel::println "  chapter's advice is enforced rather than remembered."))))
