;; F-205's family, excursus 005 stone 1. A string literal the file ends inside, at the TOP
;; LEVEL, with no list open around it. wat: unterminated string literal. The reader read it as a
;; complete string. Must be refused, naming where the string opened.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println "abc"))
"abc
