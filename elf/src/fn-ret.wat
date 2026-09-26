;; a function value returned from a function, then called
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/give [] :- [wat.type/i64 :-> wat.type/i64] user/inc)
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println ((user/give) 41)))
