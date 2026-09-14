;; The Seasoned Schemer, ch 15-17 (state): a Cell. The book's set! changes what a name
;; means. wat has no set!; mutable state lives on services. A Cell is the smallest such
;; service: it holds one S-expression and answers get and put. Needs nothing else loaded.
;; No main here.
;;
;; Keyword spelling throughout. The service forms have no Clojure/EDN spelling in wat-rs
;; yet, and Clojure-spelled special forms misread bracketed syntax (F-010, F-017).

(:wat::core::defsurface :ss::Cell :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :ss::Cell::GetRequest [])
   (:wat::core::defenum :ss::Cell::GetResponse :wat::enum::Pure
     :Ok               [value <- :wat::WatAST]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :ss::Cell::PutRequest [value <- :wat::WatAST])
   (:wat::core::defenum :ss::Cell::PutResponse :wat::enum::Pure
     :Ok               [value <- :wat::WatAST]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get [self <- :ss::Cell  req <- :ss::Cell::GetRequest] -> :ss::Cell::GetResponse :max-request-bytes 524288)
   (put [self <- :ss::Cell  req <- :ss::Cell::PutRequest] -> :ss::Cell::PutResponse :max-request-bytes 524288)])

(:wat::service::defservice :ss::cell
  :satisfies :ss::Cell
  :durable [value <- :wat::WatAST]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:ss::Cell::GetResponse.Ok {:value (:ss::cell::Record/value (:ss::cell::State/durable s))})}))
   (put [s ctx req]
     (:wat::core::let [v (:ss::Cell::PutRequest/value req)]
       (:wat::service::Outcome.Reply
         {:state (:ss::cell::State :durable (:ss::cell::Record :value v))
          :reply (:ss::Cell::PutResponse.Ok {:value v})})))])

;; A running cell: its Handle (kept so the service stays owned) and a connected peer.
(:wat::core::defstruct :ss::CellRef
  [handle <- :ss::cell::Handle
   peer   <- :ss::Cell])

(:wat::core::defn :ss::new-cell [v <- :wat::WatAST] -> :ss::CellRef
  (:wat::core::let
    [h (:ss::cell/start :locus (:wat::spawn::thread) :record (:ss::cell::Record :value v))
     p (:wat::core::match (:wat::kernel::connect (:ss::cell::Handle/addr h))
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:ss::CellRef :handle h :peer p)))

(:wat::core::defn :ss::cell-get [c <- :ss::CellRef] -> :wat::WatAST
  (:wat::core::match (:ss::Cell/get (:ss::CellRef/peer c) (:ss::Cell::GetRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Cell::GetResponse.Ok {:value v} v]
        [:ss::Cell::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "cell get: request too large")]
        [:ss::Cell::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "cell get: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "cell get: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "cell get: closed")]))

;; put a new value; answers the value put
(:wat::core::defn :ss::cell-put! [c <- :ss::CellRef v <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::match (:ss::Cell/put (:ss::CellRef/peer c) (:ss::Cell::PutRequest :value v))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Cell::PutResponse.Ok {:value v2} v2]
        [:ss::Cell::PutResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "cell put: request too large")]
        [:ss::Cell::PutResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "cell put: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "cell put: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "cell put: closed")]))
