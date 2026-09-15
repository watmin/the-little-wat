;; probes/java/peer-messages-shared-type.wat: can two Peer surfaces carry one datatype?
;; A Peer surface that owns :messages must declare every type its messages reach
;; (probes/java/peer-messages-outside-type.wat). Here PieD is declared inside the first
;; surface's messages, and the second surface, a different service over the same pies, only
;; refers to it.

(:wat::core::defsurface :probe::PieCell :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defenum :probe::PieD :wat::enum::Pure
     :Bot []
     :Top [t <- :wat::core::i64  r <- :probe::PieD])
   (:wat::core::defrecord :probe::PieCell::GetRequest [])
   (:wat::core::defenum :probe::PieCell::GetResponse :wat::enum::Pure
     :Ok               [value <- :probe::PieD]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(get [self <- :probe::PieCell  req <- :probe::PieCell::GetRequest] -> :probe::PieCell::GetResponse :max-request-bytes 524288)])

(:wat::core::defsurface :probe::PieOven :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defrecord :probe::PieOven::BakeRequest [value <- :probe::PieD])
   (:wat::core::defenum :probe::PieOven::BakeResponse :wat::enum::Pure
     :Ok               [value <- :probe::PieD]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(bake [self <- :probe::PieOven  req <- :probe::PieOven::BakeRequest] -> :probe::PieOven::BakeResponse :max-request-bytes 524288)])

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println "two Peer surfaces carry one datatype"))
