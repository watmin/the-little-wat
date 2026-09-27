;; Live data past the old 1.9 GB ceiling. 64 bytes doubled twenty times is 64 MiB; appending
;; that chunk 31 more times retains 32 * 67,108,864 = 2,147,483,648 bytes. That is above
;; 1,900,000,000 and far under this box's 32 GB of RAM. The accumulator is linear, so the
;; append extends in place. Not part of the elf-run corpus: one run touches about 2 GB.
(wat.core/defn user/dbl [n :- wat.type/i64 s :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/= n 0) s
    (user/dbl (wat.core/- n 1) (wat.string/concat s s))))

(wat.core/defn user/app [n :- wat.type/i64 chunk :- wat.type/String acc :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/= n 0) acc
    (user/app (wat.core/- n 1) chunk (wat.string/concat acc chunk))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [seed "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
                 chunk (user/dbl 20 seed)
                 s (user/app 31 chunk chunk)
                 n (wat.string/length s)]
    (wat.kernel/println n)
    (wat.kernel/println (wat.string/subs s 0 16))
    (wat.kernel/println (wat.string/subs s (wat.core/- n 16) n))))
