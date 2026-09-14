;; service-fn-put.wat: the Y-bang shape. PUT a new function into a running service, then
;; GET it back and call it. The request record carries a function; both response enums are
;; Impure; thread locus. Expected if the route works: 8 (the replacement function)
(:wat::core::defsurface :u::FnBox :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :u::FnBox::GetRequest [])
   (:wat::core::defenum :u::FnBox::GetResponse :wat::enum::Impure
     :Ok               [value <- [:wat::WatAST :-> :wat::core::i64]]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :u::FnBox::PutRequest [f <- [:wat::WatAST :-> :wat::core::i64]])
   (:wat::core::defenum :u::FnBox::PutResponse :wat::enum::Impure
     :Ok               []
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get [self <- :u::FnBox  req <- :u::FnBox::GetRequest] -> :u::FnBox::GetResponse :max-request-bytes 524288)
   (put [self <- :u::FnBox  req <- :u::FnBox::PutRequest] -> :u::FnBox::PutResponse :max-request-bytes 524288)])
(:wat::service::defservice :u::fnbox
  :satisfies :u::FnBox
  :durable [f <- [:wat::WatAST :-> :wat::core::i64]]
  :ephemeral []
  :impls
  [(get [s ctx req]
     (:wat::service::Outcome.Reply {:state s
       :reply (:u::FnBox::GetResponse.Ok {:value (:u::fnbox::Record/f (:u::fnbox::State/durable s))})}))
   (put [s ctx req]
     (:wat::service::Outcome.Reply
       {:state (:u::fnbox::State :durable (:u::fnbox::Record :f (:u::FnBox::PutRequest/f req)))
        :reply (:u::FnBox::PutResponse.Ok {})}))])
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:u::fnbox/start :locus (:wat::spawn::thread)
         :record (:u::fnbox::Record :f (:wat::core::fn [l <- :wat::WatAST] -> :wat::core::i64 7)))
     c (:wat::core::match (:wat::kernel::connect (:u::fnbox::Handle/addr h))
         [:wat::kernel::ConnectOutcome.Connected {:peer p} p]
         [:wat::kernel::ConnectOutcome.Refused {:cause c} (:wat::kernel::assertion-failed! :message "refused")]
         [:wat::kernel::ConnectOutcome.Rejected {:cause c} (:wat::kernel::assertion-failed! :message "rejected")]
         [:wat::kernel::ConnectOutcome.Failed {:cause c} (:wat::kernel::assertion-failed! :message "failed")])
     _put (:wat::core::match (:u::FnBox/put c (:u::FnBox::PutRequest :f (:wat::core::fn [l <- :wat::WatAST] -> :wat::core::i64 8)))
            [:wat::kernel::RecvOutcome.Message {:msg _m} nil]
            [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::println (:wat::kernel::LociDiedError/message x))]
            [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::println "Stopped")]
            [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::println "Closed")])]
    (:wat::core::match (:u::FnBox/get c (:u::FnBox::GetRequest))
      [:wat::kernel::RecvOutcome.Message {:msg m}
        (:wat::core::match m
          [:u::FnBox::GetResponse.Ok {:value f} (:wat::kernel::println (f 'pear))]
          [:u::FnBox::GetResponse.RequestTooLarge {:bytes b :cap cp} (:wat::kernel::println "RequestTooLarge")]
          [:u::FnBox::GetResponse.RequestMalformed {:path mp :expected me :got mg} (:wat::kernel::println "RequestMalformed")])]
      [:wat::kernel::RecvOutcome.Lost {:cause x} (:wat::kernel::println (:wat::kernel::LociDiedError/message x))]
      [:wat::kernel::RecvOutcome.Stopped {} (:wat::kernel::println "Stopped")]
      [:wat::kernel::RecvOutcome.Closed {} (:wat::kernel::println "Closed")])))
