;; Does the 'x shorthand reach the empty list, i.e. does it go through the keyword quote
;; path that F-004 spares? Expected if so: "list" then 2
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (wat.core/ast-kind '()))
    (wat.kernel/println (wat.core/length '(fig ())))))
