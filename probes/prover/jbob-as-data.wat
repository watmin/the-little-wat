;; jbob-as-data.wat: can J-Bob's source live as wat quoted data? Its symbols include
;; J-Bob/step, if.Q, car/cons and <=len (F-008: `<` in a name is a lex error), and its
;; forms nest 'x inside quoted lists. Prints each element's ast-kind and value.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [d '(J-Bob/step if.Q car/cons 't 'nil (quote ham) (defun f (x) (if (atom x) '0 x)))]
    (wat.core/do
      (wat.kernel/println (wat.core/length d))
      (wat.kernel/println (wat.core/ast-kind (wat.core/first d)))
      (wat.kernel/println (wat.core/ast-kind (wat.core/first (wat.core/rest (wat.core/rest (wat.core/rest d))))))
      (wat.kernel/println (wat.core/first (wat.core/rest (wat.core/rest (wat.core/rest d)))))
      (wat.kernel/println (wat.core/first (wat.core/first (wat.core/rest (wat.core/rest (wat.core/rest d)))))))))
