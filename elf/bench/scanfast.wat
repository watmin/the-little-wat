;; **elf/bench/scan.wat with `code-point-at`** (F-135). Identical work, identical answer; the
;; only change is that looking at one character is now a `movzbq` instead of an allocation plus a
;; `str_eq`. 101 is 'e'. elf/bench/scan.c has always been `s[i] == 'e'`.

(wat.core/defn user/count-e [s :- wat.type/String i :- wat.type/i64 n :- wat.type/i64
                             acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) acc
    (user/count-e s (wat.core/+ i 1) n
      (wat.core/if (wat.core/= (wat.string/code-point-at s i) 101)
        (wat.core/+ acc 1) acc))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s (wat.io/read-file "elf/out/scan.txt")]
    (wat.kernel/println (user/count-e s 0 (wat.string/length s) 0))))
