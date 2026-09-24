;; F-191: a VALID program -- the interpreter prints 4 -- that the native compiler SEGFAULTS on.
;; An inner let re-binds the outer name at a new type, its body is the bare name, and the outer
;; name is read next through `length`. Mechanism NOT established; see F-191 for the matrix.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [y "abc"]
    (wat.kernel/println (wat.core/+ (wat.core/let [y 1] y) (wat.string/length y)))))
