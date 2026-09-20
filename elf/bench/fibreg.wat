;; **The same fib, with the intermediate named** -- and F-129's evidence that naming it is not
;; free. `elf/bench/fib32.wat` writes `(+ (fib (- n 1)) (fib (- n 2)))`; this writes the first
;; call into a `let` and adds it, which is the same computation in the spelling a person reaches
;; for when the expression gets long.
;;
;; That spelling adds five nodes, and `:c::inl-limit` is a count of nodes: 30 becomes 35 against
;; a limit of 34, so this function does not inline and the other one does. Measured with the
;; same compiler, same machine, same answer: 105.7M instructions and 34.2M cycles against fib32's
;; 59.9M and 15.1M. One node.
(wat.core/defn user/fib [n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/< n 2)
    n
    (wat.core/let [a (user/fib (wat.core/- n 1))]
      (wat.core/+ a (user/fib (wat.core/- n 2))))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/fib 32)))
