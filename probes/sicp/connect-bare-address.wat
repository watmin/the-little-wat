;; probes/sicp/connect-bare-address.wat: a worker that dials a service for itself. It is handed
;; the address as a value of type :wat::kernel::Address — which is how an address travels to
;; another thread — and connects.
;;
;; Connecting to the address read straight off a typed handle works: the peer is the surface's
;; type, and can be stored in a struct field or passed to a function
;; (probes/sicp/peer-as-parameter.wat). Here the address has been through a parameter first.
;;
;; Run from the repository root: wat probes/sicp/connect-bare-address.wat

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

(:wat::core::defstruct :probe::CellRef [peer <- :probe::Cell])

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

;; the worker: it has an address, and dials it
(:wat::core::defn :probe::worker [addr <- :wat::kernel::Address] -> :wat::core::i64
  (:wat::core::let [p (:wat::core::match (:wat::kernel::connect addr)
                        [:wat::kernel::ConnectOutcome.Connected {:peer c} c]
                        [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
                        [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:probe::read-once p)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [h (:probe::cell/start :locus (:wat::spawn::thread) :record (:probe::cell::Record :value 7))]
    (:wat::kernel::println (:probe::worker (:probe::cell::Handle/addr h)))))
