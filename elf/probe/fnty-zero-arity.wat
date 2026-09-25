;; excursus 003 stone 1, the orchestrator's adversarial round: [:-> i64]: agree 14.
(wat.core/defn user/seven [] :- wat.type/i64 7)
(wat.core/defn user/twice [f :- [:-> wat.type/i64]] :- wat.type/i64 (wat.core/+ (f) (f)))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/twice user/seven)))
