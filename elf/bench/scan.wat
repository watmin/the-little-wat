;; **Counting one byte in a text file** — the string equivalent of elf/bench/walk.wat, and the
;; benchmark the queue has been asking for since F-062 observed that a wat String has no elements
;; and no index-of.
;;
;; The only way to look at one character is `(subs s i (i+1))`, and `str_subs` ALLOCATES: it bumps
;; r15 and copies. So this loop allocates a one-character String per byte of input and then calls
;; `str_eq` on it. elf/bench/scan.c is `if (s[i] == 'e')`.
(wat.core/defn user/count-e [s :- wat.type/String i :- wat.type/i64 n :- wat.type/i64
                             acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n) acc
    (user/count-e s (wat.core/+ i 1) n
      (wat.core/if (wat.core/= (wat.string/subs s i (wat.core/+ i 1)) "e")
        (wat.core/+ acc 1) acc))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s (wat.io/read-file "elf/out/scan.txt")]
    (wat.kernel/println (user/count-e s 0 (wat.string/length s) 0))))
