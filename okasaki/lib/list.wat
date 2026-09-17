;; okasaki/lib/list.wat — a cons list, because the book's bounds are stated over one.
;;
;; Using a PersistentVector here would measure wat's container instead of Okasaki's structure.
;; The amortization arguments in chapters 5-7 all assume cons is O(1), head/tail are O(1) and
;; reverse is O(n); a cons list is the only way to hold wat to that.
;;
;; It is also a test in its own right: if constructing a :Cons node copied its tail, cons would be
;; O(n) and every amortized bound in the book would collapse. ch05 measures whether it does.

(:wat::core::defenum :ok::List :wat::enum::Pure
  :Nil []
  :Cons [h <- :wat::core::i64  t <- :ok::List])

(:wat::core::defn :ok::nil [] -> :ok::List (:ok::List.Nil {}))
(:wat::core::defn :ok::cons [x <- :wat::core::i64 t <- :ok::List] -> :ok::List
  (:ok::List.Cons {:h x :t t}))

(:wat::core::defn :ok::null? [l <- :ok::List] -> :wat::core::bool
  (:wat::core::match l [:ok::List.Nil {} true] [:ok::List.Cons {:h h :t t} false]))

(:wat::core::defn :ok::len [l <- :ok::List] -> :wat::core::i64
  (:wat::core::match l
    [:ok::List.Nil {} 0]
    [:ok::List.Cons {:h h :t t} (:wat::core::+ 1 (:ok::len t))]))

(:wat::core::defn :ok::rev-onto [l <- :ok::List acc <- :ok::List] -> :ok::List
  (:wat::core::match l
    [:ok::List.Nil {} acc]
    [:ok::List.Cons {:h h :t t} (:ok::rev-onto t (:ok::cons h acc))]))

(:wat::core::defn :ok::rev [l <- :ok::List] -> :ok::List (:ok::rev-onto l (:ok::nil)))

;; append — O(length of a). Needed by the banker's queue's rotation.
(:wat::core::defn :ok::append [a <- :ok::List b <- :ok::List] -> :ok::List
  (:wat::core::match a
    [:ok::List.Nil {} b]
    [:ok::List.Cons {:h h :t t} (:ok::cons h (:ok::append t b))]))

(:wat::core::defn :ok::head-or [l <- :ok::List d <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match l [:ok::List.Nil {} d] [:ok::List.Cons {:h h :t t} h]))

(:wat::core::defn :ok::rest [l <- :ok::List] -> :ok::List
  (:wat::core::match l [:ok::List.Nil {} l] [:ok::List.Cons {:h h :t t} t]))
