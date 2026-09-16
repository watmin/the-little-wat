;; probes/sicp/peer-as-parameter.wat: can a connected peer be passed to a function whose
;; parameter is the surface's type? The peer here comes from an inline connect, let-bound, the
;; way every service client in this repository binds one.
;;
;; The other half of the same question, a function that answers a peer, is
;; probes/sicp/connect-return-type.wat. Putting the peer in a struct field of the surface's type
;; does work, and reading the field back gives a value that passes anywhere: that is what
;; sicp/lib/account.wat and books/seasoned-schemer/lib/counter.wat do.
;;
;; Run from the repository root: wat probes/sicp/peer-as-parameter.wat

(:wat::core::defsurface :probe::Cell :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :probe::Cell::GetRequest [])
   (:wat::core::defenum :probe::Cell::GetResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get [self <- :probe::Cell  req <- :probe::Cell::GetRequest] -> :probe::Cell::GetResponse :max-request-bytes 524288)])

(:wat::service::defservice :probe::cell
  :satisfies :probe::Cell
  :durable [value <- :wat::core::i64]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:probe::Cell::GetResponse.Ok {:value (:probe::cell::Record/value (:probe::cell::State/durable s))})}))])

;; the function that takes a peer
(:wat::core::defn :probe::read-once [p <- :probe::Cell] -> :wat::core::i64
  (:wat::core::match (:probe::Cell/get p (:probe::Cell::GetRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:probe::Cell::GetResponse.Ok {:value v} v]
        [:probe::Cell::GetResponse.RequestTooLarge {:bytes b :cap cp} -1]
        [:probe::Cell::GetResponse.RequestMalformed {:path mp :expected me :got mg} -1])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} -1]
    [:wat::kernel::RecvOutcome.Stopped {} -1]
    [:wat::kernel::RecvOutcome.Closed {} -1]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [h (:probe::cell/start :locus (:wat::spawn::thread) :record (:probe::cell::Record :value 7))
                    p (:wat::core::match (:wat::kernel::connect (:probe::cell::Handle/addr h))
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:wat::kernel::println (:probe::read-once p))))
