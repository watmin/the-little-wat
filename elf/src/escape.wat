;; THE GAP, isolated: a call whose RETURN TYPE IS NOT A POINTER, which allocated internally.
;; user/len returns i64, so nothing the caller keeps can point into the concat it made. The
;; statement release (C-120) cannot touch it: (user/len s) is an OPERAND of +, never a
;; discarded non-final form, and inside user/len the concat is the final form and so unmarked.
;; Expected TODAY: peak RSS grows with n. Expected AFTER the caller-side release: flat.
(wat.core/defn user/len [s :- wat.type/String] :- wat.type/i64
  (wat.string/length (wat.string/concat s "0123456789abcdef")))
(wat.core/defn user/run [s :- wat.type/String i :- wat.type/i64 n :- wat.type/i64
                         acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/run s (wat.core/+ i 1) n (wat.core/+ acc (user/len s)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/run "0123456789abcdef" 0 200000 0)))
