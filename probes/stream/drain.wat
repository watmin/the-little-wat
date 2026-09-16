;; probes/stream/drain.wat: the documented stream API and the real one are disjoint sets.
;;
;; Three findings meet here, and together they close a road a real user walks down:
;;
;;   F-080  :wat::core::filterv has no PersistentVector clause. The obvious fallback,
;;          :wat::core::filter, DOES take one -- and answers a :wat::stream::Stream.
;;   F-088  So you reach for the documented way to turn a Stream back into a vector.
;;          USER-GUIDE.md:3709 tabulates `:wat::stream::collect` with its signature.
;;          It does not exist. Neither do the other eight stream verbs the docs name.
;;   F-031  And `(:wat::core::length <a Stream>)` type-checks, then dies at runtime
;;          listing the six container types it actually accepts.
;;
;; The REAL API is four Rust intrinsics -- cons, empty, lazy, next -- and none of them is
;; mentioned in any user-facing page. `next` is a single-force pull returning
;; (NextOutcome :- [T]): :Item [value rest] or :Exhausted []. wat/stream.wat explains the design
;; well ("replaces the three-force empty?/first/rest walk protocol"); that file is not a document
;; a user reads.
;;
;; So this probe is also the recipe the documentation does not carry: :sd::drain below is the
;; collect that USER-GUIDE.md promises, in six lines.
;;
;; Expected: filtered 3 -> drained 3, values 1 3 5.
;;
;; Run: wat probes/stream/drain.wat

(:wat::core::typealias :sd::P (:wat::core::PersistentVector :- [:wat::core::i64]))
(:wat::core::typealias :sd::S (:wat::stream::Stream :- [:wat::core::i64]))

(:wat::core::defn :sd::odd? [x <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::= 1 (:wat::core::rem x 2)))

;; THE MISSING VERB. :wat::stream::collect is documented and absent; this is it.
(:wat::core::defn :sd::drain [s <- :sd::S acc <- :sd::P] -> :sd::P
  (:wat::core::match (:wat::stream::next s)
    [:wat::stream::NextOutcome.Item {:value v :rest r}
      (:sd::drain r (:wat::vector::conj acc v))]
    [:wat::stream::NextOutcome.Exhausted {} acc]))

(:wat::core::defn :sd::collect [s <- :sd::S] -> :sd::P
  (:sd::drain s (:wat::core::PersistentVector :- [:wat::core::i64])))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [src (:wat::core::PersistentVector :- [:wat::core::i64] 1 2 3 4 5)
     ;; filterv would be refused here (F-080); filter takes it and answers a Stream
     st  (:wat::core::filter :sd::odd? src)
     out (:sd::collect st)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "drained " (:wat::i64::to-string (:wat::core::length out)) " of " (:wat::i64::to-string (:wat::core::length src)))))
      (:wat::kernel::println (:wat::edn::write out))
      ;; The documented way, for the record -- all nine are unresolved:
      ;; (:wat::stream::collect st) (:wat::stream::map st f) (:wat::stream::take st 2)
      ;; (:wat::stream::chunks st 2) (:wat::stream::for-each st f) (:wat::stream::flat-map st f)
      ;; (:wat::stream::spawn-producer f) (:wat::stream::from-receiver r) (:wat::stream::with-state s f)
      nil)))
