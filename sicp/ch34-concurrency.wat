;; SICP §3.4 (concurrency), in wat.
;;
;; The book's worry is two processes reaching one balance at once: without a serializer, an
;; interleaving loses a deposit. In wat an account is a service (lib/account.wat), and a service
;; handles one message at a time, so the serializer is the account itself. There is nothing to
;; wrap: the unserialized version the book warns about can't be written, because nothing else
;; can reach the balance.
;;
;; So this chapter puts four workers on one account at once — :wat::bracket::map over a thread
;; locus, each worker connecting to the account's address for itself — and asks what they add up
;; to. Then it transfers between two accounts, where the two balances together never change.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch34-concurrency.scm, run by
;; tools/sicp-oracle.sh: Scheme runs one thing at a time, so it computes what any correct
;; serialization must produce), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch34-concurrency.wat

(:wat::load-file! "lib/check.wat")
(:wat::load-file! "lib/account.wat")

;; one worker's share: connect to the account, then deposit 1 twenty-five times
(:wat::core::defn :sicp::deposit-times [p <- :sicp::Account n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0)
    (:sicp::balance-of p)
    (:wat::core::do
      (:sicp::deposit! p 1)
      (:sicp::deposit-times p (:wat::core::- n 1)))))

;; The address carries the service's protocol in its type: declared as a bare
;; :wat::kernel::Address, the connection it opens speaks to nothing (F-052,
;; probes/sicp/connect-bare-address.wat).
(:wat::core::defn :sicp::deposit-worker [addr <- (:wat::kernel::Address :- [:sicp::Account::Op :sicp::Account::Reply])] -> :wat::core::i64
  (:wat::core::let [p (:wat::core::match (:wat::kernel::connect addr)
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:sicp::deposit-times p 25)))

;; a transfer moves what it takes: the two balances together never change
(:wat::core::defn :sicp::transfer! [from <- :sicp::Account to <- :sicp::Account amount <- :wat::core::i64] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match (:sicp::withdraw! from amount)
    [:wat::core::Option.Some {:value left}
      (:wat::core::do
        (:sicp::deposit! to amount)
        (:wat::core::Option.Some {:value left}))]
    [:wat::core::Option.None {} (:wat::core::Option.None {})]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [acc (:sicp::make-account 0)
                    acc-peer (:sicp::AccountRef/peer acc)
                    addr (:sicp::account-addr acc)
                    start (:sicp::balance-of acc-peer)
                    ;; four workers at once, each on its own thread, each dialling the account
                    each-saw (:wat::bracket::map (:wat::spawn::thread)
                                                 (:wat::core::Vector :- [(:wat::kernel::Address :- [:sicp::Account::Op :sicp::Account::Reply])] addr addr addr addr)
                                                 :sicp::deposit-worker)
                    after (:sicp::balance-of acc-peer)
                    a (:sicp::make-account 100)
                    a-peer (:sicp::AccountRef/peer a)
                    b (:sicp::make-account 100)
                    b-peer (:sicp::AccountRef/peer b)
                    int :sicp::show-int]
    (:sicp::check-chapter "oracle/sicp/ch34-concurrency.expected"
                          "sicp ch34 concurrency"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int start)
                            (int after)
                            ;; transfers between two accounts
                            (:sicp::show-withdraw (:sicp::transfer! a-peer b-peer 30))
                            (int (:sicp::balance-of a-peer))
                            (int (:sicp::balance-of b-peer))
                            (:sicp::show-withdraw (:sicp::transfer! b-peer a-peer 50))
                            (int (:sicp::balance-of a-peer))
                            (int (:sicp::balance-of b-peer))
                            (int (:wat::core::+ (:sicp::balance-of a-peer) (:sicp::balance-of b-peer)))
                            (:sicp::show-withdraw (:sicp::transfer! a-peer b-peer 1000))
                            (int (:wat::core::+ (:sicp::balance-of a-peer) (:sicp::balance-of b-peer)))))))
