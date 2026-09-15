;; probes/java/peer-messages-shared-type-twice.wat: can two Peer surfaces carry one datatype by
;; each declaring it? The second surface may not merely refer to a type the first declares
;; (probes/java/peer-messages-shared-type.wat), so here both declare PieD, identically.

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
  [(:wat::core::defenum :probe::PieD :wat::enum::Pure
     :Bot []
     :Top [t <- :wat::core::i64  r <- :probe::PieD])
   (:wat::core::defrecord :probe::PieOven::BakeRequest [value <- :probe::PieD])
   (:wat::core::defenum :probe::PieOven::BakeResponse :wat::enum::Pure
     :Ok               [value <- :probe::PieD]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(bake [self <- :probe::PieOven  req <- :probe::PieOven::BakeRequest] -> :probe::PieOven::BakeResponse :max-request-bytes 524288)])

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println "two Peer surfaces each declare one datatype"))
