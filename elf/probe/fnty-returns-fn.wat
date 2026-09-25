;; excursus 003 stone 1, the orchestrator's adversarial round: a function returning a function, then applied: agree 42.
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/mk [] :- [wat.type/i64 :-> wat.type/i64] user/inc)
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (user/mk)] (wat.kernel/println (f 41))))
