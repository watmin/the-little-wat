;; probes/recursion/depth-limit.wat: how deep can a non-tail recursion go before wat dies?
;;
;; Recursion is wat's primary iteration idiom -- it is how every Friedman book in this repository
;; is written -- and a non-tail recursion has a hard ceiling with NO diagnostic past it.
;;
;; MEASURED 2026-09-16 (wat-rs a3218644d):
;;
;;   depth  1000 .. 100000   exit 0, correct answer
;;   depth       120000+     SIGSEGV, exit 139, and stderr is EMPTY
;;
;; This file stays at 100000 so it can run. The cases past the edge are below, commented, because
;; a probe that segfaults would take the suite with it.
;;
;;   ;; SIGSEGV, silent:  (:u::deep 120000)
;;   ;; SIGSEGV, silent:  a self-referential stream -- (defn s [] (:wat::stream::cons 0 (:u::s)))
;;   ;;                   which is the natural spelling, because stream::cons is EAGER in its tail
;;   ;; SIGSEGV, silent:  (:ok::len l) over a 120000-element cons list -- the textbook
;;   ;;                   non-tail-recursive length, on an ordinary list
;;
;; Inside :wat::test::run-thread the same overflow ABORTS the process (exit 134) with a real
;; message -- "thread 'wat-thread-peer::<anon>' has overflowed its stack / fatal runtime error" --
;; so the runtime CAN see it on a spawned thread. It is still not catchable: F-063's only general
;; catch does not return a Failed, it takes the process down.
;;
;; TAIL recursion is unbounded: 1,000,000 deep returns correctly, so wat's TCO (arc 003) works.
;; That is the mitigation, and it is the only one.
;;
;; Expected: 100000

(:wat::core::defn :u::deep [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0 (:wat::core::+ 1 (:u::deep (:wat::core::- n 1)))))

(:wat::core::defn :u::tail [n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) acc (:u::tail (:wat::core::- n 1) (:wat::core::+ acc 1))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::deep 100000))
    (:wat::kernel::println (:u::tail 1000000 0))))
