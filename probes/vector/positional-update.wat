;; probes/vector/positional-update.wat: can an element of a vector be replaced by index?
;;
;; No -- on either vector type, and the obvious workaround is closed off too. This is the shape an
;; array-like mutable store needs (EOPL chapter 4's store is exactly `setref(i, v)`), so it is not
;; an exotic want.
;;
;; MEASURED 2026-09-16 (wat-rs a3218644d):
;;
;;   (:wat::core::assoc pv 1 99)      REFUSED -- "expects (HashMap :- [K V]) or :wat::core::Record"
;;   (:wat::core::assoc vec 1 99)     REFUSED -- same
;;   :wat::vector::assoc              does not exist
;;   :wat::core::update               does not exist
;;   :wat::core::assoc-n              does not exist
;;
;; So `core::assoc` covers HashMap and Record; `map::assoc` covers PersistentMap; NEITHER vector
;; type has a positional update at all.
;;
;; And the hand-rolled route -- take i, append the new element, drop (i+1) -- does not close:
;; `take`/`drop` on a PersistentVector answer a :wat::stream::Stream, and `vector::concat` wants a
;; PersistentVector, so the pieces do not fit back together. Getting from a Stream to a vector
;; needs `:wat::stream::collect`, which F-088 measured as documented-but-absent.
;;
;; The working route is the one below: a PersistentMap keyed by index. That is the same workaround
;; F-057 records for the missing persistent SET -- wat's sharing story is map-shaped, and the
;; persistent vector is append-only.
;;
;; Expected: the map route prints 10 99 30; the vector routes are in comments because they do not
;; compile.

(:wat::core::typealias :pu::PM (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

(:wat::core::defn :pu::at [m <- :pu::PM i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::map::get m i)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} -1]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [m0 (:wat::map::assoc (:wat::map::assoc (:wat::map::assoc
          (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) 0 10) 1 20) 2 30)
     m1 (:wat::map::assoc m0 1 99)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::join " " (:wat::core::Vector :- [:wat::core::String]
        (:wat::i64::to-string (:pu::at m1 0))
        (:wat::i64::to-string (:pu::at m1 1))
        (:wat::i64::to-string (:pu::at m1 2)))))
      ;; none of these compile:
      ;; (:wat::core::assoc  (:wat::core::PersistentVector :- [:wat::core::i64] 10 20 30) 1 99)
      ;; (:wat::vector::assoc ...)   (:wat::core::update ...)   (:wat::core::assoc-n ...)
      ;; and take/drop answer a Stream, which vector::concat will not take back (F-088)
      nil)))
