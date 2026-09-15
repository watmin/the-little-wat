;; mal/lib/env.wat: mal's environments and atoms, on a service. Needs lib/types.wat (which
;; declares the service's protocol, :mal::Store, and mal's values inside it). No main.
;;
;; An environment is a frame of bindings and the id of its outer frame (-1 for none). All the
;; frames, and all the atoms, live in one service's state, keyed by id, so a closure can hold
;; its environment by id and see what is defined there later: mal's environments are shared and
;; mutable, and in wat that state lives on a service (C-014). A lookup walks the frames inside
;; the service, one message per lookup. Keyword spelling throughout.

(:wat::core::defrecord :mal::Frame
  [vars  <- (:wat::core::HashMap :- [:wat::core::String :mal::Val])
   outer <- :wat::core::i64])

(:wat::core::typealias :mal::Frames (:wat::core::HashMap :- [:wat::core::i64 :mal::Frame]))
(:wat::core::typealias :mal::Atoms (:wat::core::HashMap :- [:wat::core::i64 :mal::Val]))

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
  :durable [frames <- :mal::Frames  atoms <- :mal::Atoms  next <- :wat::core::i64]
  :ephemeral []
  :impls
  [(new-env [s ctx req]
     (:wat::core::let [rec (:mal::store::State/durable s)
                       id (:mal::store::Record/next rec)
                       frame (:mal::Frame :vars (:wat::core::HashMap :- [:wat::core::String :mal::Val]) :outer (:mal::Store::NewEnvRequest/outer req))]
       (:wat::service::Outcome.Reply
         {:state (:mal::store::State :durable (:mal::store::Record :frames (:wat::hashmap::assoc (:mal::store::Record/frames rec) id frame)
                                                                   :atoms (:mal::store::Record/atoms rec)
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
                         :atoms (:mal::store::Record/atoms rec)
                         :next (:mal::store::Record/next rec)))
              :reply (:mal::Store::SetResponse.Ok {:value v})})]
         [:wat::core::Option.None {}
           (:wat::service::Outcome.Reply {:state s :reply (:mal::Store::SetResponse.Ok {:value v})})])))
   (new-atom [s ctx req]
     (:wat::core::let [rec (:mal::store::State/durable s)
                       id (:mal::store::Record/next rec)]
       (:wat::service::Outcome.Reply
         {:state (:mal::store::State :durable (:mal::store::Record :frames (:mal::store::Record/frames rec)
                                                                   :atoms (:wat::hashmap::assoc (:mal::store::Record/atoms rec) id (:mal::Store::NewAtomRequest/value req))
                                                                   :next (:wat::core::+ id 1)))
          :reply (:mal::Store::NewAtomResponse.Ok {:id id})})))
   (deref [s ctx req]
     (:wat::service::Outcome.Reply
       {:state s
        :reply (:mal::Store::DerefResponse.Ok
                 {:value (:wat::core::match (:wat::hashmap::get (:mal::store::Record/atoms (:mal::store::State/durable s)) (:mal::Store::DerefRequest/id req))
                           [:wat::core::Option.Some {:value v} v]
                           [:wat::core::Option.None {} (:mal::nil)])})}))
   (reset [s ctx req]
     (:wat::core::let [rec (:mal::store::State/durable s)
                       v (:mal::Store::ResetRequest/value req)]
       (:wat::service::Outcome.Reply
         {:state (:mal::store::State :durable (:mal::store::Record :frames (:mal::store::Record/frames rec)
                                                                   :atoms (:wat::hashmap::assoc (:mal::store::Record/atoms rec) (:mal::Store::ResetRequest/id req) v)
                                                                   :next (:mal::store::Record/next rec)))
          :reply (:mal::Store::ResetResponse.Ok {:value v})})))])

;; A running store: its Handle (kept so the service stays owned) and a connected peer.
(:wat::core::defstruct :mal::StoreRef
  [handle <- :mal::store::Handle
   peer   <- :mal::Store])

(:wat::core::defn :mal::new-store [] -> :mal::StoreRef
  (:wat::core::let
    [h (:mal::store/start :locus (:wat::spawn::thread)
                          :record (:mal::store::Record :frames (:wat::core::HashMap :- [:wat::core::i64 :mal::Frame])
                                                       :atoms (:wat::core::HashMap :- [:wat::core::i64 :mal::Val])
                                                       :next 0))
     p (:wat::core::match (:wat::kernel::connect (:mal::store::Handle/addr h))
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))]
         [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message (:wat::kernel::Failure/message c))])]
    (:mal::StoreRef :handle h :peer p)))

;; ---- the client side: one function per message, each unpacking every outcome

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

;; a new atom holding v; answers its id
(:wat::core::defn :mal::new-atom! [st <- :mal::StoreRef v <- :mal::Val] -> :wat::core::i64
  (:wat::core::match (:mal::Store/new-atom (:mal::StoreRef/peer st) (:mal::Store::NewAtomRequest :value v))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:mal::Store::NewAtomResponse.Ok {:id id} id]
        [:mal::Store::NewAtomResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "store new-atom: request too large")]
        [:mal::Store::NewAtomResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "store new-atom: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "store new-atom: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "store new-atom: closed")]))

(:wat::core::defn :mal::atom-deref [st <- :mal::StoreRef id <- :wat::core::i64] -> :mal::Val
  (:wat::core::match (:mal::Store/deref (:mal::StoreRef/peer st) (:mal::Store::DerefRequest :id id))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:mal::Store::DerefResponse.Ok {:value v} v]
        [:mal::Store::DerefResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "store deref: request too large")]
        [:mal::Store::DerefResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "store deref: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "store deref: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "store deref: closed")]))

(:wat::core::defn :mal::atom-reset! [st <- :mal::StoreRef id <- :wat::core::i64 v <- :mal::Val] -> :mal::Val
  (:wat::core::match (:mal::Store/reset (:mal::StoreRef/peer st) (:mal::Store::ResetRequest :id id :value v))
    [:wat::kernel::RecvOutcome.Message {:msg m}
      (:wat::core::match m
        [:mal::Store::ResetResponse.Ok {:value x} x]
        [:mal::Store::ResetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::assertion-failed! :message "store reset: request too large")]
        [:mal::Store::ResetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::assertion-failed! :message "store reset: request malformed")])]
    [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::assertion-failed! :message (:wat::kernel::LociDiedError/message x))]
    [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::assertion-failed! :message "store reset: stopped")]
    [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::assertion-failed! :message "store reset: closed")]))

;; a value with each atom inside it replaced by (atom <its value>), for printing
(:wat::core::defn :mal::show-atoms [v <- :mal::Val st <- :mal::StoreRef] -> :mal::Val
  (:wat::core::match v
    [:mal::Val.Atom {:id i} (:mal::list (:wat::core::Vector :- [:mal::Val] (:mal::sym "atom") (:mal::show-atoms (:mal::atom-deref st i) st)))]
    [:mal::Val.List {:items xs} (:mal::list (:wat::core::mapv (:wat::core::fn [x <- :mal::Val] -> :mal::Val (:mal::show-atoms x st)) xs))]
    [:mal::Val.Vec {:items xs} (:mal::vec (:wat::core::mapv (:wat::core::fn [x <- :mal::Val] -> :mal::Val (:mal::show-atoms x st)) xs))]
    [:mal::Val.Map {:kvs xs} (:mal::map (:wat::core::mapv (:wat::core::fn [x <- :mal::Val] -> :mal::Val (:mal::show-atoms x st)) xs))]
    [:mal::Val.Nil {} v]
    [:mal::Val.True {} v]
    [:mal::Val.False {} v]
    [:mal::Val.Int {:n n} v]
    [:mal::Val.Str {:s s} v]
    [:mal::Val.Sym {:name x} v]
    [:mal::Val.Kw {:name x} v]
    [:mal::Val.Builtin {:name x} v]
    [:mal::Val.Closure {:params p :body b :env e} v]
    [:mal::Val.Macro {:params p :body b :env e} v]))

(:wat::core::defn :mal::show-res [r <- :mal::Res st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match r
    [:mal::Res.Ok {:v v} (:mal::ok (:mal::show-atoms v st))]
    [:mal::Res.Err {:e e} (:mal::err (:mal::show-atoms e st))]))
