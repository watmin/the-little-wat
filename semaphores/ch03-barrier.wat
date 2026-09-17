;; semaphores/ch03-barrier.wat — Downey chapter 3's barrier, built the only way wat allows.
;;
;; A barrier holds every thread until all N have arrived, then releases them together. Downey
;; introduces semaphores for exactly this, and the thing he is eliminating is the SPIN-WAIT.
;;
;; wat cannot block a caller. A service CAN withhold a reply -- `:wat::service::Outcome.NoReply`
;; exists -- but nothing can ever answer that caller afterwards: `Invocation` carries a `conn-id`
;; described as "the stable monotonic i64 ... the name that outlives the round", and no verb takes
;; a conn-id and sends to it. Measured: a caller that receives NoReply hangs forever (F-102).
;; wat's own code never uses NoReply from a service impl, which is consistent with it being
;; unusable as a blocking primitive.
;;
;; So the barrier here is a POLL: arrive, then ask again until the count reaches N. It is correct,
;; and it costs a round-trip per poll -- 224 µs each, per F-051. The poll count is reported
;; because that number IS the price of the missing primitive.
;;
;; Run: wat semaphores/ch03-barrier.wat

(:wat::core::defsurface :bar::Barrier :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :bar::Barrier::ArriveRequest [])
   (:wat::core::defenum :bar::Barrier::ArriveResponse :wat::enum::Pure
     :Ok               [count <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :bar::Barrier::PeekRequest [])
   (:wat::core::defenum :bar::Barrier::PeekResponse :wat::enum::Pure
     :Ok               [count <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(arrive [self <- :bar::Barrier req <- :bar::Barrier::ArriveRequest] -> :bar::Barrier::ArriveResponse :max-request-bytes 524288)
   (peek   [self <- :bar::Barrier req <- :bar::Barrier::PeekRequest]   -> :bar::Barrier::PeekResponse   :max-request-bytes 524288)])

(:wat::service::defservice :bar::barrier
  :satisfies :bar::Barrier
  :durable [count <- :wat::core::i64]
  :ephemeral []
  :impls
  [(arrive [s ctx req]
     (:wat::core::let [c (:wat::i64::+ (:bar::barrier::Record/count (:bar::barrier::State/durable s)) 1)]
       (:wat::service::Outcome.Reply
         {:state (:bar::barrier::State :durable (:bar::barrier::Record :count c))
          :reply (:bar::Barrier::ArriveResponse.Ok {:count c})})))
   (peek [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:bar::Barrier::PeekResponse.Ok
         {:count (:bar::barrier::Record/count (:bar::barrier::State/durable s))})}))])

(:wat::core::defn :bar::n [] -> :wat::core::i64 8)

(:wat::core::defn :bar::peek-count :- [T]
  [c <- (:wat::kernel::Peer :- [(:bar::Barrier::Op :- []) (:bar::Barrier::Reply :- [])])] -> :wat::core::i64
  (:wat::core::match (:bar::Barrier/peek c (:bar::Barrier::PeekRequest))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:bar::Barrier::PeekResponse.Ok {:count k} k]
        [:bar::Barrier::PeekResponse.RequestTooLarge {:bytes b :cap q} -1]
        [:bar::Barrier::PeekResponse.RequestMalformed {:path p :expected e :got g} -2])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} -3]
    [:wat::kernel::RecvOutcome.Stopped {} -4]
    [:wat::kernel::RecvOutcome.Closed {} -5]))

;; spin until the count reaches n; return how many polls it took
(:wat::core::defn :bar::spin :- [T]
  [c <- (:wat::kernel::Peer :- [(:bar::Barrier::Op :- []) (:bar::Barrier::Reply :- [])])
   n <- :wat::core::i64  polls <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= (:bar::peek-count c) n)
    polls
    (:bar::spin c n (:wat::core::+ polls 1))))

(:wat::core::defn :bar::work :- [T]
  [addr <- (:wat::kernel::Address :- [(:bar::Barrier::Op :- []) (:bar::Barrier::Reply :- []) :T])]
  -> :wat::core::i64
  (:wat::core::let
    [c (:wat::core::match (:wat::kernel::connect addr)
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause x} (:wat::kernel::assertion-failed! :message "refused")]
         [:wat::kernel::ConnectOutcome.Rejected {:cause x} (:wat::kernel::assertion-failed! :message "rejected")]
         [:wat::kernel::ConnectOutcome.Failed {:cause x} (:wat::kernel::assertion-failed! :message "failed")])
     _ (:wat::core::match (:bar::Barrier/arrive c (:bar::Barrier::ArriveRequest))
         [:wat::kernel::RecvOutcome.Message {:msg m} nil]
         [:wat::kernel::RecvOutcome.Lost {:cause x} nil]
         [:wat::kernel::RecvOutcome.Stopped {} nil]
         [:wat::kernel::RecvOutcome.Closed {} nil])]
    ;; every worker is now past `arrive` and must not proceed until all n have arrived
    (:bar::spin c (:bar::n) 0)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:bar::barrier/start :locus (:wat::spawn::thread) :record (:bar::barrier::Record :count 0))
     addr (:bar::barrier::Handle/addr h)
     items (:wat::core::range 0 (:bar::n))
     t0 (:wat::time::epoch-nanos (:wat::time::now))
     polls (:wat::bracket::map (:wat::spawn::thread) items
             (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:bar::work addr)))
     ms (:wat::core::/ (:wat::core::- (:wat::time::epoch-nanos (:wat::time::now)) t0) 1000000)
     total (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                                (:wat::core::+ a b)) 0 polls)
     released (:wat::core::length polls)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "workers released  " (:wat::i64::to-string released) " / " (:wat::i64::to-string (:bar::n))
        "   " (:wat::core::if (:wat::core::= released (:bar::n)) "PASS" "FAIL"))))
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "every worker saw all " (:wat::i64::to-string (:bar::n)) " arrivals before proceeding   PASS by construction of the spin")))
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "poll round-trips spent waiting  " (:wat::i64::to-string total)
        "   (the price of the missing blocking primitive)")))
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "wall time  " (:wat::i64::to-string ms) " ms"))))))
