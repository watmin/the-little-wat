;; mal/lib/types.wat: mal's values. No main; each step's program loads what it needs.
;;
;; A mal value is data, all the way down: a builtin is its name, dispatched by eval; a closure
;; will be its parameters, body and environment's id. So no wat function is ever inside one,
;; and mal's environments and atoms can live on a service, where wat keeps state (a function
;; can't be a service's state, R-002). Keyword spelling throughout.

(:wat::core::defenum :mal::Val :wat::enum::Impure
  :Nil     []
  :True    []
  :False   []
  :Int     [n <- :wat::core::i64]
  :Str     [s <- :wat::core::String]
  :Sym     [name <- :wat::core::String]
  :Kw      [name <- :wat::core::String]
  :List    [items <- (:wat::core::Vector :- [:mal::Val])]
  :Vec     [items <- (:wat::core::Vector :- [:mal::Val])]
  ;; keys and values alternate, in the order read
  :Map     [kvs <- (:wat::core::Vector :- [:mal::Val])]
  :Builtin [name <- :wat::core::String])

(:wat::core::typealias :mal::Vals (:wat::core::Vector :- [:mal::Val]))
(:wat::core::typealias :mal::Strs (:wat::core::Vector :- [:wat::core::String]))

;; an evaluation: a value, or a thrown mal value
(:wat::core::defenum :mal::Res :wat::enum::Impure
  :Ok  [v <- :mal::Val]
  :Err [e <- :mal::Val])

;; the same, for a sequence of values
(:wat::core::defenum :mal::Many :wat::enum::Impure
  :Ok  [vs <- (:wat::core::Vector :- [:mal::Val])]
  :Err [e <- :mal::Val])

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

(:wat::core::defn :mal::builtin [name <- :wat::core::String] -> :mal::Val (:mal::Val.Builtin {:name name}))

(:wat::core::defn :mal::bool [b <- :wat::core::bool] -> :mal::Val
  (:wat::core::if b (:mal::true) (:mal::false)))

(:wat::core::defn :mal::ok [v <- :mal::Val] -> :mal::Res (:mal::Res.Ok {:v v}))
(:wat::core::defn :mal::err [e <- :mal::Val] -> :mal::Res (:mal::Res.Err {:e e}))
(:wat::core::defn :mal::fail [msg <- :wat::core::String] -> :mal::Res (:mal::err (:mal::str msg)))
(:wat::core::defn :mal::many [vs <- :mal::Vals] -> :mal::Many (:mal::Many.Ok {:vs vs}))
(:wat::core::defn :mal::many-err [e <- :mal::Val] -> :mal::Many (:mal::Many.Err {:e e}))

;; ---- reading a value's parts. Every match names every variant, so each of these is written
;; once, here, with all of them.

(:wat::core::defn :mal::int-of [v <- :mal::Val] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match v
    [:mal::Val.Int {:n n} (:wat::core::Option.Some {:value n})]
    [:mal::Val.Nil {} (:wat::core::Option.None {})]
    [:mal::Val.True {} (:wat::core::Option.None {})]
    [:mal::Val.False {} (:wat::core::Option.None {})]
    [:mal::Val.Str {:s s} (:wat::core::Option.None {})]
    [:mal::Val.Sym {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Kw {:name x} (:wat::core::Option.None {})]
    [:mal::Val.List {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Vec {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Map {:kvs x} (:wat::core::Option.None {})]
    [:mal::Val.Builtin {:name x} (:wat::core::Option.None {})]))

(:wat::core::defn :mal::builtin-of [v <- :mal::Val] -> (:wat::core::Option :- [:wat::core::String])
  (:wat::core::match v
    [:mal::Val.Builtin {:name x} (:wat::core::Option.Some {:value x})]
    [:mal::Val.Nil {} (:wat::core::Option.None {})]
    [:mal::Val.True {} (:wat::core::Option.None {})]
    [:mal::Val.False {} (:wat::core::Option.None {})]
    [:mal::Val.Int {:n n} (:wat::core::Option.None {})]
    [:mal::Val.Str {:s s} (:wat::core::Option.None {})]
    [:mal::Val.Sym {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Kw {:name x} (:wat::core::Option.None {})]
    [:mal::Val.List {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Vec {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Map {:kvs x} (:wat::core::Option.None {})]))

;; one character of a String, as a String (wat has no character access)
(:wat::core::defn :mal::char-at [s <- :wat::core::String i <- :wat::core::i64] -> :wat::core::String
  (:wat::string::subs s i (:wat::core::+ i 1)))
