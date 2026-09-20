;; **A THROUGHPUT-bound loop**, where `loopsum` is a latency-bound one.
;;
;; `loopsum` carries a single accumulator, so every iteration waits on the previous one's `add`
;; and both compilers are pinned to the same dependency chain -- which is why C-157 could tie
;; `gcc -O2` there while issuing 3.3x the instructions. C-153 said that tie was the machine's
;; spare width covering our fat, and that it would stop covering it the moment a loop had work
;; to overlap. This is that loop: three independent chains, nothing to wait for, the issue width
;; actually used.
;;
;; The conditional subtraction on each chain is the same trick `loopsum` needs -- without it gcc
;; sums the series in closed form and the benchmark measures nothing.
(wat.core/defn user/go [i :- wat.type/i64 a :- wat.type/i64 b :- wat.type/i64 c :- wat.type/i64]
    :- wat.type/i64
  (wat.core/if (wat.core/= i 0) (wat.core/+ a (wat.core/+ b c))
    (wat.core/let [a2 (wat.core/+ a (wat.core/* i 3))
                   b2 (wat.core/+ b (wat.core/* i 5))
                   c2 (wat.core/+ c (wat.core/* i 7))]
      (user/go (wat.core/- i 1)
        (wat.core/if (wat.core/> a2 1000000) (wat.core/- a2 1000000) a2)
        (wat.core/if (wat.core/> b2 2000000) (wat.core/- b2 2000000) b2)
        (wat.core/if (wat.core/> c2 3000000) (wat.core/- c2 3000000) c2)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/go 30000000 0 0 0)))
