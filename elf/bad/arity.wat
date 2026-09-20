;; A call with the wrong number of arguments. The compiler used to accept this: the caller
;; pushes three, the callee reads two at its own offsets, the caller pops three, so the stack
;; stays balanced and the callee simply reads the WRONG SLOTS (F-128).
(wat.core/defn user/two [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64
  (wat.core/+ a b))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/two 1 2 3)))
