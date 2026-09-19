;; The edges of i64, where trapping arithmetic and truncating division both live.
;;
;; C-148 made `+`, `-` and `*` trap, and F-126 made `quot` and `rem` check their divisor rather
;; than take SIGFPE. Both fixes turned up a third thing: the range is ASYMMETRIC. There is a
;; -9223372036854775808 and no +9223372036854775808, so any code that reaches a negative by
;; negating its magnitude is wrong at exactly one input -- which is where `:c::to-int` and
;; `:asm::le` both were, silently, until arithmetic stopped wrapping.
;;
;; Everything here is a value wat computes without trapping, so both sides must print it. The
;; two that DO trap live in elf/bad/ and tools/elf-run.sh checks them.
;;
;; Run both ways; they must agree.

(wat.core/defn user/neg1 [] :- wat.type/i64 -1)
(wat.core/defn user/two [] :- wat.type/i64 2)

(wat.core/defn user/main [] :- wat.type/nil
  ;; the literals themselves -- the most negative one has no positive counterpart
  (wat.kernel/println -9223372036854775808)
  (wat.kernel/println 9223372036854775807)
  ;; arithmetic that reaches the edge without crossing it
  (wat.kernel/println (wat.core/+ 9223372036854775807 -1))
  (wat.kernel/println (wat.core/- -9223372036854775807 1))
  (wat.kernel/println (wat.core/* -9223372036854775807 1))
  ;; division truncates toward zero, and `rem` takes the sign of the dividend
  (wat.kernel/println (wat.core/quot -7 (user/two)))
  (wat.kernel/println (wat.core/rem -7 (user/two)))
  (wat.kernel/println (wat.core/quot 7 (wat.core/- 0 (user/two))))
  (wat.kernel/println (wat.core/rem 7 (wat.core/- 0 (user/two))))
  ;; the most negative dividend, which is where idiv faults if nothing checks
  (wat.kernel/println (wat.core/quot -9223372036854775808 (user/two)))
  (wat.kernel/println (wat.core/rem -9223372036854775808 (user/two)))
  ;; and `rem` by -1 is zero for every dividend, including the one `quot` cannot do
  (wat.kernel/println (wat.core/rem -9223372036854775808 (user/neg1)))
  (wat.kernel/println (wat.core/quot -9223372036854775808 1)))
