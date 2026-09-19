;; Proof that memory is actually given back.
;;
;; Everything else in elf/src/ shows memory is not freed too EARLY. This one shows it is freed at
;; all: the program allocates roughly 650 MB -- about ten times the whole heap -- and completes,
;; which it can only do if the space is being reused.
;;
;; The shape is chosen so nothing can optimise it away:
;;
;;   * `user/copies` reads `s` twice on its path (once in the concat, once in the recursive
;;     call), so `s` is not linear and every concat is a real copy of 64 KB;
;;   * `user/burn` calls it as a DISCARDED statement, so the 6.5 MB each round allocates is
;;     released at the statement boundary and the next round reuses the same addresses.
;;
;; Compile the release out and this dies with `wat: heap exhausted` after about ten rounds.
;; tools/mem.sh reports the peak, which stays near one round rather than near the total.
;;
;; Run both ways; they must agree.

(wat.core/defn user/pad [n :- wat.type/i64 acc :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/= n 0) acc
    (user/pad (wat.core/- n 1) (wat.string/concat acc "0123456789abcdef"))))

(wat.core/defn user/copies [k :- wat.type/i64 s :- wat.type/String acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= k 0) acc
    (user/copies (wat.core/- k 1) s
      (wat.core/+ acc (wat.string/length (wat.string/concat s "x"))))))

(wat.core/defn user/burn [n :- wat.type/i64 s :- wat.type/String acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) acc
    (wat.core/do
      (user/copies 100 s 0)
      (user/burn (wat.core/- n 1) s (wat.core/+ acc 1)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s (user/pad 4096 "")]
    (wat.kernel/println (wat.string/length s))
    ;; one round is 100 copies of 64 KB = 6.5 MB; a hundred rounds is 650 MB, ten heaps
    (wat.kernel/println (user/burn 100 s 0))
    (wat.kernel/println (user/copies 100 s 0))
    (wat.kernel/println (wat.string/length s))))
