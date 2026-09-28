(wat.core/defn user/f [v :- (wat.core/Vector :- [wat.type/i64])
                    s :- wat.type/String] :- wat.type/i64
  (wat.core/if (wat.core/< (wat.core/length v) 5) (wat.core/length v) 5))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string
    (user/f (wat.core/Vector :- [wat.type/i64] 1 2 3) "zz"))))
