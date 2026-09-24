;; STONE 0b's other half: the guards that must SURVIVE. Stone 0b emits `incq [rax-8]` bare for a
;; type that can be neither a read-only literal nor a small-integer tag. This reads, out of
;; containers, every value that CAN be one of those, and hands each on to a site that touches it:
;;
;;   * a String LITERAL (count 0, read-only page) out of a Vector, a record field and a tier-1
;;     enum's payload, each then passed to an in-place `concat` -- `str` keeps its literal guard,
;;     and a `penum:` whose payload is a String keeps it too, because its value IS the payload;
;;   * a UNIT variant (a small integer) of a tier-1 enum over a Vector and of a tier-3 enum,
;;     read out of a Vector -- both keep the tag guard, and a tier-1 over a Vector drops only
;;     the literal one.
;;
;; A dropped literal guard faults on a write to the data tail; a dropped tag guard faults on a
;; read at a negative address. Run both ways; they must agree.
(:wat::core::typealias :user::Strs (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defrecord :user::Tag [name <- :wat::core::String])
(:wat::core::typealias :user::Tags (:wat::core::Vector :- [:user::Tag]))
(:wat::core::defenum :user::S :wat::enum::Pure
  :None []
  :Some [s <- :wat::core::String])
(:wat::core::typealias :user::Ss (:wat::core::Vector :- [:user::S]))
(:wat::core::defenum :user::O :wat::enum::Pure
  :No  []
  :Yes [xs <- :user::Row])
(:wat::core::typealias :user::Os (:wat::core::Vector :- [:user::O]))
(:wat::core::defenum :user::H :wat::enum::Pure
  :Nil []
  :One [a <- :wat::core::i64]
  :Two [a <- :wat::core::i64 b <- :wat::core::i64])
(:wat::core::typealias :user::Hs (:wat::core::Vector :- [:user::H]))

;; the in-place `concat`: `s` is linear here, so `str_cat_own` is asked whether it owns it
(wat.core/defn user/bang [s :- wat.type/String] :- wat.type/i64
  (wat.string/length (wat.string/concat s "!")))

;; door 2's shape: the payload binding shadows the linear parameter `s`
(wat.core/defn user/some-bang [s :- wat.type/String o :- :user::S] :- wat.type/i64
  (:wat::core::match o
    [:user::S.None {} 0]
    [:user::S.Some {:s s} (wat.string/length (wat.string/concat s "?"))]))

(wat.core/defn user/olen [o :- :user::O] :- wat.type/i64
  (:wat::core::match o [:user::O.No {} -1] [:user::O.Yes {:xs xs} (wat.core/length xs)]))

(wat.core/defn user/hsum [h :- :user::H] :- wat.type/i64
  (:wat::core::match h
    [:user::H.Nil {} 0]
    [:user::H.One {:a a} a]
    [:user::H.Two {:a a :b b} (wat.core/+ a b)]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [g  (wat.core/Vector :- [wat.type/String] "ab" "cde")
                 ts (wat.core/Vector :- [:user::Tag] (:user::Tag :name "lit"))
                 ss (wat.core/Vector :- [:user::S] (:user::S.Some {:s "xy"}) (:user::S.None {}))
                 os (wat.core/Vector :- [:user::O] (:user::O.No {})
                                                   (:user::O.Yes {:xs (wat.core/Vector :- [wat.type/i64] 1 2)}))
                 hs (wat.core/Vector :- [:user::H] (:user::H.Nil {}) (:user::H.Two {:a 3 :b 4}))
                 s0 (wat.core/nth g 0)
                 o0 (wat.core/nth os 0)
                 h0 (wat.core/nth hs 0)]
    (wat.kernel/println (user/bang (wat.core/nth g 1)))                  ;; 4   str literal, door 1
    (wat.kernel/println (user/bang s0))                                  ;; 3   str literal, bound first
    (wat.kernel/println (wat.core/nth g 1))                              ;; "cde" untouched
    (wat.kernel/println (user/bang (:user::Tag/name (wat.core/nth ts 0)))) ;; 4 str literal in a field
    (wat.kernel/println (user/some-bang "q" (wat.core/nth ss 0)))        ;; 3   penum:S;str, a literal payload
    (wat.kernel/println (user/some-bang "q" (wat.core/nth ss 1)))        ;; 0   penum:S;str, the unit
    (wat.kernel/println (user/olen o0))                                  ;; -1  penum:O over a Vector, the unit
    (wat.kernel/println (user/olen (wat.core/nth os 1)))                 ;; 2
    (wat.kernel/println (user/hsum h0))                                  ;; 0   henum:H, the unit
    (wat.kernel/println (user/hsum (wat.core/nth hs 1)))                 ;; 7
    (wat.kernel/println (wat.string/length (wat.core/nth g 0)))))          ;; 2   "ab" untouched
