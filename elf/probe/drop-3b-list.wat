;; excursus 008 stone 3b: a 100,000-deep list, built, summed and dropped, twenty times.
;; Before 3b each list leaks (peak RSS grows with the rounds); after it, each drops whole,
;; iteratively (the stack stays flat), and frees back to the bump.
(:wat::core::defenum :user::L :wat::enum::Pure
  :Nil  []
  :Cons [k <- :wat::core::i64 nxt <- :user::L])

(wat.core/defn user/build [i :- wat.type/i64 n :- wat.type/i64 acc :- :user::L] :- :user::L
  (wat.core/if (wat.core/= i n) acc
    (user/build (wat.core/+ i 1) n (:user::L.Cons {:k i :nxt acc}))))

(wat.core/defn user/sum [l :- :user::L acc :- wat.type/i64] :- wat.type/i64
  (:wat::core::match l
    [:user::L.Nil {} acc]
    [:user::L.Cons {:k k :nxt nxt} (user/sum nxt (wat.core/+ acc k))]))

(wat.core/defn user/rounds [r :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= r 0) acc
    (user/rounds (wat.core/- r 1)
      (wat.core/+ acc (user/sum (user/build 0 100000 (:user::L.Nil {})) 0)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (user/rounds 20 0))))
