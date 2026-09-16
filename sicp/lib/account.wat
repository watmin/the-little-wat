;; sicp/lib/account.wat: an account, the way wat keeps state: a service holding one balance.
;; No main. Used by ch31 (local state) and ch34 (concurrency).
;;
;; In Scheme an account is a procedure closed over a balance that set! changes, and the message
;; it is sent picks the operation. Here the operations are the service's messages, and the
;; balance is its state. A service handles one message at a time, so every access is serialized
;; by construction, whoever sends it.

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

;; An account: its Handle (kept so the service stays owned) and a peer connected to it.
(:wat::core::defstruct :sicp::AccountRef
  [handle <- :sicp::account::Handle
   peer   <- :sicp::Account])

;; A second access point to one account: another peer on the same address.
(:wat::core::defstruct :sicp::AccessPoint
  [peer <- :sicp::Account])

;; The connect is written out at each site: a function that answers a peer can't declare its
;; type (F-052, probes/sicp/connect-return-type.wat).
(:wat::core::defn :sicp::make-account [balance <- :wat::core::i64] -> :sicp::AccountRef
  (:wat::core::let [h (:sicp::account/start :locus (:wat::spawn::thread) :record (:sicp::account::Record :balance balance))
                    p (:wat::core::match (:wat::kernel::connect (:sicp::account::Handle/addr h))
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:sicp::AccountRef :handle h :peer p)))

(:wat::core::defn :sicp::another-access [a <- :sicp::AccountRef] -> :sicp::AccessPoint
  (:wat::core::let [p (:wat::core::match (:wat::kernel::connect (:sicp::account::Handle/addr (:sicp::AccountRef/handle a)))
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:sicp::AccessPoint :peer p)))

;; The address to dial for this account, for anyone who has to connect for themselves. Its type
;; names the protocol: a bare :wat::kernel::Address would lose it (F-052).
(:wat::core::defn :sicp::account-addr [a <- :sicp::AccountRef] -> (:wat::kernel::Address :- [:sicp::Account::Op :sicp::Account::Reply])
  (:sicp::account::Handle/addr (:sicp::AccountRef/handle a)))

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

;; ---- printing, as the Scheme oracles print

(:wat::core::defn :sicp::show-int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))

(:wat::core::defn :sicp::show-withdraw [o <- (:wat::core::Option :- [:wat::core::i64])] -> :wat::core::String
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} (:wat::i64::to-string v)]
    [:wat::core::Option.None {} "insufficient"]))
