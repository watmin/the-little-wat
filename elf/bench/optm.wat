;; An Option-shaped enum in a loop: construct, match, unwrap. TIER 1 -- the payload is a
;; pointer, so the value IS that pointer and nothing is allocated (C-205).
(:wat::core::defenum :user::A :wat::enum::Pure
  :Some [value <- :wat::core::String]
  :None [])
(wat.core/defn user/pick [s :- wat.type/String n :- wat.type/i64] :- :user::A
  (wat.core/if (wat.core/< n 0) (:user::A.None {}) (:user::A.Some {:value s})))
(wat.core/defn user/run [s :- wat.type/String i :- wat.type/i64 n :- wat.type/i64
                         acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/run s (wat.core/+ i 1) n
      (wat.core/+ acc (:wat::core::match (user/pick s i)
                        [:user::A.Some {:value v} (wat.string/length v)]
                        [:user::A.None {}         0])))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/run "abcd" 0 20000000 0)))
