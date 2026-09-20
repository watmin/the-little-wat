;; **elf/bench/parse.wat with the bitwise ops F-134 asked for.** Identical work, identical
;; answer; the only change is that `(rem (quot w 16777216) 256)` is now
;; `(bit-and (bit-shift-right w 24) 255)` -- two guarded routine calls into `idiv` become two
;; instructions. elf/bench/parse.c has always been written this way.

(wat.core/defn user/fill [p :- wat.type/i64 i :- wat.type/i64 n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) 0
    (wat.core/do
      ;; proto cycles 0..7 so one in eight matches; len is i mod 1024
      (wat.os/poke (wat.core/+ p (wat.core/* i 16))
        (wat.core/+ 4
          (wat.core/+ (wat.i64/bit-shift-left (wat.i64/bit-and i 1023) 8)
                      (wat.i64/bit-shift-left (wat.i64/bit-and i 7) 24))))
      (wat.os/poke (wat.core/+ (wat.core/+ p (wat.core/* i 16)) 8) i)
      (user/fill p (wat.core/+ i 1) n))))

(wat.core/defn user/scan [p :- wat.type/i64 i :- wat.type/i64 n :- wat.type/i64
                          hits :- wat.type/i64 total :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) (wat.core/+ (wat.core/* hits 1000000) total)
    (wat.core/let [w (wat.os/peek (wat.core/+ p (wat.core/* i 16)))
                   proto (wat.i64/bit-and (wat.i64/bit-shift-right w 24) 255)
                   len (wat.i64/bit-and (wat.i64/bit-shift-right w 8) 65535)]
      (wat.core/if (wat.core/= proto 6)
        (user/scan p (wat.core/+ i 1) n (wat.core/+ hits 1) (wat.core/+ total len))
        (user/scan p (wat.core/+ i 1) n hits total)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n 2000000
                 p (wat.os/mmap (wat.core/* n 16))]
    (wat.core/do
      (user/fill p 0 n)
      (wat.kernel/println (user/scan p 0 n 0 0)))))
