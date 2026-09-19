;; A tight self-tail-recursive loop: C-121 turns a self tail call into a `jmp` on the same frame,
;; so no call survives it and its instruction mix is arithmetic, a compare and a branch. Paired
;; with elf/bench/loopsum.c, it separates two questions that fib(32) asks at once -- how good is
;; our straight-line code, and how expensive is our CALL.
;;
;; The conditional subtraction is there because gcc solved the first version of this loop in
;; CLOSED FORM: `sum i*3` compiled to 231,032 instructions total, and the benchmark measured
;; nothing. A carry that depends on the running value cannot be summed away.
(wat.core/defn user/go [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) acc
    (wat.core/let [a (wat.core/+ acc (wat.core/* i 3))]
      (user/go (wat.core/- i 1)
               (wat.core/if (wat.core/> a 1000000) (wat.core/- a 1000000) a)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/go 100000000 0)))
