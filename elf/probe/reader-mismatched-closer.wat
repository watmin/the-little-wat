;; F-205. A mismatched closer inside a vector: `)` where `]` belongs. Must be refused, naming the line.
(wat.core/defn user/main [) :- wat.type/nil
  (wat.kernel/println 1))
