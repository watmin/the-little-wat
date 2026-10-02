;; R3. `(concat (subs code 0 at) hex (subs code from (length code)))`.
(wat.core/defn user/patch [code :- wat.type/String at :- wat.type/i64
                           hex :- wat.type/String] :- wat.type/String
  (wat.string/concat
    (wat.string/subs code 0 at)
    hex
    (wat.string/subs code (wat.core/+ at (wat.string/length hex)) (wat.string/length code))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/patch "abcdefghij" 4 "XYZ")))
