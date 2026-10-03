;; excursus 008 3b-3: a type recursive THROUGH A VECTOR (a node holds a Vector of nodes),
;; built 100,000 deep as a one-child chain, summed and dropped, twenty times. Its cycle is
;; {henum T, vec:T}; dropping it whole must walk in a loop with a flat stack.
(:wat::core::defenum :user::T :wat::enum::Pure
  :Leaf []
  :Node [k <- :wat::core::i64 kids <- (:wat::core::Vector :- [:user::T])])

(wat.core/defn user/build [i :- wat.type/i64 n :- wat.type/i64 acc :- :user::T] :- :user::T
  (wat.core/if (wat.core/= i n) acc
    (user/build (wat.core/+ i 1) n
      (:user::T.Node {:k i :kids (wat.core/conj (:wat::core::Vector :- [:user::T]) acc)}))))

(wat.core/defn user/sum [t :- :user::T acc :- wat.type/i64] :- wat.type/i64
  (:wat::core::match t
    [:user::T.Leaf {} acc]
    [:user::T.Node {:k k :kids kids} (user/sum (wat.core/nth kids 0) (wat.core/+ acc k))]))

(wat.core/defn user/rounds [r :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= r 0) acc
    (user/rounds (wat.core/- r 1)
      (wat.core/+ acc (user/sum (user/build 0 100000 (:user::T.Leaf {})) 0)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (user/rounds 20 0))))
