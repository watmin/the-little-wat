;; wat does tail-call elimination; this program needs it.
;;
;; A million levels of self-recursion in TAIL position. The interpreter answers 1000000. The same
;; shape NOT in tail position -- `(+ 1 (user/sum (- n 1)))` -- dumps core in the interpreter at
;; the same depth, which is how we know the elimination is real and not just a deep stack.
;;
;; So this is not a performance question. A tail-recursive loop is the ordinary way to iterate in
;; wat, and a compiler that lays every call down as a `call` turns working programs into
;; segmentation faults. Run both ways; they must agree.

(wat.core/defn user/count-down [n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) acc
    (user/count-down (wat.core/- n 1) (wat.core/+ acc 1))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/count-down 1000000 0)))
