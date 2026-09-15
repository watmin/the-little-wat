;; probes/sicp/connect-return-type.wat: can a function answer a connected peer? Every service
;; client in this repository writes its connect inline, inside the let that builds the struct
;; holding the peer (books/seasoned-schemer/lib/counter.wat and the rest). SICP §3.1's second
;; access point to one account wanted the same connect twice, so it moved into a function of
;; its own — which is refused.

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

;; the connect, in a function of its own, answering the surface's type
(:wat::core::defn :probe::connect-to [addr <- :wat::kernel::Address] -> :probe::Cell
  (:wat::core::match (:wat::kernel::connect addr)
    [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
    [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
    [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
    [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [h (:probe::cell/start :locus (:wat::spawn::thread) :record (:probe::cell::Record :value 7))
                    p (:probe::connect-to (:probe::cell::Handle/addr h))]
    (:wat::kernel::println (:wat::core::match (:probe::Cell/get p (:probe::Cell::GetRequest))
                             [:wat::kernel::RecvOutcome.Message {:msg m}
                               (:wat::core::match m
                                 [:probe::Cell::GetResponse.Ok {:value v} v]
                                 [:probe::Cell::GetResponse.RequestTooLarge {:bytes b :cap cp} -1]
                                 [:probe::Cell::GetResponse.RequestMalformed {:path mp :expected me :got mg} -1])]
                             [:wat::kernel::RecvOutcome.Lost {:cause x} -1]
                             [:wat::kernel::RecvOutcome.Stopped {} -1]
                             [:wat::kernel::RecvOutcome.Closed {} -1]))))
