;; probes/java/peer-messages-conflicting-type.wat: two Peer surfaces each declare :probe::PieD,
;; and the declarations differ. Two identical copies are accepted
;; (probes/java/peer-messages-shared-type-twice.wat); here the oven's PieD has a third variant.
;; Which PieD does the program get, and does anything say there are two?

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
     :Top [t <- :wat::core::i64  r <- :probe::PieD]
     :Burnt [])
   (:wat::core::defrecord :probe::PieOven::BakeRequest [value <- :probe::PieD])
   (:wat::core::defenum :probe::PieOven::BakeResponse :wat::enum::Pure
     :Ok               [value <- :probe::PieD]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(bake [self <- :probe::PieOven  req <- :probe::PieOven::BakeRequest] -> :probe::PieOven::BakeResponse :max-request-bytes 524288)])

;; exhaustive over the cell's PieD (two variants); the oven's has three
(:wat::core::defn :probe::show [p <- :probe::PieD] -> :wat::core::String
  (:wat::core::match p
    [:probe::PieD.Bot {} "(Bot)"]
    [:probe::PieD.Top {:t t :r r} (:wat::string::concat "(Top " (:wat::i64::to-string t) " " (:probe::show r) ")")]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:probe::show (:probe::PieD.Burnt {}))))
