;; koans/idiom/24-macros.wat: the macros koans that don't port literally
;; (koans/literal/24-macros.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; A macro is a keyword-named defmacro over WatAST, built with quasiquote (C-019); the
;; Clojure-spelled defmacro defines nothing (F-022). The infix forms spell their operators as
;; calls do, :wat::core::+.
;;
;; Run from the repository root: wat koans/idiom/24-macros.wat

;; the string is built at runtime, by the call the macro writes: a macro may not call functions
;; while it expands (R-004)
(:wat::core::defmacro :koan::greeting [x <- :wat::WatAST] -> :wat::WatAST
  `(:wat::string::concat "Hi, " ~x))

;; The form is taken apart in the macro's body, by let, and only bound names are unquoted: a
;; computed unquote, ~(second form), evaluates the macro's argument as code (Friction, the
;; Reasoned Schemer), here "malformed int form: call head must be a keyword, symbol, or list".
(:wat::core::defmacro :koan::infix [form <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [a (:wat::core::first form) op (:wat::core::second form) b (:wat::core::third form)]
    `(~op ~a ~b)))

(:wat::core::defmacro :koan::infix-concise [form <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [a (:wat::core::first form) op (:wat::core::second form) b (:wat::core::third form)]
    `(~op ~a ~b)))

;; nested ifs: a macro body may use if but not cond ("keyword head `:wat::core::cond` refused at
;; macro expand time — not on the pure-combinator allow-list")
(:wat::core::defmacro :koan::recursive-infix [form <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::if (:wat::core::not (:wat::core::List? form))
    form
    (:wat::core::let [a (:wat::core::first form) more (:wat::core::rest form)]
      (:wat::core::if (:wat::core::empty? more)
        `(:koan::recursive-infix ~a)
        (:wat::core::let [op (:wat::core::first more) others (:wat::core::rest more)]
          `(~op (:koan::recursive-infix ~a) (:koan::recursive-infix ~others)))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:koan::greeting "macros") "Hi, macros") ; row 1
    (:wat::test::assert-eq (:koan::infix (8 :wat::core::+ 4)) 12) ; row 2
    (:wat::test::assert-eq (:wat::core::macroexpand (:wat::core::quote (:koan::infix (8 :wat::core::+ 4)))) (:wat::core::quote (:wat::core::+ 8 4))) ; row 3
    (:wat::test::assert-eq (:wat::core::macroexpand (:wat::core::quote (:koan::infix-concise (6 :wat::core::* 7)))) (:wat::core::quote (:wat::core::* 6 7))) ; row 4
    (:wat::test::assert-eq (:wat::core::macroexpand (:wat::core::quote (:koan::infix-concise (6 :wat::core::+ (7 :wat::core::* 2)))))
                           (:wat::core::quote (:wat::core::+ 6 (7 :wat::core::* 2)))) ; row 5
    (:wat::test::assert-eq (:koan::recursive-infix (6 :wat::core::+ (4 :wat::core::* 5) :wat::core::+ (2 :wat::core::* 8))) 42) ; row 6
    (:wat::kernel::println "koans idiom 24-macros: ok")))
