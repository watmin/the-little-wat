;; F-202. A [String :-> i64] passed where [i64 :-> i64] is wanted. wat refuses it. The native
;; compiler at beb513d compiled it and the binary SEGFAULTED (the length of an integer). Must be refused.
;; wrong argument type through a function type
(wat.core/defn user/len [s :- wat.type/String] :- wat.type/i64 (wat.string/length s))
(wat.core/defn user/apply [f :- [wat.type/i64 :-> wat.type/i64]] :- wat.type/i64 (f 3))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/apply user/len)))
