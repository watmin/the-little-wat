;; eopl/lib/threads.wat — EOPL chapter 5's THREADS language: a scheduler built on continuations.
;;
;; THE POINT, and it closes a loop in this ledger:
;;   C-053  wat's own services CANNOT lose an update -- the actor serialises, so Downey's chapter 1
;;          hazard is unrepresentable.
;;   F-102  and wat CANNOT BLOCK A CALLER -- `Outcome.NoReply` withholds a reply and nothing can
;;          ever release that caller, so every blocking primitive in wat must be a spin.
;;
;; Once a continuation is a data structure, both of those become trivial. A thread IS a
;; continuation; the scheduler is a queue of them; blocking is "move this continuation to the
;; blocked list and run someone else"; waking is "move it back". So this interpreter has the
;; primitive wat lacks -- inside a language wat is hosting.
;;
;; It also reintroduces the hazard on purpose. `get` and `put` are separate expressions, so a
;; thread can be preempted between reading the counter and writing it back, which is exactly the
;; lost update. With a mutex it cannot. That is Downey chapters 1 and 3, in a language where the
;; interleaving is ours to control.
;;
;; Values are i64 only -- no closures -- to keep the machine small enough to read.

(:wat::core::defenum :thr::Exp :wat::enum::Pure
  :Lit    [n <- :wat::core::i64]
  :Var    [name <- :wat::core::String]
  :Add    [a <- :thr::Exp  b <- :thr::Exp]
  :Seq    [a <- :thr::Exp  b <- :thr::Exp]
  :Let    [name <- :wat::core::String  e <- :thr::Exp  body <- :thr::Exp]
  :Get    []
  :Put    [e <- :thr::Exp]
  :Spawn  [body <- :thr::Exp]
  :Lock   []
  :Unlock []
  :Repeat [times <- :wat::core::i64  body <- :thr::Exp])

(:wat::core::defenum :thr::Env :wat::enum::Pure
  :E0 []
  :E1 [name <- :wat::core::String  v <- :wat::core::i64  rest <- :thr::Env])

(:wat::core::defn :thr::look [env <- :thr::Env name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match env
    [:thr::Env.E0 {} 0]
    [:thr::Env.E1 {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:thr::look rest name))]))

(:wat::core::defenum :thr::K :wat::enum::Pure
  :KEnd  []
  :KAdd1 [b <- :thr::Exp  env <- :thr::Env  k <- :thr::K]
  :KAdd2 [v <- :wat::core::i64  k <- :thr::K]
  :KSeq  [b <- :thr::Exp  env <- :thr::Env  k <- :thr::K]
  :KLet  [name <- :wat::core::String  body <- :thr::Exp  env <- :thr::Env  k <- :thr::K]
  :KPut  [k <- :thr::K]
  :KRep  [left <- :wat::core::i64  body <- :thr::Exp  env <- :thr::Env  k <- :thr::K])

;; a thread is a suspended machine: either about to evaluate, or about to return a value
(:wat::core::defenum :thr::Thread :wat::enum::Pure
  :TEval  [e <- :thr::Exp  env <- :thr::Env  k <- :thr::K]
  :TApply [k <- :thr::K  v <- :wat::core::i64])

(:wat::core::defenum :thr::TList :wat::enum::Pure
  :TNil  []
  :TCons [t <- :thr::Thread  rest <- :thr::TList])

;; the scheduler: a ready queue, a blocked list, the shared counter, the mutex, the time slice
(:wat::core::defenum :thr::Sched :wat::enum::Pure
  :S [ready <- :thr::TList  blocked <- :thr::TList
      store <- :wat::core::i64  locked <- :wat::core::bool
      slice <- :wat::core::i64  fuel <- :wat::core::i64])

(:wat::core::defn :thr::snoc-t [l <- :thr::TList t <- :thr::Thread] -> :thr::TList
  (:wat::core::match l
    [:thr::TList.TNil {} (:thr::TList.TCons {:t t :rest (:thr::TList.TNil {})})]
    [:thr::TList.TCons {:t h :rest rest} (:thr::TList.TCons {:t h :rest (:thr::snoc-t rest t)})]))

;; the outcome of one transition
(:wat::core::defenum :thr::Out :wat::enum::Pure
  :ORun   [t <- :thr::Thread  s <- :thr::Sched]
  :ODone  [s <- :thr::Sched]
  :OBlock [t <- :thr::Thread  s <- :thr::Sched])

(:wat::core::defn :thr::with-ready [s <- :thr::Sched r <- :thr::TList] -> :thr::Sched
  (:wat::core::match s
    [:thr::Sched.S {:ready ready :blocked b :store st :locked l :slice sl :fuel f}
      (:thr::Sched.S {:ready r :blocked b :store st :locked l :slice sl :fuel f})]))

(:wat::core::defn :thr::step [t <- :thr::Thread s <- :thr::Sched] -> :thr::Out
  (:wat::core::match s
    [:thr::Sched.S {:ready ready :blocked blocked :store store :locked locked :slice slice :fuel fuel}
      (:wat::core::match t
        [:thr::Thread.TEval {:e e :env env :k k}
          (:wat::core::match e
            [:thr::Exp.Lit {:n n} (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k :v n}) :s s})]
            [:thr::Exp.Var {:name name}
              (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k :v (:thr::look env name)}) :s s})]
            [:thr::Exp.Get {} (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k :v store}) :s s})]
            [:thr::Exp.Add {:a a :b b}
              (:thr::Out.ORun {:t (:thr::Thread.TEval {:e a :env env :k (:thr::K.KAdd1 {:b b :env env :k k})}) :s s})]
            [:thr::Exp.Seq {:a a :b b}
              (:thr::Out.ORun {:t (:thr::Thread.TEval {:e a :env env :k (:thr::K.KSeq {:b b :env env :k k})}) :s s})]
            [:thr::Exp.Let {:name name :e rhs :body body}
              (:thr::Out.ORun {:t (:thr::Thread.TEval {:e rhs :env env :k (:thr::K.KLet {:name name :body body :env env :k k})}) :s s})]
            [:thr::Exp.Put {:e inner}
              (:thr::Out.ORun {:t (:thr::Thread.TEval {:e inner :env env :k (:thr::K.KPut {:k k})}) :s s})]
            [:thr::Exp.Repeat {:times times :body body}
              (:wat::core::if (:wat::core::<= times 0)
                (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k :v 0}) :s s})
                (:thr::Out.ORun {:t (:thr::Thread.TEval {:e body :env env
                                       :k (:thr::K.KRep {:left (:wat::core::- times 1) :body body :env env :k k})}) :s s}))]
            ;; SPAWN: a new thread is just a new (Exp, Env, K) on the ready queue
            [:thr::Exp.Spawn {:body body}
              (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k :v 0})
                               :s (:thr::with-ready s
                                    (:thr::snoc-t ready (:thr::Thread.TEval {:e body :env (:thr::Env.E0 {}) :k (:thr::K.KEnd {})})))})]
            ;; LOCK: this is the primitive F-102 says wat itself cannot express
            [:thr::Exp.Lock {}
              (:wat::core::if locked
                (:thr::Out.OBlock {:t t :s s})
                (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k :v 1})
                                 :s (:thr::Sched.S {:ready ready :blocked blocked :store store
                                                    :locked true :slice slice :fuel fuel})}))]
            ;; UNLOCK: release, and wake one blocked continuation by moving it back to ready
            [:thr::Exp.Unlock {}
              (:wat::core::match blocked
                [:thr::TList.TNil {}
                  (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k :v 0})
                                   :s (:thr::Sched.S {:ready ready :blocked blocked :store store
                                                      :locked false :slice slice :fuel fuel})})]
                [:thr::TList.TCons {:t bt :rest brest}
                  (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k :v 0})
                                   :s (:thr::Sched.S {:ready (:thr::snoc-t ready bt) :blocked brest
                                                      :store store :locked false :slice slice :fuel fuel})})])])]
        [:thr::Thread.TApply {:k k :v v}
          (:wat::core::match k
            [:thr::K.KEnd {} (:thr::Out.ODone {:s s})]
            [:thr::K.KAdd1 {:b b :env env :k k2}
              (:thr::Out.ORun {:t (:thr::Thread.TEval {:e b :env env :k (:thr::K.KAdd2 {:v v :k k2})}) :s s})]
            [:thr::K.KAdd2 {:v v1 :k k2}
              (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k2 :v (:wat::core::+ v1 v)}) :s s})]
            [:thr::K.KSeq {:b b :env env :k k2}
              (:thr::Out.ORun {:t (:thr::Thread.TEval {:e b :env env :k k2}) :s s})]
            [:thr::K.KLet {:name name :body body :env env :k k2}
              (:thr::Out.ORun {:t (:thr::Thread.TEval {:e body :env (:thr::Env.E1 {:name name :v v :rest env}) :k k2}) :s s})]
            [:thr::K.KPut {:k k2}
              (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k2 :v v})
                               :s (:thr::Sched.S {:ready ready :blocked blocked :store v
                                                  :locked locked :slice slice :fuel fuel})})]
            [:thr::K.KRep {:left left :body body :env env :k k2}
              (:wat::core::if (:wat::core::<= left 0)
                (:thr::Out.ORun {:t (:thr::Thread.TApply {:k k2 :v v}) :s s})
                (:thr::Out.ORun {:t (:thr::Thread.TEval {:e body :env env
                                       :k (:thr::K.KRep {:left (:wat::core::- left 1) :body body :env env :k k2})}) :s s}))])])]))

;; run ONE thread for up to `n` transitions, then hand it back for rotation
(:wat::core::defn :thr::run-slice [t <- :thr::Thread s <- :thr::Sched n <- :wat::core::i64] -> :thr::Out
  (:wat::core::if (:wat::core::<= n 0)
    (:thr::Out.ORun {:t t :s s})
    (:wat::core::match (:thr::step t s)
      [:thr::Out.ODone {:s s2} (:thr::Out.ODone {:s s2})]
      [:thr::Out.OBlock {:t t2 :s s2} (:thr::Out.OBlock {:t t2 :s s2})]
      [:thr::Out.ORun {:t t2 :s s2} (:thr::run-slice t2 s2 (:wat::core::- n 1))])))

;; the scheduler: round-robin over the ready queue, tail-recursive so the host stack is constant
(:wat::core::defn :thr::schedule [s <- :thr::Sched] -> :wat::core::i64
  (:wat::core::match s
    [:thr::Sched.S {:ready ready :blocked blocked :store store :locked locked :slice slice :fuel fuel}
      (:wat::core::if (:wat::core::<= fuel 0)
        store
        (:wat::core::match ready
          [:thr::TList.TNil {} store]
          [:thr::TList.TCons {:t head :rest rest}
            (:wat::core::let
              [s1 (:thr::Sched.S {:ready rest :blocked blocked :store store :locked locked
                                  :slice slice :fuel (:wat::core::- fuel 1)})]
              (:wat::core::match (:thr::run-slice head s1 slice)
                [:thr::Out.ODone {:s s2} (:thr::schedule s2)]
                [:thr::Out.ORun {:t t2 :s s2}
                  (:wat::core::match s2
                    [:thr::Sched.S {:ready r2 :blocked b2 :store st2 :locked l2 :slice sl2 :fuel f2}
                      (:thr::schedule (:thr::Sched.S {:ready (:thr::snoc-t r2 t2) :blocked b2 :store st2
                                                      :locked l2 :slice sl2 :fuel f2}))])]
                ;; BLOCKED: park the continuation and run someone else -- F-102's missing primitive
                [:thr::Out.OBlock {:t t2 :s s2}
                  (:wat::core::match s2
                    [:thr::Sched.S {:ready r2 :blocked b2 :store st2 :locked l2 :slice sl2 :fuel f2}
                      (:thr::schedule (:thr::Sched.S {:ready r2 :blocked (:thr::snoc-t b2 t2) :store st2
                                                      :locked l2 :slice sl2 :fuel f2}))])]))]))]))

(:wat::core::defn :thr::run [main <- :thr::Exp slice <- :wat::core::i64 fuel <- :wat::core::i64] -> :wat::core::i64
  (:thr::schedule
    (:thr::Sched.S {:ready (:thr::TList.TCons {:t (:thr::Thread.TEval {:e main :env (:thr::Env.E0 {}) :k (:thr::K.KEnd {})})
                                               :rest (:thr::TList.TNil {})})
                    :blocked (:thr::TList.TNil {}) :store 0 :locked false :slice slice :fuel fuel})))
