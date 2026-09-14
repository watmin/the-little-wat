;; sexp-cons.wat: can a quoted list be built from an element and a quoted list, which
;; is Little Schemer's cons? Attempted as quasiquote with ~@ splicing a quoted list.
;; Expected: true   true
;;   (cons 'x '(a b c)) = (x a b c)
;;   (cons '(a) '(b))   = ((a) b)   -- a list as the first element

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [x     (wat.core/quote x)
                 l     (wat.core/quote (a b c))
                 inner (wat.core/quote (a))
                 tail  (wat.core/quote (b))]
    (wat.core/do
      (wat.kernel/println (wat.core/= (wat.core/quasiquote (~x ~@l))
                                      (wat.core/quote (x a b c))))
      (wat.kernel/println (wat.core/= (wat.core/quasiquote (~inner ~@tail))
                                      (wat.core/quote ((a) b)))))))
