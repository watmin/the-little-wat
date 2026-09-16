;; bench/lib/timer.wat — the shared harness for bench/.
;;
;; Three things this harness exists to get right, each learned by getting it wrong first:
;;
;; 1. THE LOOP IS NOT FREE. At ~3.6 us per trivial iteration the loop machinery dwarfs what is
;;    being measured, so every figure is reported against an EMPTY-LOOP CONTROL of the same shape
;;    and the same N, and the per-op cost is the difference.
;;
;; 2. ONE OP PER ITERATION IS BELOW THE NOISE FLOOR. Measuring a ~200 ns call against a 3.6 us
;;    iteration is a 6% effect, and run-to-run variance on a laptop exceeds that -- the first
;;    version of this file reported a NEGATIVE cost for a builtin call. So every body repeats its
;;    operation :bench::rep times, and ns/op divides by (n * rep).
;;
;; 3. A SINGLE RUN IS A SAMPLE. tools/bench.sh runs each program repeatedly and keeps the MINIMUM
;;    per label -- the least-disturbed run, the standard choice for a noisy machine.
;;
;; Output is " | "-separated rather than tab-separated because :wat::kernel::println EDN-quotes a
;; String, so a tab comes out as a literal backslash-t (F-049: there is no raw write to stdout).

(:wat::core::defn :bench::rep [] -> :wat::core::i64 10)

(:wat::core::defn :bench::now [] -> :wat::core::i64
  (:wat::time::epoch-nanos (:wat::time::now)))

(:wat::core::defn :bench::ns-since [t0 <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::- (:bench::now) t0))

;; The control: a bare countdown, nothing in the body. Every other loop in bench/ has this shape.
(:wat::core::defn :bench::empty-loop [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0 (:bench::empty-loop (:wat::core::- n 1))))

(:wat::core::defn :bench::row
  [label <- :wat::core::String
   n     <- :wat::core::i64
   total <- :wat::core::i64
   base  <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let [net (:wat::core::- total base)
                    ops (:wat::core::* n (:bench::rep))
                    per (:wat::core::/ net ops)]
    (:wat::kernel::println (:wat::string::join " | " (:wat::core::Vector :- [:wat::core::String]
      "BENCH" label (:wat::i64::to-string ops)
      (:wat::i64::to-string (:wat::core::/ total 1000))
      (:wat::i64::to-string (:wat::core::/ base 1000))
      (:wat::i64::to-string per))))))
