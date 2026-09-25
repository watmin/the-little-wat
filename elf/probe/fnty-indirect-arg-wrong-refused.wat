;; excursus 003 stone 1, the orchestrator's adversarial round: a wrong argument at an INDIRECT call ([String :-> i64] called with 3): wat refuses; must be COMPILE-FAILED, reaching :c::check-fn-args.
(wat.core/defn user/apply [f :- [wat.type/String :-> wat.type/i64] n :- wat.type/i64] :- wat.type/i64 (f n))
(wat.core/defn user/len [s :- wat.type/String] :- wat.type/i64 (wat.string/length s))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/apply user/len 3)))
