;; eopl/ch05-exceptions.wat — EOPL 5.4: a handler is a continuation frame, and what that costs.
;;
;; The same move as ch05-threads, aimed at a different finding. F-063: wat's ONLY general catch is
;; `:wat::test::run-thread`, which expands to `spawn-thread-program` — **recovery in wat means
;; starting a thread**, measured at about 1.3 ms. In the guest language a handler is one frame in
;; the continuation and `raise` walks the chain to the nearest one.
;;
;; So the comparison is not "wat is slow" — it is that the two are different mechanisms, and
;; reifying the continuation turns a thread spawn into a pointer walk. The same argument as C-064
;; made for blocking, and the same one the CEK notes make for wat's own evaluator.
;;
;; Run: wat eopl/ch05-exceptions.wat

(:wat::load-file! "lib/exceptions.wat")

(:wat::core::defn :ce::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :ce::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; try { 10 / 0 } catch(e) { 42 }        -- the handler fires
(:wat::core::defn :ce::caught [] -> :exn::Exp
  (:exn::Exp.Try {:body (:exn::Exp.Div {:a (:exn::Exp.Lit {:n 10}) :b (:exn::Exp.Lit {:n 0})})
                  :var "e" :handler (:exn::Exp.Lit {:n 42})}))

;; try { 10 / 2 } catch(e) { 42 }        -- the handler does NOT fire
(:wat::core::defn :ce::not-caught [] -> :exn::Exp
  (:exn::Exp.Try {:body (:exn::Exp.Div {:a (:exn::Exp.Lit {:n 10}) :b (:exn::Exp.Lit {:n 2})})
                  :var "e" :handler (:exn::Exp.Lit {:n 42})}))

;; raise 7  with no handler at all       -- propagates to the top
(:wat::core::defn :ce::uncaught [] -> :exn::Exp
  (:exn::Exp.Add {:a (:exn::Exp.Lit {:n 1}) :b (:exn::Exp.Raise {:e (:exn::Exp.Lit {:n 7})})}))

;; try { try { raise 5 } catch(e) { e + 100 } } catch(e) { 999 }  -- the INNER handler wins
(:wat::core::defn :ce::nested [] -> :exn::Exp
  (:exn::Exp.Try
    {:body (:exn::Exp.Try {:body (:exn::Exp.Raise {:e (:exn::Exp.Lit {:n 5})})
                           :var "e" :handler (:exn::Exp.Add {:a (:exn::Exp.Var {:name "e"})
                                                             :b (:exn::Exp.Lit {:n 100})})})
     :var "e" :handler (:exn::Exp.Lit {:n 999})}))

;; the raise happens under 20 frames of arithmetic, so unwinding has something to walk
(:wat::core::defn :ce::deep [d <- :wat::core::i64] -> :exn::Exp
  (:wat::core::if (:wat::core::<= d 0)
    (:exn::Exp.Raise {:e (:exn::Exp.Lit {:n 1})})
    (:exn::Exp.Add {:a (:exn::Exp.Lit {:n 1}) :b (:ce::deep (:wat::core::- d 1))})))

(:wat::core::defn :ce::cycle [n <- :wat::core::i64] -> :exn::Exp
  (:exn::Exp.Rep {:times n
    :body (:exn::Exp.Try {:body (:ce::deep 20) :var "e" :handler (:exn::Exp.Lit {:n 0})})}))

;; wat's own catch, for comparison: run-thread around a raise (F-063)
(:wat::core::defn :ce::wat-catch [] -> :wat::core::i64
  (:wat::core::match (:wat::test::run-thread (:wat::kernel::assertion-failed! :message "boom"))
    [:wat::kernel::RunResult.Passed {} 0]
    [:wat::kernel::RunResult.Failed {:failure f} 1]))

(:wat::core::defn :ce::wat-catches [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::+ a (:ce::wat-catch)))
    0 (:wat::core::range 0 n)))

(:wat::core::defn :ce::depth-row [d <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [caught (:exn::steps (:exn::Exp.Try {:body (:ce::deep d) :var "e" :handler (:exn::Exp.Lit {:n 0})}))
     plain  (:exn::steps (:exn::Exp.Try {:body (:exn::Exp.Lit {:n 0}) :var "e" :handler (:exn::Exp.Lit {:n 0})}))]
    (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      "  raise under " (:wat::i64::to-string d) " frames"
      "   transitions=" (:wat::i64::to-string caught)
      "   (an empty try is " (:wat::i64::to-string plain) ")")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n 200]
    (:wat::core::do
      (:ce::say "handler fires on div-by-zero " (:wat::core::if (:wat::core::= (:exn::run (:ce::caught)) 42) "PASS" "FAIL"))
      (:ce::say "handler skipped when no raise" (:wat::core::if (:wat::core::= (:exn::run (:ce::not-caught)) 5) "PASS" "FAIL"))
      (:ce::say "uncaught reaches the top     " (:wat::core::if (:wat::core::= (:exn::run (:ce::uncaught)) 7) "PASS" "FAIL"))
      (:ce::say "the INNER handler wins       " (:wat::core::if (:wat::core::= (:exn::run (:ce::nested)) 105) "PASS" "FAIL"))
      (:wat::kernel::println "---- how a catch SCALES with handler depth ----")
      (:wat::kernel::println "   (transitions, not wall clock: the guest's wall time is wat interpreting it")
      (:wat::kernel::println "    at ~14 us a transition, which would measure the interpreter, not the mechanism)")
      (:ce::depth-row 5) (:ce::depth-row 10) (:ce::depth-row 20) (:ce::depth-row 40)
      (:wat::kernel::println "---- wat's own catch, for the shape not the magnitude ----")
      (:wat::core::let
        [n 100
         t1 (:ce::now) _2 (:ce::wat-catches n) e2 (:wat::core::- (:ce::now) t1)]
        (:ce::say "  :wat::test::run-thread, per catch"
          (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
            (:wat::i64::to-string (:wat::core::/ e2 n)) " ns -- a thread spawn (F-063), FIXED whatever the depth")))))))
