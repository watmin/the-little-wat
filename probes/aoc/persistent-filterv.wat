;; probes/aoc/persistent-filterv.wat: which core sequence verbs accept a PersistentVector?
;;
;; F-057 is that the copying containers are quadratic and the sharing ones are linear, and that
;; nothing points a user at the sharing ones -- converting aoc/day05-paths.wat took it from
;; 135.1 s to 20.6 s. This asks the other half of that question: once you have taken the advice
;; and your data is a PersistentVector, does the core vocabulary still work on it?
;;
;; Eight of the nine verbs below do. `:wat::core::filterv` is the exception -- its only clauses
;; are (Vector :- [T]) and (Stream :- [T]), so it is refused at startup. That is F-080.
;;
;; It is not academic: every vector in :wat::grep::Facts -- nodes, named, spans, written,
;; unreadable -- is a PersistentVector, so the fact base wat's own code-search engine produces
;; cannot be filtered with the verb a user reaches for first.
;;
;; There is no fallback namespace either: :wat::vector:: holds exactly concat, conj, contains?.
;; `:wat::core::filter` does accept a PersistentVector, but answers a :wat::stream::Stream, so it
;; is not a drop-in -- and `(length <that Stream>)` type-checks and dies at runtime, which is
;; F-031's family a third time.
;;
;; To see the refusal, restore the commented line at the bottom.
;; Expected as written: nine numbers from the Vector controls, then eight from the persistent side.

(:wat::core::typealias :pv::V (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :pv::P (:wat::core::PersistentVector :- [:wat::core::i64]))

(:wat::core::defn :pv::v [] -> :pv::V (:wat::core::Vector :- [:wat::core::i64] 1 2 3))
(:wat::core::defn :pv::p [] -> :pv::P (:wat::core::PersistentVector :- [:wat::core::i64] 1 2 3))
(:wat::core::defn :pv::one? [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::= x 1))
(:wat::core::defn :pv::inc [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))
(:wat::core::defn :pv::add [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; --- Vector controls: all nine pass, so a refusal below is about the container ---
    (:wat::kernel::println (:wat::core::length  (:wat::core::mapv    :pv::inc  (:pv::v))))
    (:wat::kernel::println (:wat::core::length  (:wat::core::filterv :pv::one? (:pv::v))))
    (:wat::kernel::println (:wat::core::foldl   :pv::add 0 (:pv::v)))
    (:wat::kernel::println (:wat::core::length  (:pv::v)))
    (:wat::kernel::println (:wat::core::nth     (:pv::v) 0))
    (:wat::kernel::println (:wat::core::first   (:pv::v)))
    (:wat::kernel::println (:wat::core::length  (:wat::core::rest    (:pv::v))))
    (:wat::kernel::println (:wat::core::length  (:wat::core::reverse (:pv::v))))
    (:wat::kernel::println (:wat::core::length  (:wat::core::concat  (:pv::v) (:pv::v))))
    ;; --- the same verbs against a PersistentVector: eight of nine ---
    (:wat::kernel::println (:wat::core::length  (:wat::core::mapv    :pv::inc  (:pv::p))))
    (:wat::kernel::println (:wat::core::foldl   :pv::add 0 (:pv::p)))
    (:wat::kernel::println (:wat::core::length  (:pv::p)))
    (:wat::kernel::println (:wat::core::nth     (:pv::p) 0))
    (:wat::kernel::println (:wat::core::first   (:pv::p)))
    (:wat::kernel::println (:wat::core::length  (:wat::core::rest    (:pv::p))))
    (:wat::kernel::println (:wat::core::length  (:wat::core::reverse (:pv::p))))
    (:wat::kernel::println (:wat::core::length  (:wat::core::concat  (:pv::p) (:pv::p))))
    ;; F-080 -- uncomment to see the startup refusal:
    ;; (:wat::kernel::println (:wat::core::length (:wat::core::filterv :pv::one? (:pv::p))))
    ))
