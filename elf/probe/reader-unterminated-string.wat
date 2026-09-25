;; F-205's family, excursus 005 stone 1. A string literal the file ends inside, INSIDE a list.
;; wat: unterminated string literal. The reader answered the end of input as the string's end,
;; and the refusal then blamed the unclosed `(` instead of the string. Must be refused, naming
;; where the string opened.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println "abc))
