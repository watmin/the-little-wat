;; SICP §3.1 (assignment and local state), in wat.
;;
;; In Scheme an account is a procedure closed over a balance that set! changes. wat has no
;; assignment: state lives on a service (C-014). So an account is a service holding one balance
;; (lib/account.wat), and the messages are the dispatch the Scheme version does by hand. Two
;; names for one account are two peers connected to one address, which is what "two access
;; points to one balance" means here.
;;
;; The accumulator is the Seasoned Schemer's counter (its add answers the new total), and the
;; procedure that counts its calls is a counter beside a function.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch31-local-state.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch31-local-state.wat

(:wat::load-file! "lib/check.wat")
(:wat::load-file! "lib/account.wat")
(:wat::load-file! "../books/seasoned-schemer/lib/counter.wat")

;; a monitored function: a counter beside it, counting the calls
(:wat::core::defn :sicp::monitored-call [f <- [:wat::core::i64 :-> :wat::core::i64] calls <- :ss::CounterRef x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::do
    (:ss::counter-add! calls 1)
    (f x)))

(:wat::core::defn :sicp::square [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* n n))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [acc (:sicp::make-account 100)
                    acc-peer (:sicp::AccountRef/peer acc)
                    acc2 (:sicp::make-account 100)
                    acc2-peer (:sicp::AccountRef/peer acc2)
                    ;; two names for one account: a second peer on the same address
                    peter acc-peer
                    paul (:sicp::AccessPoint/peer (:sicp::another-access acc))
                    a (:ss::new-counter 5)
                    b (:ss::new-counter 5)
                    calls (:ss::new-counter 0)
                    int :sicp::show-int]
    (:sicp::check-chapter "oracle/sicp/ch31-local-state.expected"
                          "sicp ch31 local-state"
                          (:wat::core::Vector :- [:wat::core::String]
                            ;; an account remembers
                            (:sicp::show-withdraw (:sicp::withdraw! acc-peer 30))
                            (:sicp::show-withdraw (:sicp::withdraw! acc-peer 80))
                            (int (:sicp::deposit! acc-peer 50))
                            (:sicp::show-withdraw (:sicp::withdraw! acc-peer 60))
                            (int (:sicp::balance-of acc-peer))
                            ;; a second account has its own balance
                            (:sicp::show-withdraw (:sicp::withdraw! acc2-peer 10))
                            (int (:sicp::balance-of acc2-peer))
                            (int (:sicp::balance-of acc-peer))
                            ;; two names for one account are one balance
                            (:sicp::show-withdraw (:sicp::withdraw! peter 10))
                            (int (:sicp::balance-of paul))
                            (int (:sicp::deposit! paul 25))
                            (int (:sicp::balance-of peter))
                            ;; an accumulator
                            (int (:ss::counter-add! a 10))
                            (int (:ss::counter-add! a 10))
                            (int (:ss::counter-add! b 1))
                            (int (:ss::counter-add! a 1))
                            ;; a function that counts its own calls
                            (int (:sicp::monitored-call :sicp::square calls 5))
                            (int (:ss::counter-get calls))
                            (int (:sicp::monitored-call :sicp::square calls 3))
                            (int (:ss::counter-get calls))))))
