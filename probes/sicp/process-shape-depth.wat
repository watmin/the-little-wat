;; probes/sicp/process-shape-depth.wat — SICP §1.2.1's "recursive process vs iterative process",
;; made observable.
;;
;; Run: wat probes/sicp/process-shape-depth.wat <rec|iter> <n>
;;
;; SICP says two procedures computing the same function can generate different PROCESSES: one
;; accumulates deferred operations, the other keeps its state in the arguments. In Scheme the
;; difference does not show in the answers, and the book asks you to take the shape on faith.
;;
;; wat has a ceiling, so it shows. F-099: a non-tail recursion segfaults with an empty stderr;
;; TCO makes tail recursion unbounded. Both arms below compute sum(1..n); only the shape differs.
;; A segfault is an expected outcome of the `rec` arm, so each rung runs in its own process and
;; the driver reads the exit status directly, never through a pipe (R-005).
;;
;; Addition rather than multiplication, so nothing overflows and the only variable is the shape.

;; deferred: the addition waits for the recursive call to return
(:wat::core::defn :ps::sum-rec [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0
    (:wat::core::+ n (:ps::sum-rec (:wat::core::- n 1)))))

;; iterative: the state is in the arguments and the call is in tail position
(:wat::core::defn :ps::sum-iter [n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) acc
    (:ps::sum-iter (:wat::core::- n 1) (:wat::core::+ acc n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [args (:wat::runtime::argv)
                    mode (:wat::core::if (:wat::core::> (:wat::core::length args) 2)
                           (:wat::core::nth args 2) "iter")
                    n (:wat::core::if (:wat::core::> (:wat::core::length args) 3)
                        (:wat::core::match (:wat::string::to-i64 (:wat::core::nth args 3))
                          [:wat::core::Option.Some {:value v} v]
                          [:wat::core::Option.None {} 1000])
                        1000)
                    v (:wat::core::if (:wat::core::= mode "rec")
                        (:ps::sum-rec n) (:ps::sum-iter n 0))]
    (:wat::kernel::println
      (:wat::string::concat mode " n=" (:wat::i64::to-string n) " => " (:wat::i64::to-string v)))))
