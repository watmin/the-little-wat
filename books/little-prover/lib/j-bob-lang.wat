;; The Little Prover: J-Bob's language primitives in wat. Our own code, after
;; vendor/j-bob/j-bob-lang.scm (BSD 2-Clause, Friedman and Eastlund).
;; Needs ../little-schemer/lib/ch01-toys.wat and ../little-schemer/lib/ch04-numbers-games.wat.
;;
;; J-Bob's values are S-expressions, here :wat::WatAST. Its true is the symbol t and its false
;; the symbol nil. wat's reader reads nil as its own nil literal; either way, nil stays
;; distinct from the empty list (). Every primitive is total, as J-Bob's are: car and cdr of
;; an atom are (), and + and < treat a non-number as 0.

(wat.core/defn jb/true? [q :- :wat::WatAST] :- wat.type/bool
  (wat.core/not (wat.core/= q 'nil)))

(wat.core/defn jb/pair? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/and (wat.core/= (wat.core/ast-kind x) "list") (wat.core/not (wat.core/empty? x))))

(wat.core/defn jb/atom [x :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (jb/pair? x) 'nil 't))

(wat.core/defn jb/car [x :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (jb/pair? x) (wat.core/first x) '()))

(wat.core/defn jb/cdr [x :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (jb/pair? x) (wat.core/rest x) '()))

;; A quoted list cannot end in anything but (): WatAST has no dotted pair. So consing onto a
;; non-list fails loudly rather than building something else.
(wat.core/defn jb/cons [a :- :wat::WatAST d :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (wat.core/= (wat.core/ast-kind d) "list")
    (wat.core/quasiquote (~a ~@d))
    (:wat::kernel::assertion-failed! :message "jb/cons: cons onto a non-list (WatAST has no dotted pair)")))

(wat.core/defn jb/equal [x :- :wat::WatAST y :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (wat.core/= x y) 't 'nil))

(wat.core/defn jb/num [x :- :wat::WatAST] :- wat.type/i64
  (wat.core/if (wat.core/= (wat.core/ast-kind x) "int") (ls/ast->i64 x) 0))

(wat.core/defn jb/natp [x :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (wat.core/and (wat.core/= (wat.core/ast-kind x) "int")
                             (wat.core/not (wat.core/< (ls/ast->i64 x) 0)))
    't
    'nil))

(wat.core/defn jb/plus [x :- :wat::WatAST y :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [n (wat.core/+ (jb/num x) (jb/num y))]
    (wat.core/quasiquote ~n)))

(wat.core/defn jb/lt [x :- :wat::WatAST y :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (wat.core/< (jb/num x) (jb/num y)) 't 'nil))

;; (defun size (x) (if (atom x) '0 (+ '1 (+ (size (car x)) (size (cdr x))))))
(wat.core/defn jb/size [x :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (jb/true? (jb/atom x))
    '0
    (jb/plus '1 (jb/plus (jb/size (jb/car x)) (jb/size (jb/cdr x))))))
