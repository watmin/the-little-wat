;; mal/lib/types.wat: mal's values. No main; each step's program loads what it needs.
;;
;; Impure from the start: later steps add functions, which a Pure enum may not hold.
;; Keyword spelling throughout.

(:wat::core::defenum :mal::Val :wat::enum::Impure
  :Nil   []
  :True  []
  :False []
  :Int   [n <- :wat::core::i64]
  :Str   [s <- :wat::core::String]
  :Sym   [name <- :wat::core::String]
  :Kw    [name <- :wat::core::String]
  :List  [items <- (:wat::core::Vector :- [:mal::Val])]
  :Vec   [items <- (:wat::core::Vector :- [:mal::Val])]
  ;; keys and values alternate, in the order read
  :Map   [kvs <- (:wat::core::Vector :- [:mal::Val])])

(:wat::core::typealias :mal::Vals (:wat::core::Vector :- [:mal::Val]))
(:wat::core::typealias :mal::Strs (:wat::core::Vector :- [:wat::core::String]))

;; widened constructors: a bare variant keeps its narrowed type (F-019)
(:wat::core::defn :mal::nil [] -> :mal::Val (:mal::Val.Nil {}))
(:wat::core::defn :mal::true [] -> :mal::Val (:mal::Val.True {}))
(:wat::core::defn :mal::false [] -> :mal::Val (:mal::Val.False {}))
(:wat::core::defn :mal::int [n <- :wat::core::i64] -> :mal::Val (:mal::Val.Int {:n n}))
(:wat::core::defn :mal::str [s <- :wat::core::String] -> :mal::Val (:mal::Val.Str {:s s}))
(:wat::core::defn :mal::sym [name <- :wat::core::String] -> :mal::Val (:mal::Val.Sym {:name name}))
(:wat::core::defn :mal::kw [name <- :wat::core::String] -> :mal::Val (:mal::Val.Kw {:name name}))
(:wat::core::defn :mal::list [items <- :mal::Vals] -> :mal::Val (:mal::Val.List {:items items}))
(:wat::core::defn :mal::vec [items <- :mal::Vals] -> :mal::Val (:mal::Val.Vec {:items items}))
(:wat::core::defn :mal::map [kvs <- :mal::Vals] -> :mal::Val (:mal::Val.Map {:kvs kvs}))

(:wat::core::defn :mal::bool [b <- :wat::core::bool] -> :mal::Val
  (:wat::core::if b (:mal::true) (:mal::false)))

;; one character of a String, as a String (wat has no character access)
(:wat::core::defn :mal::char-at [s <- :wat::core::String i <- :wat::core::i64] -> :wat::core::String
  (:wat::string::subs s i (:wat::core::+ i 1)))
