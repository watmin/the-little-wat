;; i64 traps, and the compiled language must trap too.
;;
;; wat answers `IntegerOverflow: 9223372036854775807 :wat::i64::+ 1 does not fit in 64 bits` and
;; stops. This compiler emitted a bare `add rax, rcx`, printed -9223372036854775808 and exited 0
;; -- a wrong ANSWER, not a refusal, and the worst kind of divergence there is (F-120's shape).
;; Nothing in forty programs overflowed, so forty programs agreed and the suite stayed green.
;;
;; It lives here rather than in elf/src because it always stops, and the differential compares
;; programs that finish. What `tools/elf-run.sh` checks is that BOTH stop, and say so.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/+ 9223372036854775807 1)))
