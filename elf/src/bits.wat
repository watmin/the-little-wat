;; **clj's seven bitwise ops** (F-134), each one x86 instruction. The differential is what makes
;; this honest: the interpreter runs the Rust intrinsics and the binary runs `and`/`or`/`xor`/
;; `not`/`shl`/`sar`/`shr`, and the two must print the same fourteen numbers.
;;
;; The shift-count edges are the ones worth having: x86 masks a 64-bit shift count to six bits
;; and so does the JVM, so `(bit-shift-left 1 64)` is 1 rather than 0 on BOTH sides. Every value
;; here was taken from clj 1.12.6 first.
(wat.core/defn user/id [n :- wat.type/i64] :- wat.type/i64 n)

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/bit-and (user/id -1) 255))
  (wat.kernel/println (wat.i64/bit-or (user/id -256) 15))
  (wat.kernel/println (wat.i64/bit-xor (user/id -1) -1))
  (wat.kernel/println (wat.i64/bit-not (user/id 0)))
  (wat.kernel/println (wat.i64/bit-not (user/id -1)))
  (wat.kernel/println (wat.i64/bit-shift-left (user/id 1) 63))
  (wat.kernel/println (wat.i64/bit-shift-left (user/id 1) 64))
  (wat.kernel/println (wat.i64/bit-shift-left (user/id 1) 65))
  (wat.kernel/println (wat.i64/bit-shift-right (user/id -7) 1))
  (wat.kernel/println (wat.i64/bit-shift-right (user/id -1) 64))
  (wat.kernel/println (wat.i64/bit-shift-right (user/id -9223372036854775808) 63))
  (wat.kernel/println (wat.i64/unsigned-bit-shift-right (user/id -1) 60))
  (wat.kernel/println (wat.i64/unsigned-bit-shift-right (user/id -1) 64))
  (wat.kernel/println (wat.i64/unsigned-bit-shift-right (user/id -9223372036854775808) 63))
  ;; and the variable-count path, where the count reaches CL instead of an immediate
  (wat.kernel/println (wat.i64/bit-shift-left (user/id 3) (user/id 4)))
  (wat.kernel/println (wat.i64/bit-shift-right (user/id -1024) (user/id 3)))
  (wat.kernel/println (wat.i64/unsigned-bit-shift-right (user/id -1) (user/id 62)))
  (wat.kernel/println (wat.i64/bit-and (user/id 3735928559) (user/id 255))))
