;; The accumulator :c::emit uses: a String grown by concat, 32000 times. conj got an in-place path
;; in C-127; concat did not, so this is still a copy per step.
(wat.core/defn user/grow [n :- wat.type/i64 acc :- wat.type/String] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) (wat.string/length acc)
    (user/grow (wat.core/- n 1) (wat.string/concat acc "0123456789abcdef"))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/grow 32000 "")))
