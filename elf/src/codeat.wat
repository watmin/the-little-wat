;; **`code-point-at`, the one string verb that does not allocate** (F-135). Run both ways: the
;; interpreter walks `chars()` and returns a Unicode scalar; the binary emits one `movzbq` against
;; `[len:8][bytes...]`. They agree for every string this compiler accepts, which is the ASCII ones
;; (F-120) -- and that agreement is exactly what the differential is for.
(wat.core/defn user/id [n :- wat.type/i64] :- wat.type/i64 n)
(wat.core/defn user/s [] :- wat.type/String "hello, world!")

;; the idiom it exists for: count a byte without allocating one String
(wat.core/defn user/count-l [s :- wat.type/String i :- wat.type/i64 n :- wat.type/i64
                             acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) acc
    (user/count-l s (wat.core/+ i 1) n
      (wat.core/if (wat.core/= (wat.string/code-point-at s i) 108) (wat.core/+ acc 1) acc))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.string/code-point-at "hello" 0))
  (wat.kernel/println (wat.string/code-point-at "hello" 1))
  (wat.kernel/println (wat.string/code-point-at "hello" 4))
  ;; a computed index, so the operand reaches rcx rather than an immediate
  (wat.kernel/println (wat.string/code-point-at (user/s) (user/id 7)))
  (wat.kernel/println (wat.string/code-point-at (user/s) (user/id 12)))
  ;; three 'l' in "hello, world!"
  (wat.kernel/println (user/count-l (user/s) 0 (wat.string/length (user/s)) 0))
  ;; and it composes with the bitwise ops: lowercase a byte by clearing bit 5
  (wat.kernel/println (wat.i64/bit-or (wat.string/code-point-at "HELLO" 0) 32)))
