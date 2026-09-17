;; eopl/ch06-cps-transform.wat — EOPL chapter 6: CPS TRANSFORMATION and REGISTERIZATION.
;;
;; Chapter 5 changed the machine and left the program alone. Chapter 6 does the opposite: it
;; rewrites the PROGRAM, source to source, into a form where every call is a tail call — and then
;; any interpreter at all, including the naive direct one, runs it in constant stack.
;;
;; That claim is testable in wat in a way it is not in Scheme, because wat has a hard ceiling to
;; hit: F-099, a non-tail recursion segfaults with an empty stderr. The experiment is one
;; interpreted program under ONE interpreter (eopl/lib/direct.wat), before and after the
;; transform. See probes/eopl/cps6-depth.wat for the ladder.

(:wat::load-file! "lib/letrec.wat")
(:wat::load-file! "lib/direct.wat")
(:wat::load-file! "lib/cps6.wat")
(:wat::load-file! "lib/regz.wat")

(:wat::core::defn :c6t::say [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :c6t::num [label <- :wat::core::String n <- :wat::core::i64] -> :wat::core::nil
  (:c6t::say label (:wat::i64::to-string n)))

;; letrec f(n) = if zero?(n) then 0 else -(n, -(0, f(-(n,1)))) in (f N)
;; The recursive call sits in an OPERAND position, so it is not a tail call and the host stack
;; grows with the interpreted depth.
(:wat::core::defn :c6t::sum-prog [n <- :wat::core::i64] -> :eopl::Exp
  (:eopl::Exp.Letrec
    {:fname "f" :param "n"
     :fbody (:eopl::Exp.If
              {:c (:eopl::Exp.IsZero {:e (:eopl::Exp.Var {:name "n"})})
               :t (:eopl::Exp.Const {:n 0})
               :f (:eopl::Exp.Diff
                    {:a (:eopl::Exp.Var {:name "n"})
                     :b (:eopl::Exp.Diff
                          {:a (:eopl::Exp.Const {:n 0})
                           :b (:eopl::Exp.Call
                                {:rator (:eopl::Exp.Var {:name "f"})
                                 :rand (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "n"})
                                                         :b (:eopl::Exp.Const {:n 1})})})})})})
     :body (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "f"})
                             :rand (:eopl::Exp.Const {:n n})})}))

(:wat::core::defn :c6t::agree? [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [src (:c6t::sum-prog n)
                    a (:eopl::num-of (:eopl::direct-run src))
                    b (:eopl::num-of (:eopl::direct-run (:c6::cps-of-program src)))]
    (:wat::string::concat (:wat::i64::to-string a)
      (:wat::core::if (:wat::core::= a b) "   AGREE" "   DIFFER"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [src (:c6t::sum-prog 10)
                    out (:c6::cps-of-program src)]
    (:wat::core::do
      (:wat::kernel::println "---- EOPL ch6: the CPS transformation is source to source ----")

      ;; 1. the transform preserves meaning
      (:c6t::say "sum to 10   " (:c6t::agree? 10))
      (:c6t::say "sum to 100  " (:c6t::agree? 100))
      (:c6t::say "sum to 1000 " (:c6t::agree? 1000))

      ;; 2. the claim itself: no call in the output is in a non-tail position
      (:wat::kernel::println "---- calls in non-tail position ----")
      (:c6t::num "source     " (:c6::nontail src))
      (:c6t::num "transformed" (:c6::nontail out))
      (:wat::kernel::println "  NOT zero -- LETREC procedures take one argument, so the continuation")
      (:wat::kernel::println "  must be CURRIED: `((f a) k)`. The inner `(f a)` is a real non-tail call.")
      (:wat::kernel::println "  It is also a BOUNDED one: it applies `proc(x) proc(k) ...` and returns a")
      (:wat::kernel::println "  closure without evaluating anything, so it costs one host frame, never a chain.")
      (:wat::kernel::println "---- departures from the CPS grammar (every operator and operand SIMPLE) ----")
      (:c6t::num "source     " (:c6::violations src))
      (:c6t::num "transformed" (:c6::violations out))
      (:wat::kernel::println "  THAT is the checkable form of the claim, and the property the ceiling follows.")

      ;; 3. what it costs: the `if` case duplicates the continuation into both arms
      (:wat::kernel::println "---- term size (the price of duplicating k into both If arms) ----")
      (:c6t::num "source     " (:c6::size src))
      (:c6t::num "transformed" (:c6::size out))

      ;; 4. the result that only wat can show, because only wat has a ceiling to hit
      (:wat::kernel::println "---- the SAME direct interpreter, before and after (ladder: probes/eopl/cps6-depth.wat) ----")
      (:wat::kernel::println "  as written   n=20000 ok   n=25000 SEGFAULT (F-099, empty stderr)")
      (:wat::kernel::println "  CPS'd        n=20000 ok   n=25000 ok  ... n=100000 ok, same answers")

      ;; 5. registerization — and the measurement that inverts the book's motivation
      (:wat::kernel::println "---- ch6.5: registerization ----")
      (:wat::kernel::println "  mutual tail calls survive n=10,000,000 (probes/eopl/mutual-tco.wat),")
      (:wat::kernel::println "  so registerization is a CHOICE in wat, not a requirement.")
      (:c6t::say "both machines agree on sum to 1000"
        (:wat::core::if (:wat::core::= (:eopl::num-of (:eopl::run (:c6t::sum-prog 1000)))
                                       (:eopl::num-of (:rz::run (:c6t::sum-prog 1000))))
          "AGREE" "DIFFER"))
      (:wat::kernel::println "  and it COSTS ~1.9x: step/drive must allocate a State per transition")
      (:wat::kernel::println "  where mutual tail calls allocate nothing (probes/eopl/regz-cost.wat)."))))
