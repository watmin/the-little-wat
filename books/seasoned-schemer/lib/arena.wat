;; The Seasoned Schemer, ch 18 (mutable lists): an Arena. The book's konses have a kdr that
;; set-kdr can change in place, so lists can share structure and even form cycles. wat's
;; values are immutable trees, and a Cell cannot hold another Cell's live Handle (FINDINGS.md,
;; R-002's rule). So memory is modelled the way wat allows: ONE service holding a table of
;; nodes, where a pointer is an integer id, -1 is the empty list, and set-kdr! rewrites one
;; table entry. Needs nothing else loaded. No main here. Keyword spelling throughout.

(:wat::core::defsurface :ss::Arena :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :ss::Arena::KonsRequest [kar <- :wat::WatAST  kdr <- :wat::core::i64])
   (:wat::core::defenum :ss::Arena::KonsResponse :wat::enum::Pure
     :Ok               [id <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :ss::Arena::KarRequest [id <- :wat::core::i64])
   (:wat::core::defenum :ss::Arena::KarResponse :wat::enum::Pure
     :Ok               [value <- :wat::WatAST]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :ss::Arena::KdrRequest [id <- :wat::core::i64])
   (:wat::core::defenum :ss::Arena::KdrResponse :wat::enum::Pure
     :Ok               [value <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :ss::Arena::SetKdrRequest [id <- :wat::core::i64  kdr <- :wat::core::i64])
   (:wat::core::defenum :ss::Arena::SetKdrResponse :wat::enum::Pure
     :Ok               [id <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(kons    [self <- :ss::Arena  req <- :ss::Arena::KonsRequest]   -> :ss::Arena::KonsResponse   :max-request-bytes 524288)
   (kar     [self <- :ss::Arena  req <- :ss::Arena::KarRequest]    -> :ss::Arena::KarResponse    :max-request-bytes 524288)
   (kdr     [self <- :ss::Arena  req <- :ss::Arena::KdrRequest]    -> :ss::Arena::KdrResponse    :max-request-bytes 524288)
   (set-kdr [self <- :ss::Arena  req <- :ss::Arena::SetKdrRequest] -> :ss::Arena::SetKdrResponse :max-request-bytes 524288)])

(:wat::service::defservice :ss::arena
  :satisfies :ss::Arena
  :durable [next <- :wat::core::i64
            kars <- (:wat::core::HashMap :- [:wat::core::i64 :wat::WatAST])
            kdrs <- (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64])]
  :ephemeral []
  :impls
  [(kons [s ctx req]
     (:wat::core::let [r  (:ss::arena::State/durable s)
                       id (:ss::arena::Record/next r)]
       (:wat::service::Outcome.Reply
         {:state (:ss::arena::State :durable
                   (:ss::arena::Record :next (:wat::i64::+ id 1)
                                       :kars (:wat::core::assoc (:ss::arena::Record/kars r) id (:ss::Arena::KonsRequest/kar req))
                                       :kdrs (:wat::core::assoc (:ss::arena::Record/kdrs r) id (:ss::Arena::KonsRequest/kdr req))))
          :reply (:ss::Arena::KonsResponse.Ok {:id id})})))
   (kar [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:ss::Arena::KarResponse.Ok
         {:value (:wat::core::match (:wat::core::get (:ss::arena::Record/kars (:ss::arena::State/durable s))
                                                     (:ss::Arena::KarRequest/id req))
                   [:wat::core::Option.Some {:value v} v]
                   [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message "arena kar: no such node")])})}))
   (kdr [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:ss::Arena::KdrResponse.Ok
         {:value (:wat::core::match (:wat::core::get (:ss::arena::Record/kdrs (:ss::arena::State/durable s))
                                                     (:ss::Arena::KdrRequest/id req))
                   [:wat::core::Option.Some {:value v} v]
                   [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message "arena kdr: no such node")])})}))
   (set-kdr [s ctx req]
     (:wat::core::let [r (:ss::arena::State/durable s)]
       (:wat::service::Outcome.Reply
         {:state (:ss::arena::State :durable
                   (:ss::arena::Record :next (:ss::arena::Record/next r)
                                       :kars (:ss::arena::Record/kars r)
                                       :kdrs (:wat::core::assoc (:ss::arena::Record/kdrs r)
                                                                (:ss::Arena::SetKdrRequest/id req)
                                                                (:ss::Arena::SetKdrRequest/kdr req))))
          :reply (:ss::Arena::SetKdrResponse.Ok {:id (:ss::Arena::SetKdrRequest/id req)})})))])

;; A running arena: its Handle (kept so the service stays owned) and a connected peer.
(:wat::core::defstruct :ss::ArenaRef
  [handle <- :ss::arena::Handle
   peer   <- :ss::Arena])

(:wat::core::defn :ss::new-arena [] -> :ss::ArenaRef
  (:wat::core::let
    [h (:ss::arena/start :locus (:wat::spawn::thread)
         :record (:ss::arena::Record :next 0
                                     :kars (:wat::core::HashMap :- [:wat::core::i64 :wat::WatAST])
                                     :kdrs (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64])))
     p (:wat::core::match (:wat::kernel::connect (:ss::arena::Handle/addr h))
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:ss::ArenaRef :handle h :peer p)))

;; kons!: a new node (kar, kdr); answers its id. kdr is another node's id, or -1 for ().
(:wat::core::defn :ss::kons! [a <- :ss::ArenaRef kar <- :wat::WatAST kdr <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:ss::Arena/kons (:ss::ArenaRef/peer a) (:ss::Arena::KonsRequest :kar kar :kdr kdr))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Arena::KonsResponse.Ok {:id id} id]
        [:ss::Arena::KonsResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "arena kons: too large")]
        [:ss::Arena::KonsResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "arena kons: malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "arena: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "arena: closed")]))

(:wat::core::defn :ss::kar [a <- :ss::ArenaRef id <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::match (:ss::Arena/kar (:ss::ArenaRef/peer a) (:ss::Arena::KarRequest :id id))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Arena::KarResponse.Ok {:value v} v]
        [:ss::Arena::KarResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "arena kar: too large")]
        [:ss::Arena::KarResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "arena kar: malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "arena: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "arena: closed")]))

(:wat::core::defn :ss::kdr [a <- :ss::ArenaRef id <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:ss::Arena/kdr (:ss::ArenaRef/peer a) (:ss::Arena::KdrRequest :id id))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Arena::KdrResponse.Ok {:value v} v]
        [:ss::Arena::KdrResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "arena kdr: too large")]
        [:ss::Arena::KdrResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "arena kdr: malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "arena: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "arena: closed")]))

;; set-kdr!: point node id's kdr at another node (or -1); answers id
(:wat::core::defn :ss::set-kdr! [a <- :ss::ArenaRef id <- :wat::core::i64 kdr <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:ss::Arena/set-kdr (:ss::ArenaRef/peer a) (:ss::Arena::SetKdrRequest :id id :kdr kdr))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:ss::Arena::SetKdrResponse.Ok {:id i} i]
        [:ss::Arena::SetKdrResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "arena set-kdr: too large")]
        [:ss::Arena::SetKdrResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "arena set-kdr: malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "arena: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "arena: closed")]))
