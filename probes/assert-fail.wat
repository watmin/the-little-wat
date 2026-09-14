;; assert-fail.wat: the negative control. This assertion is WRONG ON PURPOSE. Expected: a
;; NON-ZERO exit and a message naming the actual and expected values. If this exits 0,
;; no chapter program's green means anything.

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.test/assert-eq (wat.core/+ 40 2) 43)
    (wat.kernel/println "assert-fail: UNREACHABLE (the assertion did not fire)")))
