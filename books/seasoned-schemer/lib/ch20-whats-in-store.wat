;; The Seasoned Schemer, ch 20 (What's in Store?): the definitions. An interpreter whose
;; language has define, set!, closures with private mutable state, and letcc. Everything
;; lives in the ssi/ namespace (seasoned-schemer interpreter).
;;
;; How the pieces map onto wat:
;;   - the store is a global Arena (lib/arena.wat): a box is a node id, unbox is kar, and
;;     setbox is set-kar!;
;;   - tables are data, ((name id) ...); a lookup falls back to the global table, which is
;;     held in a Cell (lib/cell.wat) and extended by define. Recursive definitions find
;;     themselves through it;
;;   - the language's values are all data: numbers and true/false stand for themselves, a
;;     primitive is (primitive name), a closure is (non-primitive (table formals body ...)),
;;     and a continuation is (continuation id), with a fresh id per letcc;
;;   - every meaning returns a Result. Calling a continuation returns Err (id value), which
;;     travels through Result/try until the letcc with that id catches it. So the language
;;     gets escaping continuations, which wat itself does not have (FINDINGS.md, R-003).
;; meaning dispatches with one cond, rather than the book's table of action functions.
;;
;; Needs, in order: lib/cell.wat, lib/arena.wat, and the Little Schemer libs ch01, ch02,
;; ch03, ch04, ch07 and ch10 (the lsi/ helpers). No main here.

(:wat::core::def :ssi::store (:ss::new-arena))
(:wat::core::def :ssi::global (:ss::new-cell '()))

(wat.core/defn ssi/ok [v :- :wat::WatAST] :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (:wat::core::Result.Ok {:value v}))

;; ── boxes, in the store ────────────────────────────────────────────────────────────

(wat.core/defn ssi/box [v :- :wat::WatAST] :- wat.type/i64
  (ss/kons! :ssi::store v -1))

(wat.core/defn ssi/unbox [id :- wat.type/i64] :- :wat::WatAST
  (ss/kar :ssi::store id))

(wat.core/defn ssi/setbox [id :- wat.type/i64 v :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [_set (ss/set-kar! :ssi::store id v)]
    v))

;; ── tables: ((name id) ...) ────────────────────────────────────────────────────────

(wat.core/defn ssi/extend [name :- :wat::WatAST id :- wat.type/i64 table :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [entry (wat.core/quasiquote (~name ~id))]
    (ls/cons entry table)))

;; the box id for name in table, or -1
(wat.core/defn ssi/lookup-in [name :- :wat::WatAST table :- :wat::WatAST] :- wat.type/i64
  (wat.core/cond
    ((ls/null? table) -1)
    ((ls/eq? (ls/car (ls/car table)) name) (ls/ast->i64 (ls/car (ls/cdr (ls/car table)))))
    (:else (ssi/lookup-in name (ls/cdr table)))))

;; local table first, then the global one
(wat.core/defn ssi/lookup [name :- :wat::WatAST table :- :wat::WatAST] :- wat.type/i64
  (wat.core/let [local (ssi/lookup-in name table)]
    (wat.core/if (wat.core/>= local 0)
      local
      (wat.core/let [g (ssi/lookup-in name (ss/cell-get :ssi::global))]
        (wat.core/if (wat.core/>= g 0)
          g
          (:wat::kernel::assertion-failed! :message "ssi: unbound name"))))))

;; ── meaning ────────────────────────────────────────────────────────────────────────

(wat.core/defn ssi/meaning [e :- :wat::WatAST table :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/cond
    ((ls/number? e) (ssi/ok e))
    ((lsi/boolean? e) (ssi/ok e))
    ((ls/atom? e)
     (wat.core/if (lsi/primitive-name? e)
       (ssi/ok (wat.core/quasiquote (primitive ~e)))
       (ssi/ok (ssi/unbox (ssi/lookup e table)))))
    ((ls/eq? (ls/car e) 'quote) (ssi/ok (ls/car (ls/cdr e))))
    ((ls/eq? (ls/car e) 'lambda)
     (wat.core/let [parts (ls/cdr e)]
       (ssi/ok (wat.core/quasiquote (non-primitive (~table ~@parts))))))
    ((ls/eq? (ls/car e) 'set!)
     (wat.core/let [v (:wat::core::Result/try (ssi/meaning (ls/car (ls/cdr (ls/cdr e))) table))]
       (ssi/ok (ssi/setbox (ssi/lookup (ls/car (ls/cdr e)) table) v))))
    ((ls/eq? (ls/car e) 'cond) (ssi/evcon (ls/cdr e) table))
    ((ls/eq? (ls/car e) 'letcc) (ssi/letcc e table))
    (:else (ssi/application e table))))

(wat.core/defn ssi/evcon [lines :- :wat::WatAST table :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/let [line (ls/car lines)
                 q    (ls/car line)
                 ans  (ls/car (ls/cdr line))]
    (wat.core/if (lsi/else? q)
      (ssi/meaning ans table)
      (wat.core/let [t (:wat::core::Result/try (ssi/meaning q table))]
        (wat.core/if (lsi/true? t)
          (ssi/meaning ans table)
          (ssi/evcon (ls/cdr lines) table))))))

;; evlis: the values of a list of expressions, left to right
(wat.core/defn ssi/evlis [args :- :wat::WatAST table :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/if (ls/null? args)
    (ssi/ok '())
    (wat.core/let [v  (:wat::core::Result/try (ssi/meaning (ls/car args) table))
                   vs (:wat::core::Result/try (ssi/evlis (ls/cdr args) table))]
      (ssi/ok (ls/cons v vs)))))

;; beglis: evaluate a body of one or more expressions; answer the last
(wat.core/defn ssi/beglis [es :- :wat::WatAST table :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/if (ls/null? (ls/cdr es))
    (ssi/meaning (ls/car es) table)
    (wat.core/let [_v (:wat::core::Result/try (ssi/meaning (ls/car es) table))]
      (ssi/beglis (ls/cdr es) table))))

(wat.core/defn ssi/application [e :- :wat::WatAST table :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/let [f    (:wat::core::Result/try (ssi/meaning (ls/car e) table))
                 args (:wat::core::Result/try (ssi/evlis (ls/cdr e) table))]
    (ssi/apply f args)))

(wat.core/defn ssi/apply [f :- :wat::WatAST args :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/cond
    ((ls/eq? (ls/car f) 'primitive) (ssi/ok (ssi/apply-primitive (ls/car (ls/cdr f)) args)))
    ((ls/eq? (ls/car f) 'non-primitive) (ssi/apply-closure (ls/car (ls/cdr f)) args))
    ((ls/eq? (ls/car f) 'continuation)
     (wat.core/let [k (ls/car (ls/cdr f))
                    v (ls/car args)
                    escape (wat.core/quasiquote (~k ~v))]
       (:wat::core::Result.Err {:error escape})))
    (:else (:wat::kernel::assertion-failed! :message "ssi: not a function"))))

;; bind each formal to a fresh box holding its argument
(wat.core/defn ssi/bind-all [formals :- :wat::WatAST args :- :wat::WatAST table :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/null? formals)
    table
    (ssi/bind-all (ls/cdr formals) (ls/cdr args)
                  (ssi/extend (ls/car formals) (ssi/box (ls/car args)) table))))

;; a closure is (table formals body ...)
(wat.core/defn ssi/apply-closure [closure :- :wat::WatAST args :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/let [ctable  (ls/car closure)
                 formals (ls/car (ls/cdr closure))
                 body    (ls/cdr (ls/cdr closure))]
    (ssi/beglis body (ssi/bind-all formals args ctable))))

;; (letcc k body ...): k names this point. Calling k with v anywhere inside the body
;; returns Err (id v); this letcc catches its own id and answers v, and passes any other
;; escape on up.
(wat.core/defn ssi/letcc [e :- :wat::WatAST table :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/let [name (ls/car (ls/cdr e))
                 body (ls/cdr (ls/cdr e))
                 c    (ssi/box 'continuation-token)
                 kval (wat.core/quasiquote (continuation ~c))
                 r    (ssi/beglis body (ssi/extend name (ssi/box kval) table))]
    (:wat::core::match r
      [:wat::core::Result.Ok {:value v} (ssi/ok v)]
      [:wat::core::Result.Err {:error esc}
        (wat.core/if (wat.core/= (ls/ast->i64 (ls/car esc)) c)
          (ssi/ok (ls/car (ls/cdr esc)))
          (:wat::core::Result.Err {:error esc}))])))

;; ── primitives ─────────────────────────────────────────────────────────────────────

;; primitives, closures and continuations all count as atoms in the language
(wat.core/defn ssi/atom-value? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((ls/atom? x) true)
    ((ls/null? x) false)
    ((ls/member? (ls/car x) '(primitive non-primitive continuation)) true)
    (:else false)))

(wat.core/defn ssi/apply-primitive [name :- :wat::WatAST vals :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/eq? name 'cons) (ls/cons (ls/car vals) (ls/car (ls/cdr vals))))
    ((ls/eq? name 'car) (ls/car (ls/car vals)))
    ((ls/eq? name 'cdr) (ls/cdr (ls/car vals)))
    ((ls/eq? name 'null?) (lsi/bool (ls/null? (ls/car vals))))
    ((ls/eq? name 'eq?) (lsi/bool (ls/eq? (ls/car vals) (ls/car (ls/cdr vals)))))
    ((ls/eq? name 'atom?) (lsi/bool (ssi/atom-value? (ls/car vals))))
    ((ls/eq? name 'zero?) (lsi/bool (ls/zero? (ls/ast->i64 (ls/car vals)))))
    ((ls/eq? name 'add1) (lsi/num (ls/add1 (ls/ast->i64 (ls/car vals)))))
    ((ls/eq? name 'sub1) (lsi/num (ls/sub1 (ls/ast->i64 (ls/car vals)))))
    (:else (lsi/bool (ls/number? (ls/car vals))))))

;; ── the top level: define, or an expression ────────────────────────────────────────

;; an escape that reaches the top level answers its value
(wat.core/defn ssi/unwrap [r :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])] :- :wat::WatAST
  (:wat::core::match r
    [:wat::core::Result.Ok {:value v} v]
    [:wat::core::Result.Err {:error esc} (ls/car (ls/cdr esc))]))

;; (define name expr): box the value and extend the global table; answers name
(wat.core/defn ssi/define [e :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [name (ls/car (ls/cdr e))
                 v    (ssi/unwrap (ssi/meaning (ls/car (ls/cdr (ls/cdr e))) '()))
                 id   (ssi/box v)
                 _g   (ss/cell-put! :ssi::global (ssi/extend name id (ss/cell-get :ssi::global)))]
    name))

(wat.core/defn ssi/value [e :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (wat.core/and (wat.core/not (ls/atom? e)) (ls/eq? (ls/car e) 'define))
    (ssi/define e)
    (ssi/unwrap (ssi/meaning e '()))))
