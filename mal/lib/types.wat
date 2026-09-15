;; mal/lib/types.wat: mal's values. No main; each step's program loads what it needs.
;;
;; A mal value is data, all the way down: a builtin is its name, dispatched by eval; a closure
;; is its parameters, its body and its environment's id; an atom is its id. So no wat function
;; is ever inside one, and mal's environments and atoms can live on a service, where wat keeps
;; state (a function can't be a service's state, R-002). Keyword spelling throughout.

;; The values are declared inside the protocol of the store service (lib/env.wat), which holds
;; mal's environments and atoms: a Peer surface must declare every type its messages carry
;; (Friction, A Little Java ch 10), and the store's messages carry values. So this file is the
;; store's protocol too; steps that start no store just never use it.
(:wat::core::defsurface :mal::Store :nature :wat::kernel::Peer
  :messages
  [(:wat::core::defenum :mal::Val :wat::enum::Pure
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
     :Builtin [name <- :wat::core::String]
     :Closure [params <- (:wat::core::Vector :- [:mal::Val])  body <- :mal::Val  env <- :wat::core::i64]
     :Atom    [id <- :wat::core::i64])
   (:wat::core::defrecord :mal::Store::NewEnvRequest [outer <- :wat::core::i64])
   (:wat::core::defenum :mal::Store::NewEnvResponse :wat::enum::Pure
     :Ok               [id <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :mal::Store::GetRequest [env <- :wat::core::i64  name <- :wat::core::String])
   (:wat::core::defenum :mal::Store::GetResponse :wat::enum::Pure
     :Ok               [found <- (:wat::core::Option :- [:mal::Val])]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :mal::Store::SetRequest [env <- :wat::core::i64  name <- :wat::core::String  value <- :mal::Val])
   (:wat::core::defenum :mal::Store::SetResponse :wat::enum::Pure
     :Ok               [value <- :mal::Val]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :mal::Store::NewAtomRequest [value <- :mal::Val])
   (:wat::core::defenum :mal::Store::NewAtomResponse :wat::enum::Pure
     :Ok               [id <- :wat::core::i64]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :mal::Store::DerefRequest [id <- :wat::core::i64])
   (:wat::core::defenum :mal::Store::DerefResponse :wat::enum::Pure
     :Ok               [value <- :mal::Val]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])
   (:wat::core::defrecord :mal::Store::ResetRequest [id <- :wat::core::i64  value <- :mal::Val])
   (:wat::core::defenum :mal::Store::ResetResponse :wat::enum::Pure
     :Ok               [value <- :mal::Val]
     :RequestTooLarge  [bytes <- :wat::core::i64  cap <- :wat::core::i64]
     :RequestMalformed [path <- (:wat::core::Vector :- [:wat::core::String])  expected <- :wat::core::String  got <- :wat::core::String])]
  :features
  [(new-env  [self <- :mal::Store  req <- :mal::Store::NewEnvRequest]  -> :mal::Store::NewEnvResponse  :max-request-bytes 524288)
   (get      [self <- :mal::Store  req <- :mal::Store::GetRequest]     -> :mal::Store::GetResponse     :max-request-bytes 524288)
   (set      [self <- :mal::Store  req <- :mal::Store::SetRequest]     -> :mal::Store::SetResponse     :max-request-bytes 524288)
   (new-atom [self <- :mal::Store  req <- :mal::Store::NewAtomRequest] -> :mal::Store::NewAtomResponse :max-request-bytes 524288)
   (deref    [self <- :mal::Store  req <- :mal::Store::DerefRequest]   -> :mal::Store::DerefResponse   :max-request-bytes 524288)
   (reset    [self <- :mal::Store  req <- :mal::Store::ResetRequest]   -> :mal::Store::ResetResponse   :max-request-bytes 524288)])

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
(:wat::core::defn :mal::closure [params <- :mal::Vals body <- :mal::Val env <- :wat::core::i64] -> :mal::Val
  (:mal::Val.Closure {:params params :body body :env env}))
(:wat::core::defn :mal::atom-ref [id <- :wat::core::i64] -> :mal::Val (:mal::Val.Atom {:id id}))

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
    [:mal::Val.Builtin {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Closure {:params p :body b :env e} (:wat::core::Option.None {})]
    [:mal::Val.Atom {:id i} (:wat::core::Option.None {})]))

(:wat::core::defn :mal::str-of [v <- :mal::Val] -> (:wat::core::Option :- [:wat::core::String])
  (:wat::core::match v
    [:mal::Val.Str {:s s} (:wat::core::Option.Some {:value s})]
    [:mal::Val.Nil {} (:wat::core::Option.None {})]
    [:mal::Val.True {} (:wat::core::Option.None {})]
    [:mal::Val.False {} (:wat::core::Option.None {})]
    [:mal::Val.Int {:n n} (:wat::core::Option.None {})]
    [:mal::Val.Sym {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Kw {:name x} (:wat::core::Option.None {})]
    [:mal::Val.List {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Vec {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Map {:kvs x} (:wat::core::Option.None {})]
    [:mal::Val.Builtin {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Closure {:params p :body b :env e} (:wat::core::Option.None {})]
    [:mal::Val.Atom {:id i} (:wat::core::Option.None {})]))

(:wat::core::defn :mal::sym-of [v <- :mal::Val] -> (:wat::core::Option :- [:wat::core::String])
  (:wat::core::match v
    [:mal::Val.Sym {:name x} (:wat::core::Option.Some {:value x})]
    [:mal::Val.Nil {} (:wat::core::Option.None {})]
    [:mal::Val.True {} (:wat::core::Option.None {})]
    [:mal::Val.False {} (:wat::core::Option.None {})]
    [:mal::Val.Int {:n n} (:wat::core::Option.None {})]
    [:mal::Val.Str {:s s} (:wat::core::Option.None {})]
    [:mal::Val.Kw {:name x} (:wat::core::Option.None {})]
    [:mal::Val.List {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Vec {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Map {:kvs x} (:wat::core::Option.None {})]
    [:mal::Val.Builtin {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Closure {:params p :body b :env e} (:wat::core::Option.None {})]
    [:mal::Val.Atom {:id i} (:wat::core::Option.None {})]))

;; a list's or a vector's elements
(:wat::core::defn :mal::seq-of [v <- :mal::Val] -> (:wat::core::Option :- [:mal::Vals])
  (:wat::core::match v
    [:mal::Val.List {:items xs} (:wat::core::Option.Some {:value xs})]
    [:mal::Val.Vec {:items xs} (:wat::core::Option.Some {:value xs})]
    [:mal::Val.Nil {} (:wat::core::Option.None {})]
    [:mal::Val.True {} (:wat::core::Option.None {})]
    [:mal::Val.False {} (:wat::core::Option.None {})]
    [:mal::Val.Int {:n n} (:wat::core::Option.None {})]
    [:mal::Val.Str {:s s} (:wat::core::Option.None {})]
    [:mal::Val.Sym {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Kw {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Map {:kvs x} (:wat::core::Option.None {})]
    [:mal::Val.Builtin {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Closure {:params p :body b :env e} (:wat::core::Option.None {})]
    [:mal::Val.Atom {:id i} (:wat::core::Option.None {})]))

;; a list's elements (not a vector's)
(:wat::core::defn :mal::list-of [v <- :mal::Val] -> (:wat::core::Option :- [:mal::Vals])
  (:wat::core::match v
    [:mal::Val.List {:items xs} (:wat::core::Option.Some {:value xs})]
    [:mal::Val.Vec {:items xs} (:wat::core::Option.None {})]
    [:mal::Val.Nil {} (:wat::core::Option.None {})]
    [:mal::Val.True {} (:wat::core::Option.None {})]
    [:mal::Val.False {} (:wat::core::Option.None {})]
    [:mal::Val.Int {:n n} (:wat::core::Option.None {})]
    [:mal::Val.Str {:s s} (:wat::core::Option.None {})]
    [:mal::Val.Sym {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Kw {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Map {:kvs x} (:wat::core::Option.None {})]
    [:mal::Val.Builtin {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Closure {:params p :body b :env e} (:wat::core::Option.None {})]
    [:mal::Val.Atom {:id i} (:wat::core::Option.None {})]))

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
    [:mal::Val.Map {:kvs x} (:wat::core::Option.None {})]
    [:mal::Val.Closure {:params p :body b :env e} (:wat::core::Option.None {})]
    [:mal::Val.Atom {:id i} (:wat::core::Option.None {})]))

(:wat::core::defn :mal::atom-of [v <- :mal::Val] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match v
    [:mal::Val.Atom {:id i} (:wat::core::Option.Some {:value i})]
    [:mal::Val.Nil {} (:wat::core::Option.None {})]
    [:mal::Val.True {} (:wat::core::Option.None {})]
    [:mal::Val.False {} (:wat::core::Option.None {})]
    [:mal::Val.Int {:n n} (:wat::core::Option.None {})]
    [:mal::Val.Str {:s s} (:wat::core::Option.None {})]
    [:mal::Val.Sym {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Kw {:name x} (:wat::core::Option.None {})]
    [:mal::Val.List {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Vec {:items x} (:wat::core::Option.None {})]
    [:mal::Val.Map {:kvs x} (:wat::core::Option.None {})]
    [:mal::Val.Builtin {:name x} (:wat::core::Option.None {})]
    [:mal::Val.Closure {:params p :body b :env e} (:wat::core::Option.None {})]))

;; a value's variant, as a keyword: written once with every variant, so a test of a value's kind
;; elsewhere is a comparison, not another match of every variant
(:wat::core::defn :mal::kind-of [v <- :mal::Val] -> :wat::core::keyword
  (:wat::core::match v
    [:mal::Val.Nil {} :nil]
    [:mal::Val.True {} :true]
    [:mal::Val.False {} :false]
    [:mal::Val.Int {:n n} :int]
    [:mal::Val.Str {:s s} :str]
    [:mal::Val.Sym {:name x} :sym]
    [:mal::Val.Kw {:name x} :kw]
    [:mal::Val.List {:items x} :list]
    [:mal::Val.Vec {:items x} :vec]
    [:mal::Val.Map {:kvs x} :map]
    [:mal::Val.Builtin {:name x} :builtin]
    [:mal::Val.Closure {:params p :body b :env e} :closure]
    [:mal::Val.Atom {:id i} :atom]))

;; is v the symbol name?
(:wat::core::defn :mal::sym-is? [v <- :mal::Val name <- :wat::core::String] -> :wat::core::bool
  (:wat::core::match (:mal::sym-of v)
    [:wat::core::Option.Some {:value x} (:wat::core::= x name)]
    [:wat::core::Option.None {} false]))

;; nil and false are false; everything else is true
(:wat::core::defn :mal::falsy? [v <- :mal::Val] -> :wat::core::bool
  (:wat::core::match v
    [:mal::Val.Nil {} true]
    [:mal::Val.False {} true]
    [:mal::Val.True {} false]
    [:mal::Val.Int {:n n} false]
    [:mal::Val.Str {:s s} false]
    [:mal::Val.Sym {:name x} false]
    [:mal::Val.Kw {:name x} false]
    [:mal::Val.List {:items x} false]
    [:mal::Val.Vec {:items x} false]
    [:mal::Val.Map {:kvs x} false]
    [:mal::Val.Builtin {:name x} false]
    [:mal::Val.Closure {:params p :body b :env e} false]
    [:mal::Val.Atom {:id i} false]))

;; one character of a String, as a String (wat has no character access)
(:wat::core::defn :mal::char-at [s <- :wat::core::String i <- :wat::core::i64] -> :wat::core::String
  (:wat::string::subs s i (:wat::core::+ i 1)))
