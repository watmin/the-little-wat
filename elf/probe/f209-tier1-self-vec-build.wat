;; F-209's build+match+drop variant: a tier-1 enum whose sole payload is a Vector of itself,
;; actually BUILT (a Node holding a one-element Vector of a Leaf), MATCHED (both arms), and
;; dropped at the end of `main`. `f209-tier1-self-vec.wat` only declares the type and never
;; constructs a value; this shows the fixed `:c::enum-tier` (tier decided from the payload's
;; KIND) also lets codegen for a real value through -- `:c::arm-ftys`/`:c::payload-ty` ask the
;; same question downstream of the tier and must not reopen the recursion.
(:wat::core::defenum :user::T :wat::enum::Pure
  :Leaf []
  :Node [kids <- (:wat::core::Vector :- [:user::T])])

(wat.core/defn user/count [t :- :user::T] :- wat.type/i64
  (:wat::core::match t
    [:user::T.Leaf {} 0]
    [:user::T.Node {:kids ks} (wat.core/length ks)]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/conj (wat.core/Vector :- [:user::T]) (:user::T.Leaf {}))
                 t (:user::T.Node {:kids v})]
    (wat.kernel/println (user/count t))))
