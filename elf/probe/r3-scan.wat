;; R3. `(= (subs s i (+ i 1)) c)` — the slice is a temporary the comparison reads.
(wat.core/defn user/one [s :- wat.type/String i :- wat.type/i64 c :- wat.type/String] :- wat.type/i64
  (wat.core/if (wat.core/= (wat.string/subs s i (wat.core/+ i 1)) c) 1 0))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (user/one "abcd" 1 "b")))
  (wat.kernel/println (wat.i64/to-string (user/one "abcd" 1 "z"))))
