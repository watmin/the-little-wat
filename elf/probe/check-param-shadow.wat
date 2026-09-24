;; F-190: the interpreter REJECTS this; the native compiler runs it (prints 4). A let re-binding a
;; PARAMETER at a different type. Re-binding a LET-bound name at a different type is accepted.
(wat.core/defn user/f [x :- wat.type/String] :- wat.type/i64
  (wat.core/+ (wat.string/length x) (wat.core/let [x 1] x)))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/f "abc")))
