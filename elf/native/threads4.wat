(wat.core/defn user/reap [n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0)
    0
    (wat.core/do (wat.os/wait) (user/reap (wat.core/- n 1)))))

(wat.core/defn user/spawn [shared :- wat.type/i64 stacks :- wat.type/i64
                           i :- wat.type/i64 n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n)
    (user/reap n)
    (wat.core/if (wat.core/= (wat.os/clone (wat.core/+ stacks (wat.core/* (wat.core/+ i 1) 65536))) 0)
      (wat.core/do
        (wat.os/poke (wat.core/+ shared (wat.core/* i 8)) (wat.core/* (wat.core/+ i 1) 100))
        (wat.os/exit 0))
      (user/spawn shared stacks (wat.core/+ i 1) n))))

(wat.core/defn user/sum [base :- wat.type/i64 i :- wat.type/i64 n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i n)
    0
    (wat.core/+ (wat.os/peek (wat.core/+ base (wat.core/* i 8)))
                (user/sum base (wat.core/+ i 1) n))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [shared (wat.os/mmap 4096)
                 stacks (wat.os/mmap 524288)]
    (user/spawn shared stacks 0 4)
    (wat.kernel/println (user/sum shared 0 4))))
