;; probes/java/peer-messages-outside-type.wat: may a Peer surface's messages carry a type
;; declared at top level? A Little Java ch 10 keeps a pie on a service; the pie datatype is the
;; program's own, declared before the service is. Here the surface's messages reach it.

(:wat::core::defenum :probe::PieD :wat::enum::Pure
  :Bot []
  :Top [t <- :wat::core::i64  r <- :probe::PieD])

(:wat::core::defsurface :probe::PieCell :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :probe::PieCell::GetRequest [])
   (:wat::core::defenum :probe::PieCell::GetResponse :wat::enum::Pure
     :Ok               [value <- :probe::PieD]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get [self <- :probe::PieCell  req <- :probe::PieCell::GetRequest] -> :probe::PieCell::GetResponse :max-request-bytes 524288)])

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println "a Peer surface's messages carry a top-level type"))
