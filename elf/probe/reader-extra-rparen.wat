;; F-205. One `)` too many. wat: UnexpectedRParen. The native compiler never finished (heap exhausted,
;; 1.9 GB, exit 70). Must be refused at compile time, naming the line.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/+ 1 2))))
