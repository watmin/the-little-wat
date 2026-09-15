;; ast-to-source.wat: what does :wat::core::ast->source render for the pieces of J-Bob's data:
;; a symbol with / . ? <, nil, an int, longhand (quote nil), shorthand 't, nested lists, ()?
;; The J-Bob translator emits quoted data through it. Walks the list with first/rest.
(wat.core/defn u/show-each [l :- :wat::WatAST] :- wat.type/nil
  (wat.core/if (wat.core/empty? l)
    nil
    (wat.core/do (wat.kernel/println (:wat::core::ast->source (wat.core/first l)))
                 (u/show-each (wat.core/rest l)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [d '(J-Bob/step if.Q list0? <=len nil 0 (quote nil) 't (a (b c) ()))]
    (wat.core/do (u/show-each d)
                 (wat.kernel/println (:wat::core::ast->source d)))))
