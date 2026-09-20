;; The SAME walk as elf/bench/parse.wat with the field extraction removed -- peek each header word
;; and sum it. This is the control: it isolates the load and loop from the byte-field arithmetic,
;; so the difference between this ratio and parse's is what having no bitwise operators costs.
(wat.core/defn user/fill [p :- wat.type/i64 i :- wat.type/i64 n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) 0
    (wat.core/do
      ;; no `rem` here: the fill must not pay the same tax the scan is being measured for
      (wat.os/poke (wat.core/+ p (wat.core/* i 16)) i)
      (wat.os/poke (wat.core/+ (wat.core/+ p (wat.core/* i 16)) 8) i)
      (user/fill p (wat.core/+ i 1) n))))
(wat.core/defn user/scan [p :- wat.type/i64 i :- wat.type/i64 n :- wat.type/i64
                          total :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) total
    (user/scan p (wat.core/+ i 1) n
      (wat.core/+ total (wat.os/peek (wat.core/+ p (wat.core/* i 16)))))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n 2000000 p (wat.os/mmap (wat.core/* n 16))]
    (wat.core/do (user/fill p 0 n) (wat.kernel/println (user/scan p 0 n 0)))))
