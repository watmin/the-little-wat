;; service-counter.wat: can a plain PROGRAM (run by the wat binary, not a deftest) define a
;; service, start it on a thread, call it, and exit cleanly? This is the pattern Seasoned
;; Schemer ch 15-17 (set!, state) will need. Copied in shape from wat-rs's live
;; wat-tests/service-locus-parity.wat. Keyword spelling throughout.
;; Expected: prints 10 and exits 0. A hang at exit would show as timeout's 124.

(:wat::core::defsurface :u::Counter :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :u::Counter::GetRequest [])
   (:wat::core::defenum :u::Counter::GetResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :u::Counter::IncrementRequest [n <- :wat::core::i64])
   (:wat::core::defenum :u::Counter::IncrementResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get       [self <- :u::Counter  req <- :u::Counter::GetRequest]       -> :u::Counter::GetResponse :max-request-bytes 524288)
   (increment [self <- :u::Counter  req <- :u::Counter::IncrementRequest] -> :u::Counter::IncrementResponse :max-request-bytes 524288)])

(:wat::service::defservice :u::counter
  :satisfies :u::Counter
  :durable [count <- :wat::core::i64]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:u::Counter::GetResponse.Ok
         {:value (:u::counter::Record/count (:u::counter::State/durable s))})}))
   (increment [s ctx req]
     (:wat::core::let [c (:wat::i64::+
                           (:u::counter::Record/count (:u::counter::State/durable s))
                           (:u::Counter::IncrementRequest/n req))]
       (:wat::service::Outcome.Reply
         {:state (:u::counter::State :durable (:u::counter::Record :count c))
          :reply (:u::Counter::IncrementResponse.Ok {:value c})})))])

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:u::counter/start :locus (:wat::spawn::thread) :record (:u::counter::Record :count 0))
     c (:wat::core::match (:wat::kernel::connect (:u::counter::Handle/addr h))
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])
     _a (:wat::core::match (:u::Counter/increment c (:u::Counter::IncrementRequest :n 5))
          [:wat::kernel::RecvOutcome.Message {:msg _r} nil]
          [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
          [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "stopped")]
          [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "closed")])
     _b (:wat::core::match (:u::Counter/increment c (:u::Counter::IncrementRequest :n 5))
          [:wat::kernel::RecvOutcome.Message {:msg _r} nil]
          [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
          [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "stopped")]
          [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "closed")])
     v (:wat::core::match (:u::Counter/get c (:u::Counter::GetRequest))
         [:wat::kernel::RecvOutcome.Message {:msg m}
           (:wat::core::match m
             [:u::Counter::GetResponse.Ok {:value value} value]
             [:u::Counter::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "too large")]
             [:u::Counter::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "malformed")])]
         [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
         [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "stopped")]
         [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "closed")])]
    (:wat::kernel::println v)))
