;; service-fn-state-impure.wat: follows service-fn-state.wat's own diagnostic, "Declare the
;; enum :wat::enum::Impure if it must hold a live resource (it then stays in shared memory
;; and never crosses)". The same function-holding service on a THREAD locus, with its
;; response enum Impure. Expected if the route works: 7
(:wat::core::defsurface :u::FnCell :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :u::FnCell::GetRequest [])
   (:wat::core::defenum :u::FnCell::GetResponse :wat::enum::Impure
     :Ok               [value <- [:wat::WatAST :-> :wat::core::i64]]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get [self <- :u::FnCell  req <- :u::FnCell::GetRequest] -> :u::FnCell::GetResponse :max-request-bytes 524288)])
(:wat::service::defservice :u::fncell
  :satisfies :u::FnCell
  :durable [f <- [:wat::WatAST :-> :wat::core::i64]]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:u::FnCell::GetResponse.Ok {:value (:u::fncell::Record/f (:u::fncell::State/durable s))})}))])
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:u::fncell/start :locus (:wat::spawn::thread)
         :record (:u::fncell::Record :f (:wat::core::fn [l <- :wat::WatAST] -> :wat::core::i64 7)))
     c (:wat::core::match (:wat::kernel::connect (:u::fncell::Handle/addr h))
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message "refused")]
         [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message "rejected")]
         [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message "failed")])]
    (:wat::core::match (:u::FnCell/get c (:u::FnCell::GetRequest))
      [:wat::kernel::RecvOutcome.Message {:msg m}
        (:wat::core::match m
          [:u::FnCell::GetResponse.Ok {:value f} (:wat::kernel::println (f 'pear))]
          [:u::FnCell::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::println "RequestTooLarge")]
          [:u::FnCell::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::println "RequestMalformed")])]
      [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::println (:wat::kernel::LociDiedError/message x))]
      [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::println "Stopped")]
      [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::println "Closed")])))
