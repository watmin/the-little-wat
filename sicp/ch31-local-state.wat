;; SICP §3.1 (assignment and local state), in wat.
;;
;; In Scheme an account is a procedure closed over a balance that set! changes. wat has no
;; assignment: state lives on a service (C-014). So an account is a service holding one balance,
;; and the messages are the dispatch the Scheme version does by hand. Two names for one account
;; are two peers connected to one address, which is what "two access points to one balance"
;; means here.
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
(:wat::load-file! "../books/seasoned-schemer/lib/counter.wat")

(:wat::core::defsurface :sicp::Account :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :sicp::Account::BalanceRequest [])
   (:wat::core::defenum :sicp::Account::BalanceResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :sicp::Account::WithdrawRequest [amount <- :wat::core::i64])
   (:wat::core::defenum :sicp::Account::WithdrawResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :Insufficient     []
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :sicp::Account::DepositRequest [amount <- :wat::core::i64])
   (:wat::core::defenum :sicp::Account::DepositResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(balance  [self <- :sicp::Account  req <- :sicp::Account::BalanceRequest]  -> :sicp::Account::BalanceResponse  :max-request-bytes 524288)
   (withdraw [self <- :sicp::Account  req <- :sicp::Account::WithdrawRequest] -> :sicp::Account::WithdrawResponse :max-request-bytes 524288)
   (deposit  [self <- :sicp::Account  req <- :sicp::Account::DepositRequest]  -> :sicp::Account::DepositResponse  :max-request-bytes 524288)])

(:wat::service::defservice :sicp::account
  :satisfies :sicp::Account
  :durable [balance <- :wat::core::i64]
  :ephemeral []
  :impls
  [(balance [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:sicp::Account::BalanceResponse.Ok {:value (:sicp::account::Record/balance (:sicp::account::State/durable s))})}))
   (withdraw [s ctx req]
     (:wat::core::let [have (:sicp::account::Record/balance (:sicp::account::State/durable s))
                       amount (:sicp::Account::WithdrawRequest/amount req)]
       (:wat::core::if (:wat::core::>= have amount)
         (:wat::core::let [left (:wat::core::- have amount)]
           (:wat::service::Outcome.Reply
             {:state (:sicp::account::State :durable (:sicp::account::Record :balance left))
              :reply (:sicp::Account::WithdrawResponse.Ok {:value left})}))
         (:wat::service::Outcome.Reply {:state s :reply (:sicp::Account::WithdrawResponse.Insufficient {})}))))
   (deposit [s ctx req]
     (:wat::core::let [total (:wat::core::+ (:sicp::account::Record/balance (:sicp::account::State/durable s))
                                            (:sicp::Account::DepositRequest/amount req))]
       (:wat::service::Outcome.Reply
         {:state (:sicp::account::State :durable (:sicp::account::Record :balance total))
          :reply (:sicp::Account::DepositResponse.Ok {:value total})})))])

;; An access point to an account: a peer connected to its address. The handle is kept by the
;; account that started it, so a second access point holds only its own peer.
(:wat::core::defstruct :sicp::AccountRef
  [handle <- :sicp::account::Handle
   peer   <- :sicp::Account])

(:wat::core::defstruct :sicp::AccessPoint
  [peer <- :sicp::Account])

;; The connect is written out at each site: a function that answers a peer can't declare its
;; type (probes/sicp/connect-return-type.wat).
(:wat::core::defn :sicp::make-account [balance <- :wat::core::i64] -> :sicp::AccountRef
  (:wat::core::let [h (:sicp::account/start :locus (:wat::spawn::thread) :record (:sicp::account::Record :balance balance))
                    p (:wat::core::match (:wat::kernel::connect (:sicp::account::Handle/addr h))
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:sicp::AccountRef :handle h :peer p)))

;; a second access point to the same balance: another peer on the same address
(:wat::core::defn :sicp::another-access [a <- :sicp::AccountRef] -> :sicp::AccessPoint
  (:wat::core::let [p (:wat::core::match (:wat::kernel::connect (:sicp::account::Handle/addr (:sicp::AccountRef/handle a)))
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:sicp::AccessPoint :peer p)))

(:wat::core::defn :sicp::balance-of [p <- :sicp::Account] -> :wat::core::i64
  (:wat::core::match (:sicp::Account/balance p (:sicp::Account::BalanceRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sicp::Account::BalanceResponse.Ok {:value v} v]
        [:sicp::Account::BalanceResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "account balance: request too large")]
        [:sicp::Account::BalanceResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "account balance: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "account balance: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "account balance: closed")]))

;; the balance left, or None when there isn't enough
(:wat::core::defn :sicp::withdraw! [p <- :sicp::Account amount <- :wat::core::i64] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match (:sicp::Account/withdraw p (:sicp::Account::WithdrawRequest :amount amount))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sicp::Account::WithdrawResponse.Ok {:value v} (:wat::core::Option.Some {:value v})]
        [:sicp::Account::WithdrawResponse.Insufficient {} (:wat::core::Option.None {})]
        [:sicp::Account::WithdrawResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "account withdraw: request too large")]
        [:sicp::Account::WithdrawResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "account withdraw: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "account withdraw: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "account withdraw: closed")]))

(:wat::core::defn :sicp::deposit! [p <- :sicp::Account amount <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:sicp::Account/deposit p (:sicp::Account::DepositRequest :amount amount))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sicp::Account::DepositResponse.Ok {:value v} v]
        [:sicp::Account::DepositResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "account deposit: request too large")]
        [:sicp::Account::DepositResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "account deposit: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "account deposit: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "account deposit: closed")]))

;; ---- printing, as the Scheme oracle prints

(:wat::core::defn :sicp::show-int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))

(:wat::core::defn :sicp::show-withdraw [o <- (:wat::core::Option :- [:wat::core::i64])] -> :wat::core::String
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} (:wat::i64::to-string v)]
    [:wat::core::Option.None {} "insufficient"]))

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
