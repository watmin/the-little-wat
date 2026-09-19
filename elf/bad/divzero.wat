;; `idiv` does not set a flag on a bad divisor -- it FAULTS. A bare divide took SIGFPE here:
;; core dumped, exit 136, no message, where the interpreter says `DivisionByZero: division by
;; zero` and stops cleanly (F-126). The divisor goes through a check BEFORE the instruction,
;; because after it is a signal.
;;
;; The divisor comes from a call so that nothing can fold it away.
(wat.core/defn user/zero [] :- wat.type/i64 0)
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/quot 1 (user/zero))))
