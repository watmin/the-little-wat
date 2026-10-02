;; R3. `(concat (nibble hi) (nibble lo))` — the low nibble is a right-hand concat operand.
(wat.core/defn user/nibble [n :- wat.type/i64] :- wat.type/String
  (wat.string/subs "0123456789abcdef" n (wat.core/+ n 1)))

(wat.core/defn user/u8 [n :- wat.type/i64] :- wat.type/String
  (wat.string/concat (user/nibble (wat.core/quot n 16)) (user/nibble (wat.core/rem n 16))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/u8 255))
  (wat.kernel/println (user/u8 10)))
