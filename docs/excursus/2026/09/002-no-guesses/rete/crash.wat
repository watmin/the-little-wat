;; a tier-1 enum over a String, built by a constructor around a LITERAL and bound by `let`.
;; `:c::type-of-form` types the binding `henum:`, so its share gets the tag guard and not the
;; literal guard -- and the payload is a read-only literal.
(:wat::core::defenum :user::S :wat::enum::Pure
  :None []
  :Some [s <- :wat::core::String])

(wat.core/defn user/slen [o :- :user::S] :- wat.type/i64
  (:wat::core::match o [:user::S.None {} 0] [:user::S.Some {:s s} (wat.string/length s)]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [o (:user::S.Some {:s "xy"})
                 k (user/slen o)]
    (wat.kernel/println k)))               ;; 2
