;; **The shape an XDP filter is made of**, and the first benchmark here that is not arithmetic in
;; a loop: walk fixed-size records in raw memory, pull BYTE FIELDS out of a header word, filter on
;; one of them, and accumulate another.
;;
;; `wat.os/peek` is a single `mov (%rax),%rax`, so the load side is already exactly C's. The
;; field extraction is the question: **wat has no bitwise operators** — no `bit-and`, no shift, in
;; any namespace — so `(w >> 8) & 0xff` has to be written `(rem (quot w 256) 256)`, and in this
;; compiler `quot` and `rem` are guarded ROUTINE CALLS, because `idiv` faults rather than flagging
;; (F-126/C-150). elf/bench/parse.c does the same work with `>>` and `&`.
;;
;; 16 bytes a record: a header word whose bytes are [version, len-lo, len-hi, proto] and a payload
;; word. Count the records with proto 6 and sum their lengths.

(wat.core/defn user/fill [p :- wat.type/i64 i :- wat.type/i64 n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) 0
    (wat.core/do
      ;; proto cycles 0..7 so one in eight matches; len is i mod 1024
      (wat.os/poke (wat.core/+ p (wat.core/* i 16))
        (wat.core/+ 4
          (wat.core/+ (wat.core/* (wat.core/rem i 1024) 256)
                      (wat.core/* (wat.core/rem i 8) 16777216))))
      (wat.os/poke (wat.core/+ (wat.core/+ p (wat.core/* i 16)) 8) i)
      (user/fill p (wat.core/+ i 1) n))))

(wat.core/defn user/scan [p :- wat.type/i64 i :- wat.type/i64 n :- wat.type/i64
                          hits :- wat.type/i64 total :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) (wat.core/+ (wat.core/* hits 1000000) total)
    (wat.core/let [w (wat.os/peek (wat.core/+ p (wat.core/* i 16)))
                   proto (wat.core/rem (wat.core/quot w 16777216) 256)
                   len (wat.core/rem (wat.core/quot w 256) 65536)]
      (wat.core/if (wat.core/= proto 6)
        (user/scan p (wat.core/+ i 1) n (wat.core/+ hits 1) (wat.core/+ total len))
        (user/scan p (wat.core/+ i 1) n hits total)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n 2000000
                 p (wat.os/mmap (wat.core/* n 16))]
    (wat.core/do
      (user/fill p 0 n)
      (wat.kernel/println (user/scan p 0 n 0 0)))))
