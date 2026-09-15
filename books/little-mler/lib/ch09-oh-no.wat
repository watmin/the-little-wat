;; The Little MLer, chapter 9 (Oh No!): exceptions. Our own code.
;;
;; wat has no exceptions; a function that can raise returns a Result, `raise` is returning an
;; Err, `handle` is matching on the Result, and Result/try propagates an Err past every
;; pending computation, as a raise does (C-006). Each exception is its own enum, so the
;; exceptions a function can raise are part of its type (ML's exn is one open type), and a
;; handler's match names exactly the ones that can arrive, with no catch-all.

;; datatype box = Bacon | Ix of int
(:wat::core::defenum :ml::Box :wat::enum::Pure :Bacon [] :Ix [i <- :wat::core::i64])
(:wat::core::defenum :ml::Boxes :wat::enum::Pure :Empty [] :Cons [b <- :ml::Box  t <- :ml::Boxes])

;; exception No_bacon of int;  exception Out_of_range
(:wat::core::defenum :ml::NoBacon :wat::enum::Pure :NoBacon [n <- :wat::core::i64])
(:wat::core::defenum :ml::OutOfRange :wat::enum::Pure :OutOfRange [])

(wat.core/defn ml/bacon [] :- :ml::Box (:ml::Box.Bacon {}))
(wat.core/defn ml/ix [i :- wat.type/i64] :- :ml::Box (:ml::Box.Ix {:i i}))
(wat.core/defn ml/no-bacon [n :- wat.type/i64] :- :ml::NoBacon (:ml::NoBacon.NoBacon {:n n}))
(wat.core/defn ml/out-of-range [] :- :ml::OutOfRange (:ml::OutOfRange.OutOfRange {}))

(wat.core/defn ml/boxes [xs :- (wat.type/Vector :- [:ml::Box])] :- :ml::Boxes
  (wat.core/if (wat.core/empty? xs)
    (:ml::Boxes.Empty {})
    (:ml::Boxes.Cons {:b (wat.core/first xs) :t (ml/boxes (wat.core/rest xs))})))

(wat.core/defn ml/is-bacon [b :- :ml::Box] :- wat.type/bool
  (:wat::core::match b
    [:ml::Box.Bacon {} true]
    [:ml::Box.Ix {:i _i} false]))

;; where_is: the position of the first Bacon. With none, it raises No_bacon(0), and every
;; pending (1 + ...) is abandoned.
(wat.core/defn ml/where-is [bs :- :ml::Boxes] :- (wat.type/Result :- [wat.type/i64 :ml::NoBacon])
  (:wat::core::match bs
    [:ml::Boxes.Empty {} (:wat::core::Result.Err {:error (ml/no-bacon 0)})]
    [:ml::Boxes.Cons {:b b :t t}
      (wat.core/if (ml/is-bacon b)
        (:wat::core::Result.Ok {:value 1})
        (:wat::core::Result.Ok {:value (wat.core/+ 1 (:wat::core::Result/try (ml/where-is t)))}))]))

;; where_is(...) handle No_bacon(an_int) => an_int
(wat.core/defn ml/where-is-handled [bs :- :ml::Boxes] :- wat.type/i64
  (:wat::core::match (ml/where-is bs)
    [:wat::core::Result.Ok {:value v} v]
    [:wat::core::Result.Err {:error e}
      (:wat::core::match e [:ml::NoBacon.NoBacon {:n n} n])]))

;; list_item: the n-th box, counting from 1, or raise Out_of_range.
(wat.core/defn ml/list-item [n :- wat.type/i64 bs :- :ml::Boxes] :- (wat.type/Result :- [:ml::Box :ml::OutOfRange])
  (:wat::core::match bs
    [:ml::Boxes.Empty {} (:wat::core::Result.Err {:error (ml/out-of-range)})]
    [:ml::Boxes.Cons {:b b :t t}
      (wat.core/if (wat.core/= n 1)
        (:wat::core::Result.Ok {:value b})
        (ml/list-item (wat.core/- n 1) t))]))

;; find: follow the boxes from position n, each Ix pointing at another position, until
;; Bacon; a position out of range is retried at half of it.
(wat.core/defn ml/find [n :- wat.type/i64 bs :- :ml::Boxes] :- wat.type/i64
  (:wat::core::match (ml/list-item n bs)
    [:wat::core::Result.Ok {:value b} (ml/check n bs b)]
    [:wat::core::Result.Err {:error e}
      (:wat::core::match e [:ml::OutOfRange.OutOfRange {} (ml/find (:wat::core::/ n 2) bs)])]))

(wat.core/defn ml/check [n :- wat.type/i64 bs :- :ml::Boxes b :- :ml::Box] :- wat.type/i64
  (:wat::core::match b
    [:ml::Box.Bacon {} n]
    [:ml::Box.Ix {:i i} (ml/find i bs)]))

;; path: the positions find visits, in order.
(wat.core/defn ml/path [n :- wat.type/i64 bs :- :ml::Boxes] :- (wat.type/Vector :- [wat.type/i64])
  (wat.core/concat [n]
    (:wat::core::match (ml/list-item n bs)
      [:wat::core::Result.Ok {:value b} (ml/path-check bs b)]
      [:wat::core::Result.Err {:error e}
        (:wat::core::match e [:ml::OutOfRange.OutOfRange {} (ml/path (:wat::core::/ n 2) bs)])])))

(wat.core/defn ml/path-check [bs :- :ml::Boxes b :- :ml::Box] :- (wat.type/Vector :- [wat.type/i64])
  (:wat::core::match b
    [:ml::Box.Bacon {} []]
    [:ml::Box.Ix {:i i} (ml/path i bs)]))
