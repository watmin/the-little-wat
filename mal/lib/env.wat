;; mal/lib/env.wat: mal's environments, on a service. Needs lib/types.wat (which declares the
;; service's protocol, :mal::Store, and mal's values inside it). No main.
;;
;; An environment is a frame of bindings and the id of its outer frame (-1 for none). All the
;; frames live in one service's state, keyed by id, so a closure can hold its environment by id
;; and see what is defined there later: mal's environments are shared and mutable, and in wat
;; that state lives on a service (C-014). A lookup walks the frames inside the service, one
;; message per lookup. Keyword spelling throughout.

(:wat::core::defrecord :mal::Frame
  [vars  <- (:wat::core::HashMap :- [:wat::core::String :mal::Val])
   outer <- :wat::core::i64])

(:wat::core::typealias :mal::Frames (:wat::core::HashMap :- [:wat::core::i64 :mal::Frame]))

(:wat::core::defn :mal::frame-find [frames <- :mal::Frames env <- :wat::core::i64 name <- :wat::core::String] -> (:wat::core::Option :- [:mal::Val])
  (:wat::core::match (:wat::hashmap::get frames env)
    [:wat::core::Option.Some {:value f}
      (:wat::core::match (:wat::hashmap::get (:mal::Frame/vars f) name)
        [:wat::core::Option.Some {:value v} (:wat::core::Option.Some {:value v})]
        [:wat::core::Option.None {}
          (:wat::core::if (:wat::core::< (:mal::Frame/outer f) 0)
            (:wat::core::Option.None {})
            (:mal::frame-find frames (:mal::Frame/outer f) name))])]
    [:wat::core::Option.None {} (:wat::core::Option.None {})]))

(:wat::service::defservice :mal::store
  :satisfies :mal::Store
  :durable [frames <- :mal::Frames  next <- :wat::core::i64]
  :ephemeral []
  :impls
  [(new-env [s ctx req]
     (:wat::core::let [rec (:mal::store::State/durable s)
                       id (:mal::store::Record/next rec)
                       frame (:mal::Frame :vars (:wat::core::HashMap :- [:wat::core::String :mal::Val]) :outer (:mal::Store::NewEnvRequest/outer req))]
       (:wat::service::Outcome.Reply
         {:state (:mal::store::State :durable (:mal::store::Record :frames (:wat::hashmap::assoc (:mal::store::Record/frames rec) id frame)
                                                                   :next (:wat::core::+ id 1)))
          :reply (:mal::Store::NewEnvResponse.Ok {:id id})})))
   (get [s ctx req]
     (:wat::service::Outcome.Reply
       {:state s
        :reply (:mal::Store::GetResponse.Ok
                 {:found (:mal::frame-find (:mal::store::Record/frames (:mal::store::State/durable s))
                                           (:mal::Store::GetRequest/env req) (:mal::Store::GetRequest/name req))})}))
   (set [s ctx req]
     (:wat::core::let [rec (:mal::store::State/durable s)
                       frames (:mal::store::Record/frames rec)
                       env (:mal::Store::SetRequest/env req)
                       v (:mal::Store::SetRequest/value req)]
       (:wat::core::match (:wat::hashmap::get frames env)
         [:wat::core::Option.Some {:value f}
           (:wat::service::Outcome.Reply
             {:state (:mal::store::State :durable
                       (:mal::store::Record
                         :frames (:wat::hashmap::assoc frames env
                                   (:mal::Frame :vars (:wat::hashmap::assoc (:mal::Frame/vars f) (:mal::Store::SetRequest/name req) v)
                                                :outer (:mal::Frame/outer f)))
                         :next (:mal::store::Record/next rec)))
              :reply (:mal::Store::SetResponse.Ok {:value v})})]
         [:wat::core::Option.None {}
           (:wat::service::Outcome.Reply {:state s :reply (:mal::Store::SetResponse.Ok {:value v})})])))])

;; A running store: its Handle (kept so the service stays owned) and a connected peer.
(:wat::core::defstruct :mal::StoreRef
  [handle <- :mal::store::Handle
   peer   <- :mal::Store])

(:wat::core::defn :mal::new-store [] -> :mal::StoreRef
  (:wat::core::let
    [h (:mal::store/start :locus (:wat::spawn::thread)
                          :record (:mal::store::Record :frames (:wat::core::HashMap :- [:wat::core::i64 :mal::Frame]) :next 0))
     p (:wat::core::match (:wat::kernel::connect (:mal::store::Handle/addr h))
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:mal::StoreRef :handle h :peer p)))

;; a new, empty environment inside outer (-1 for none); answers its id
(:wat::core::defn :mal::new-env! [st <- :mal::StoreRef outer <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:mal::Store/new-env (:mal::StoreRef/peer st) (:mal::Store::NewEnvRequest :outer outer))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:mal::Store::NewEnvResponse.Ok {:id id} id]
        [:mal::Store::NewEnvResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "store new-env: request too large")]
        [:mal::Store::NewEnvResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "store new-env: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "store new-env: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "store new-env: closed")]))

;; a name's value, looked up from env outward
(:wat::core::defn :mal::env-get [st <- :mal::StoreRef env <- :wat::core::i64 name <- :wat::core::String] -> (:wat::core::Option :- [:mal::Val])
  (:wat::core::match (:mal::Store/get (:mal::StoreRef/peer st) (:mal::Store::GetRequest :env env :name name))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:mal::Store::GetResponse.Ok {:found f} f]
        [:mal::Store::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "store get: request too large")]
        [:mal::Store::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "store get: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "store get: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "store get: closed")]))

;; bind a name in env itself; answers the value
(:wat::core::defn :mal::env-set! [st <- :mal::StoreRef env <- :wat::core::i64 name <- :wat::core::String v <- :mal::Val] -> :mal::Val
  (:wat::core::match (:mal::Store/set (:mal::StoreRef/peer st) (:mal::Store::SetRequest :env env :name name :value v))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:mal::Store::SetResponse.Ok {:value x} x]
        [:mal::Store::SetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "store set: request too large")]
        [:mal::Store::SetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "store set: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "store set: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "store set: closed")]))
