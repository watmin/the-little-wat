;; semaphores/ch01-lost-update.wat — NEXT.md §11, and the question the book rests on.
;;
;; The Little Book of Semaphores exists because shared mutable state races: N threads each
;; incrementing a shared counter K times will, without synchronisation, finish below N*K, because
;; read-modify-write is not atomic. Every puzzle in the book is a way of stopping that.
;;
;; wat's answer is structural. docs/ZERO-MUTEX.md: state lives in a service, and the actor's
;; serialisation IS the mutex -- so there is no lock to write and, if the claim holds, no race to
;; lose. This file tries to break it.
;;
;; 8 workers, each sending 200 increments to ONE counter service over a real thread pool. If the
;; claim holds the answer is exactly 1600. Anything less is a lost update, which would be a defect
;; far larger than anything else in this ledger.
;;
;; Note F-052, the spawn scope law: a helper that returns a peer leaves the service thread dead,
;; so each worker's `connect` has to happen inside the worker. The address is passed as the item.
;;
;; Run: wat semaphores/ch01-lost-update.wat

(:wat::core::defsurface :sem::Counter :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :sem::Counter::GetRequest [])
   (:wat::core::defenum :sem::Counter::GetResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :sem::Counter::BumpRequest [n <- :wat::core::i64])
   (:wat::core::defenum :sem::Counter::BumpResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get  [self <- :sem::Counter  req <- :sem::Counter::GetRequest]  -> :sem::Counter::GetResponse  :max-request-bytes 524288)
   (bump [self <- :sem::Counter  req <- :sem::Counter::BumpRequest] -> :sem::Counter::BumpResponse :max-request-bytes 524288)])

(:wat::service::defservice :sem::counter
  :satisfies :sem::Counter
  :durable [count <- :wat::core::i64]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:sem::Counter::GetResponse.Ok
         {:value (:sem::counter::Record/count (:sem::counter::State/durable s))})}))
   ;; read-modify-write, deliberately written as three separate steps: if anything could
   ;; interleave between them, this is where an update would be lost.
   (bump [s ctx req]
     (:wat::core::let [old (:sem::counter::Record/count (:sem::counter::State/durable s))
                       add (:sem::Counter::BumpRequest/n req)
                       new (:wat::i64::+ old add)]
       (:wat::service::Outcome.Reply
         {:state (:sem::counter::State :durable (:sem::counter::Record :count new))
          :reply (:sem::Counter::BumpResponse.Ok {:value new})})))])

(:wat::core::defn :sem::workers [] -> :wat::core::i64 8)
(:wat::core::defn :sem::per-worker [] -> :wat::core::i64 200)

;; one worker: connect (inline, per F-052), then send K increments
(:wat::core::defn :sem::work :- [T]
  [addr <- (:wat::kernel::Address :- [(:sem::Counter::Op :- []) (:sem::Counter::Reply :- []) :T])]
  -> :wat::core::i64
  (:wat::core::let
    [c (:wat::core::match (:wat::kernel::connect addr)
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause x} (:wat::kernel::assertion-failed! :message "refused")]
         [:wat::kernel::ConnectOutcome.Rejected {:cause x} (:wat::kernel::assertion-failed! :message "rejected")]
         [:wat::kernel::ConnectOutcome.Failed {:cause x} (:wat::kernel::assertion-failed! :message "failed")])]
    (:wat::core::foldl
      (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
        (:wat::core::match (:sem::Counter/bump c (:sem::Counter::BumpRequest :n 1))
          [:wat::kernel::RecvOutcome.Message {:msg m} (:wat::core::+ a 1)]
          [:wat::kernel::RecvOutcome.Lost {:cause x} a]
          [:wat::kernel::RecvOutcome.Stopped {} a]
          [:wat::kernel::RecvOutcome.Closed {} a]))
      0 (:wat::core::range 0 (:sem::per-worker)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:sem::counter/start :locus (:wat::spawn::thread) :record (:sem::counter::Record :count 0))
     addr (:sem::counter::Handle/addr h)
     items (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 i)
                             (:wat::core::range 0 (:sem::workers)))
     sent (:wat::bracket::map (:wat::spawn::thread) items
            (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:sem::work addr)))
     total (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                                (:wat::core::+ a b)) 0 sent)
     c (:wat::core::match (:wat::kernel::connect addr)
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause x} (:wat::kernel::assertion-failed! :message "refused")]
         [:wat::kernel::ConnectOutcome.Rejected {:cause x} (:wat::kernel::assertion-failed! :message "rejected")]
         [:wat::kernel::ConnectOutcome.Failed {:cause x} (:wat::kernel::assertion-failed! :message "failed")])
     final (:wat::core::match (:sem::Counter/get c (:sem::Counter::GetRequest))
             [:wat::kernel::RecvOutcome.Message {:msg m}
               (:wat::core::match m
                 [:sem::Counter::GetResponse.Ok {:value v} v]
                 [:sem::Counter::GetResponse.RequestTooLarge {:bytes b :cap k} -1]
                 [:sem::Counter::GetResponse.RequestMalformed {:path p :expected e :got g} -2])]
             [:wat::kernel::RecvOutcome.Lost {:cause x} -3]
             [:wat::kernel::RecvOutcome.Stopped {} -4]
             [:wat::kernel::RecvOutcome.Closed {} -5])
     expect (:wat::core::* (:sem::workers) (:sem::per-worker))]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "workers=" (:wat::i64::to-string (:sem::workers))
        "  each sending " (:wat::i64::to-string (:sem::per-worker)))))
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "acknowledged sends  " (:wat::i64::to-string total) " / " (:wat::i64::to-string expect))))
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "counter final value " (:wat::i64::to-string final) " / " (:wat::i64::to-string expect)
        "   " (:wat::core::if (:wat::core::= final expect) "PASS -- no lost update" "FAIL -- LOST UPDATE")))))))
