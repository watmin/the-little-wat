;; assert-pass.wat: can a program assert, in the Clojure/EDN spelling? Expected: exit 0,
;; prints "assert-pass: ok".

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.test/assert-eq (wat.core/+ 40 2) 42)
    (wat.kernel/println "assert-pass: ok")))
