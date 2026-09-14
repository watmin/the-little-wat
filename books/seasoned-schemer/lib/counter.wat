;; The Seasoned Schemer, ch 17 (counters): a Counter service holding one i64. Like lib/cell.wat
;; (which holds an S-expression), but numeric, so counting needs no conversion between number
;; nodes and i64. Needs nothing else loaded. No main here.
;;
;; Keyword spelling throughout, for the same reasons as lib/cell.wat. It is a second copy of
;; the same ceremony, for a second shape of state (FINDINGS.md, friction under C-014).

(:wat::core::defsurface :ss::Counter :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :ss::Counter::GetRequest [])
   (:wat::core::defenum :ss::Counter::GetResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :ss::Counter::AddRequest [n <- :wat::core::i64])
   (:wat::core::defenum :ss::Counter::AddResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :ss::Counter::ResetRequest [n <- :wat::core::i64])
   (:wat::core::defenum :ss::Counter::ResetResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get   [self <- :ss::Counter  req <- :ss::Counter::GetRequest]   -> :ss::Counter::GetResponse   :max-request-bytes 524288)
   (add   [self <- :ss::Counter  req <- :ss::Counter::AddRequest]   -> :ss::Counter::AddResponse   :max-request-bytes 524288)
   (reset [self <- :ss::Counter  req <- :ss::Counter::ResetRequest] -> :ss::Counter::ResetResponse :max-request-bytes 524288)])

(:wat::service::defservice :ss::counter
  :satisfies :ss::Counter
  :durable [count <- :wat::core::i64]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:ss::Counter::GetResponse.Ok {:value (:ss::counter::Record/count (:ss::counter::State/durable s))})}))
   (add [s ctx req]
     (:wat::core::let [c (:wat::i64::+ (:ss::counter::Record/count (:ss::counter::State/durable s))
                                       (:ss::Counter::AddRequest/n req))]
       (:wat::service::Outcome.Reply
         {:state (:ss::counter::State :durable (:ss::counter::Record :count c))
          :reply (:ss::Counter::AddResponse.Ok {:value c})})))
   (reset [s ctx req]
     (:wat::core::let [c (:ss::Counter::ResetRequest/n req)]
       (:wat::service::Outcome.Reply
         {:state (:ss::counter::State :durable (:ss::counter::Record :count c))
          :reply (:ss::Counter::ResetResponse.Ok {:value c})})))])

;; A running counter: its Handle (kept so the service stays owned) and a connected peer.
(:wat::core::defstruct :ss::CounterRef
  [handle <- :ss::counter::Handle
   peer   <- :ss::Counter])

(:wat::core::defn :ss::new-counter [n <- :wat::core::i64] -> :ss::CounterRef
  (:wat::core::let
    [h (:ss::counter/start :locus (:wat::spawn::thread) :record (:ss::counter::Record :count n))
     p (:wat::core::match (:wat::kernel::connect (:ss::counter::Handle/addr h))
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:ss::CounterRef :handle h :peer p)))

(:wat::core::defn :ss::counter-get [c <- :ss::CounterRef] -> :wat::core::i64
  (:wat::core::match (:ss::Counter/get (:ss::CounterRef/peer c) (:ss::Counter::GetRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Counter::GetResponse.Ok {:value v} v]
        [:ss::Counter::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "counter get: request too large")]
        [:ss::Counter::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "counter get: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "counter get: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "counter get: closed")]))

;; add n; answers the new count
(:wat::core::defn :ss::counter-add! [c <- :ss::CounterRef n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:ss::Counter/add (:ss::CounterRef/peer c) (:ss::Counter::AddRequest :n n))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Counter::AddResponse.Ok {:value v} v]
        [:ss::Counter::AddResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "counter add: request too large")]
        [:ss::Counter::AddResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "counter add: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "counter add: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "counter add: closed")]))

;; reset to n; answers n
(:wat::core::defn :ss::counter-reset! [c <- :ss::CounterRef n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:ss::Counter/reset (:ss::CounterRef/peer c) (:ss::Counter::ResetRequest :n n))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Counter::ResetResponse.Ok {:value v} v]
        [:ss::Counter::ResetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "counter reset: request too large")]
        [:ss::Counter::ResetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "counter reset: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "counter reset: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "counter reset: closed")]))
