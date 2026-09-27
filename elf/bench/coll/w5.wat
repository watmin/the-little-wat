(:wat::load-file! "common.wat")

(wat.core/defn user/grow [i :- wat.type/i64 n :- wat.type/i64 s :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/= i n) s
    (user/grow (wat.core/+ i 1) n (wat.string/concat s "a"))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 s (user/grow 0 n "")]
    (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (wat.string/length s))))))
