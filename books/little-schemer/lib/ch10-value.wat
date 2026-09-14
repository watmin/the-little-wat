;; The Little Schemer, ch 10 (What Is the Value of All of This?): the definitions. An
;; interpreter for the book's little language, written over S-expressions. Everything
;; lives in the lsi/ namespace (little-schemer interpreter), so value, meaning and apply
;; cannot collide with earlier chapters' names.
;;
;; The interpreted language's values are S-expressions too:
;;   - numbers and true/false stand for themselves
;;   - a primitive is (primitive name)
;;   - a closure is (non-primitive (table formals body))
;; An entry is a pair (names values), and a table is a list of entries.
;;
;; Needs, in order: lib/ch01-toys.wat, ch02 (member?), ch03, ch04 (number?, ast->i64,
;; add1, sub1, zero?) and ch07 (first, second, build). No main here.
;; The book's :atom? is spelled lsi/atom-value? here; a colon-led name is not valid in the
;; Clojure/EDN spelling.

;; ── entries and tables ─────────────────────────────────────────────────────────────

(wat.core/defn lsi/new-entry [names :- :wat::WatAST values :- :wat::WatAST] :- :wat::WatAST
  (ls/build names values))

(wat.core/defn lsi/lookup-in-entry-help [name    :- :wat::WatAST
                                         names   :- :wat::WatAST
                                         values  :- :wat::WatAST
                                         entry-f :- [:wat::WatAST :-> :wat::WatAST]]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? names) (entry-f name))
    ((ls/eq? (ls/car names) name) (ls/car values))
    (:else (lsi/lookup-in-entry-help name (ls/cdr names) (ls/cdr values) entry-f))))

(wat.core/defn lsi/lookup-in-entry [name    :- :wat::WatAST
                                    entry   :- :wat::WatAST
                                    entry-f :- [:wat::WatAST :-> :wat::WatAST]]
  :- :wat::WatAST
  (lsi/lookup-in-entry-help name (ls/first entry) (ls/second entry) entry-f))

(wat.core/defn lsi/extend-table [entry :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (ls/cons entry table))

;; lookup-in-table: search each entry in turn. What to do on a miss is passed along as a
;; function (table-f), the ch 8 collector idea again.
(wat.core/defn lsi/lookup-in-table [name    :- :wat::WatAST
                                    table   :- :wat::WatAST
                                    table-f :- [:wat::WatAST :-> :wat::WatAST]]
  :- :wat::WatAST
  (wat.core/if (ls/null? table)
    (table-f name)
    (lsi/lookup-in-entry name (ls/car table)
      (wat.core/fn [n :- :wat::WatAST] :- :wat::WatAST
        (lsi/lookup-in-table n (ls/cdr table) table-f)))))

;; ── from an expression to the action that gives its meaning ────────────────────────

(wat.core/defn lsi/primitive-name? [x :- :wat::WatAST] :- wat.type/bool
  (ls/member? x (wat.core/quote (cons car cdr null? eq? atom? zero? add1 sub1 number?))))

(wat.core/defn lsi/boolean? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/= (wat.core/ast-kind x) "bool"))

(wat.core/defn lsi/atom-to-action [e :- :wat::WatAST]
  :- [:wat::WatAST :wat::WatAST :-> :wat::WatAST]
  (wat.core/cond
    ((ls/number? e) lsi/*const)
    ((lsi/boolean? e) lsi/*const)
    ((lsi/primitive-name? e) lsi/*const)
    (:else lsi/*identifier)))

(wat.core/defn lsi/list-to-action [e :- :wat::WatAST]
  :- [:wat::WatAST :wat::WatAST :-> :wat::WatAST]
  (wat.core/if (ls/atom? (ls/car e))
    (wat.core/cond
      ((ls/eq? (ls/car e) (wat.core/quote quote)) lsi/*quote)
      ((ls/eq? (ls/car e) (wat.core/quote lambda)) lsi/*lambda)
      ((ls/eq? (ls/car e) (wat.core/quote cond)) lsi/*cond)
      (:else lsi/*application))
    lsi/*application))

(wat.core/defn lsi/expression-to-action [e :- :wat::WatAST]
  :- [:wat::WatAST :wat::WatAST :-> :wat::WatAST]
  (wat.core/if (ls/atom? e) (lsi/atom-to-action e) (lsi/list-to-action e)))

(wat.core/defn lsi/meaning [e :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  ((lsi/expression-to-action e) e table))

(wat.core/defn lsi/value [e :- :wat::WatAST] :- :wat::WatAST
  (lsi/meaning e (ls/empty-list)))

;; ── the actions ────────────────────────────────────────────────────────────────────

(wat.core/defn lsi/*const [e :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/number? e) e)
    ((lsi/boolean? e) e)
    (:else (ls/build (wat.core/quote primitive) e))))

(wat.core/defn lsi/text-of [e :- :wat::WatAST] :- :wat::WatAST
  (ls/second e))

(wat.core/defn lsi/*quote [e :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (lsi/text-of e))

;; An unbound name: the book's (car (quote ())). Taking the first of an empty list raises.
(wat.core/defn lsi/initial-table [name :- :wat::WatAST] :- :wat::WatAST
  (ls/car (ls/empty-list)))

(wat.core/defn lsi/*identifier [e :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (lsi/lookup-in-table e table lsi/initial-table))

;; (lambda formals body) in table becomes the closure (non-primitive (table formals body)).
(wat.core/defn lsi/*lambda [e :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (ls/build (wat.core/quote non-primitive) (ls/cons table (ls/cdr e))))

(wat.core/defn lsi/table-of [closure :- :wat::WatAST] :- :wat::WatAST
  (ls/first closure))

(wat.core/defn lsi/formals-of [closure :- :wat::WatAST] :- :wat::WatAST
  (ls/second closure))

(wat.core/defn lsi/body-of [closure :- :wat::WatAST] :- :wat::WatAST
  (ls/car (ls/cdr (ls/cdr closure))))

;; cond

(wat.core/defn lsi/else? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/and (ls/atom? x) (ls/eq? x (wat.core/quote else))))

(wat.core/defn lsi/question-of [line :- :wat::WatAST] :- :wat::WatAST
  (ls/first line))

(wat.core/defn lsi/answer-of [line :- :wat::WatAST] :- :wat::WatAST
  (ls/second line))

(wat.core/defn lsi/cond-lines-of [e :- :wat::WatAST] :- :wat::WatAST
  (ls/cdr e))

(wat.core/defn lsi/true? [v :- :wat::WatAST] :- wat.type/bool
  (ls/eq? v (wat.core/quote true)))

(wat.core/defn lsi/evcon [lines :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((lsi/else? (lsi/question-of (ls/car lines)))
     (lsi/meaning (lsi/answer-of (ls/car lines)) table))
    ((lsi/true? (lsi/meaning (lsi/question-of (ls/car lines)) table))
     (lsi/meaning (lsi/answer-of (ls/car lines)) table))
    (:else (lsi/evcon (ls/cdr lines) table))))

(wat.core/defn lsi/*cond [e :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (lsi/evcon (lsi/cond-lines-of e) table))

;; application

(wat.core/defn lsi/evlis [args :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/null? args)
    (ls/empty-list)
    (ls/cons (lsi/meaning (ls/car args) table) (lsi/evlis (ls/cdr args) table))))

(wat.core/defn lsi/function-of [e :- :wat::WatAST] :- :wat::WatAST
  (ls/car e))

(wat.core/defn lsi/arguments-of [e :- :wat::WatAST] :- :wat::WatAST
  (ls/cdr e))

(wat.core/defn lsi/primitive? [l :- :wat::WatAST] :- wat.type/bool
  (ls/eq? (ls/first l) (wat.core/quote primitive)))

(wat.core/defn lsi/non-primitive? [l :- :wat::WatAST] :- wat.type/bool
  (ls/eq? (ls/first l) (wat.core/quote non-primitive)))

(wat.core/defn lsi/*application [e :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (lsi/apply (lsi/meaning (lsi/function-of e) table)
             (lsi/evlis (lsi/arguments-of e) table)))

;; Applying something that is neither kind of function raises, like an unbound name.
(wat.core/defn lsi/apply [fun :- :wat::WatAST vals :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((lsi/primitive? fun) (lsi/apply-primitive (ls/second fun) vals))
    ((lsi/non-primitive? fun) (lsi/apply-closure (ls/second fun) vals))
    (:else (ls/car (ls/empty-list)))))

;; primitives

(wat.core/defn lsi/bool [b :- wat.type/bool] :- :wat::WatAST
  (wat.core/if b (wat.core/quote true) (wat.core/quote false)))

(wat.core/defn lsi/num [n :- wat.type/i64] :- :wat::WatAST
  (wat.core/quasiquote ~n))

;; the book's :atom?: primitives and closures count as atoms in the interpreted language
(wat.core/defn lsi/atom-value? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((ls/atom? x) true)
    ((ls/null? x) false)
    ((ls/eq? (ls/car x) (wat.core/quote primitive)) true)
    ((ls/eq? (ls/car x) (wat.core/quote non-primitive)) true)
    (:else false)))

(wat.core/defn lsi/apply-primitive [name :- :wat::WatAST vals :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/eq? name (wat.core/quote cons)) (ls/cons (ls/first vals) (ls/second vals)))
    ((ls/eq? name (wat.core/quote car)) (ls/car (ls/first vals)))
    ((ls/eq? name (wat.core/quote cdr)) (ls/cdr (ls/first vals)))
    ((ls/eq? name (wat.core/quote null?)) (lsi/bool (ls/null? (ls/first vals))))
    ((ls/eq? name (wat.core/quote eq?)) (lsi/bool (ls/eq? (ls/first vals) (ls/second vals))))
    ((ls/eq? name (wat.core/quote atom?)) (lsi/bool (lsi/atom-value? (ls/first vals))))
    ((ls/eq? name (wat.core/quote zero?)) (lsi/bool (ls/zero? (ls/ast->i64 (ls/first vals)))))
    ((ls/eq? name (wat.core/quote add1)) (lsi/num (ls/add1 (ls/ast->i64 (ls/first vals)))))
    ((ls/eq? name (wat.core/quote sub1)) (lsi/num (ls/sub1 (ls/ast->i64 (ls/first vals)))))
    (:else (lsi/bool (ls/number? (ls/first vals))))))

;; a closure's body, evaluated in its own table extended with formals bound to the values
(wat.core/defn lsi/apply-closure [closure :- :wat::WatAST vals :- :wat::WatAST] :- :wat::WatAST
  (lsi/meaning (lsi/body-of closure)
               (lsi/extend-table (lsi/new-entry (lsi/formals-of closure) vals)
                                 (lsi/table-of closure))))
