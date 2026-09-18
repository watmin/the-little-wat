;; semaphores/lib/sem.wat — a counting semaphore, which is the whole of Downey's book.
;;
;; Every pattern in The Little Book of Semaphores is built from one primitive: a counter you may
;; increment freely (`signal`) and may only decrement when it is positive (`wait`). Once that
;; exists, signalling, rendezvous, mutex, multiplex, barriers, producer-consumer, readers-writers
;; and the dining philosophers are all compositions of it.
;;
;; ┌─ WHAT F-102 COSTS, AND WHY IT IS HERE RATHER THAN IN EACH PUZZLE ──────────────────────────┐
;; │ `wait` is supposed to BLOCK. wat cannot block a caller: `:wat::service::Outcome.NoReply`    │
;; │ withholds a reply and nothing can ever release that caller — measured, it hangs forever     │
;; │ (F-102). So `wait` here is `try-wait` in a loop, and every wait costs a round-trip per poll │
;; │ at F-051's ~224 µs. The poll count is threaded out of every puzzle below, because that      │
;; │ number IS the price of the missing primitive, and it is the one thing these ports measure   │
;; │ that a language with blocking would not have to.                                           │
;; └────────────────────────────────────────────────────────────────────────────────────────────┘
;;
;; One service hosts MANY named semaphores, because the classical problems need several at once —
;; the bounded buffer alone wants `items`, `spaces` and a mutex.

(:wat::core::defsurface :sem::Sem :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :sem::Sem::InitRequest [name <- :wat::core::String  n <- :wat::core::i64])
   (:wat::core::defenum :sem::Sem::InitResponse :wat::enum::Pure
     :Ok               [n <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   ;; try-wait: decrement if positive. The reply says whether it succeeded -- this is the verb
   ;; that would simply BLOCK in a language that could.
   (:wat::core::defrecord :sem::Sem::TryRequest [name <- :wat::core::String])
   (:wat::core::defenum :sem::Sem::TryResponse :wat::enum::Pure
     :Acquired         [left <- :wat::core::i64]
     :Blocked          [left <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :sem::Sem::SignalRequest [name <- :wat::core::String])
   (:wat::core::defenum :sem::Sem::SignalResponse :wat::enum::Pure
     :Ok               [n <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :sem::Sem::PeekRequest [name <- :wat::core::String])
   (:wat::core::defenum :sem::Sem::PeekResponse :wat::enum::Pure
     :Ok               [n <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(init   [self <- :sem::Sem req <- :sem::Sem::InitRequest]   -> :sem::Sem::InitResponse   :max-request-bytes 524288)
   (try    [self <- :sem::Sem req <- :sem::Sem::TryRequest]    -> :sem::Sem::TryResponse    :max-request-bytes 524288)
   (signal [self <- :sem::Sem req <- :sem::Sem::SignalRequest] -> :sem::Sem::SignalResponse :max-request-bytes 524288)
   (peek   [self <- :sem::Sem req <- :sem::Sem::PeekRequest]   -> :sem::Sem::PeekResponse   :max-request-bytes 524288)])

(:wat::core::typealias :sem::Counts (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64]))

(:wat::service::defservice :sem::sem
  :satisfies :sem::Sem
  :durable [counts <- :sem::Counts]
  :ephemeral []
  :impls
  [(init [s ctx req]
     (:wat::service::Outcome.Reply
       {:state (:sem::sem::State :durable
                 (:sem::sem::Record :counts
                   (:wat::map::assoc (:sem::sem::Record/counts (:sem::sem::State/durable s))
                     (:sem::Sem::InitRequest/name req) (:sem::Sem::InitRequest/n req))))
        :reply (:sem::Sem::InitResponse.Ok {:n (:sem::Sem::InitRequest/n req)})}))
   ;; the decrement and the test are ONE service round, so no two callers can both see a 1
   (try [s ctx req]
     (:wat::core::let [m (:sem::sem::Record/counts (:sem::sem::State/durable s))
                       k (:sem::Sem::TryRequest/name req)
                       n (:wat::core::match (:wat::map::get m k)
                           [:wat::core::Option.Some {:value v} v]
                           [:wat::core::Option.None {} 0])]
       (:wat::core::if (:wat::core::> n 0)
         (:wat::service::Outcome.Reply
           {:state (:sem::sem::State :durable (:sem::sem::Record :counts (:wat::map::assoc m k (:wat::core::- n 1))))
            :reply (:sem::Sem::TryResponse.Acquired {:left (:wat::core::- n 1)})})
         (:wat::service::Outcome.Reply {:state s :reply (:sem::Sem::TryResponse.Blocked {:left n})}))))
   (signal [s ctx req]
     (:wat::core::let [m (:sem::sem::Record/counts (:sem::sem::State/durable s))
                       k (:sem::Sem::SignalRequest/name req)
                       n (:wat::core::match (:wat::map::get m k)
                           [:wat::core::Option.Some {:value v} v]
                           [:wat::core::Option.None {} 0])]
       (:wat::service::Outcome.Reply
         {:state (:sem::sem::State :durable (:sem::sem::Record :counts (:wat::map::assoc m k (:wat::core::+ n 1))))
          :reply (:sem::Sem::SignalResponse.Ok {:n (:wat::core::+ n 1)})})))
   (peek [s ctx req]
     (:wat::core::let [m (:sem::sem::Record/counts (:sem::sem::State/durable s))
                       n (:wat::core::match (:wat::map::get m (:sem::Sem::PeekRequest/name req))
                           [:wat::core::Option.Some {:value v} v]
                           [:wat::core::Option.None {} 0])]
       (:wat::service::Outcome.Reply {:state s :reply (:sem::Sem::PeekResponse.Ok {:n n})})))])

;; ---- the client side. `wait` is the spin F-102 forces; it answers how many polls it cost.
(:wat::core::typealias :sem::Conn
  (:wat::kernel::Peer :- [(:sem::Sem::Op :- []) (:sem::Sem::Reply :- [])]))

(:wat::core::defn :sem::connect-to :- [T]
  [addr <- (:wat::kernel::Address :- [(:sem::Sem::Op :- []) (:sem::Sem::Reply :- []) :T])] -> :sem::Conn
  (:wat::core::match (:wat::kernel::connect addr)
    [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
    [:wat::kernel::ConnectOutcome.Refused {:cause x} (:wat::kernel::assertion-failed! :message "sem: refused")]
    [:wat::kernel::ConnectOutcome.Rejected {:cause x} (:wat::kernel::assertion-failed! :message "sem: rejected")]
    [:wat::kernel::ConnectOutcome.Failed {:cause x} (:wat::kernel::assertion-failed! :message "sem: failed")]))

(:wat::core::defn :sem::do-init [c <- :sem::Conn name <- :wat::core::String n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:sem::Sem/init c (:sem::Sem::InitRequest :name name :n n))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sem::Sem::InitResponse.Ok {:n k} k]
        [:sem::Sem::InitResponse.RequestTooLarge {:bytes b :cap q} -1]
        [:sem::Sem::InitResponse.RequestMalformed {:path p :expected e :got g} -2])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} -3]
    [:wat::kernel::RecvOutcome.Stopped {} -4]
    [:wat::kernel::RecvOutcome.Closed {} -5]))

(:wat::core::defn :sem::do-signal [c <- :sem::Conn name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:sem::Sem/signal c (:sem::Sem::SignalRequest :name name))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sem::Sem::SignalResponse.Ok {:n k} k]
        [:sem::Sem::SignalResponse.RequestTooLarge {:bytes b :cap q} -1]
        [:sem::Sem::SignalResponse.RequestMalformed {:path p :expected e :got g} -2])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} -3]
    [:wat::kernel::RecvOutcome.Stopped {} -4]
    [:wat::kernel::RecvOutcome.Closed {} -5]))

(:wat::core::defn :sem::do-peek [c <- :sem::Conn name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:sem::Sem/peek c (:sem::Sem::PeekRequest :name name))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sem::Sem::PeekResponse.Ok {:n k} k]
        [:sem::Sem::PeekResponse.RequestTooLarge {:bytes b :cap q} -1]
        [:sem::Sem::PeekResponse.RequestMalformed {:path p :expected e :got g} -2])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} -3]
    [:wat::kernel::RecvOutcome.Stopped {} -4]
    [:wat::kernel::RecvOutcome.Closed {} -5]))

(:wat::core::defn :sem::try-once [c <- :sem::Conn name <- :wat::core::String] -> :wat::core::bool
  (:wat::core::match (:sem::Sem/try c (:sem::Sem::TryRequest :name name))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:sem::Sem::TryResponse.Acquired {:left k} true]
        [:sem::Sem::TryResponse.Blocked {:left k} false]
        [:sem::Sem::TryResponse.RequestTooLarge {:bytes b :cap q} false]
        [:sem::Sem::TryResponse.RequestMalformed {:path p :expected e :got g} false])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} false]
    [:wat::kernel::RecvOutcome.Stopped {} false]
    [:wat::kernel::RecvOutcome.Closed {} false]))

;; THE SPIN. In Downey this is one instruction and the thread sleeps. Here it is a round-trip per
;; attempt, and the count is returned so every puzzle can report what F-102 cost it.
(:wat::core::defn :sem::wait [c <- :sem::Conn name <- :wat::core::String polls <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:sem::try-once c name) polls
    (:sem::wait c name (:wat::core::+ polls 1))))
