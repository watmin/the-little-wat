;; mal/lib/core.wat: mal's builtin functions, each dispatched by its name. Needs lib/types.wat
;; and lib/printer.wat. No main. Keyword spelling throughout.
;;
;; The builtins here need nothing but their arguments. Those that call back into mal (apply,
;; map, swap!) or touch the store are in the step programs that have them.

(:wat::core::defn :mal::core-names [] -> :mal::Strs
  ["+" "-" "*" "/" "<" "<=" ">" ">=" "=" "list" "list?" "empty?" "count" "not" "pr-str" "str" "prn" "println"
   "cons" "concat" "vec" "nth" "first" "rest" "macro?"
   "nil?" "true?" "false?" "symbol?" "symbol" "keyword" "keyword?" "vector" "vector?" "sequential?"
   "hash-map" "map?" "assoc" "dissoc" "get" "contains?" "keys" "vals"])

;; ---- hash-maps: keys and values alternate in a Vector, in the order they were added

;; the index of key k, or -1
(:wat::core::defn :mal::kv-index [kvs <- :mal::Vals k <- :mal::Val i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= (:wat::core::+ i 1) (:wat::core::length kvs))
    -1
    (:wat::core::if (:mal::equal? (:wat::core::nth kvs i) k) i (:mal::kv-index kvs k (:wat::core::+ i 2)))))

(:wat::core::defn :mal::kv-assoc [kvs <- :mal::Vals k <- :mal::Val v <- :mal::Val] -> :mal::Vals
  (:wat::core::let [i (:mal::kv-index kvs k 0)]
    (:wat::core::if (:wat::core::< i 0)
      (:wat::core::conj (:wat::core::conj kvs k) v)
      (:wat::core::concat (:wat::core::conj (:wat::core::into (:wat::core::Vector :- [:mal::Val]) (:wat::core::take kvs (:wat::core::+ i 1))) v)
                          (:wat::core::into (:wat::core::Vector :- [:mal::Val]) (:wat::core::drop kvs (:wat::core::+ i 2)))))))

(:wat::core::defn :mal::kv-assoc-all [kvs <- :mal::Vals args <- :mal::Vals] -> :mal::Vals
  (:wat::core::if (:wat::core::< (:wat::core::length args) 2)
    kvs
    (:mal::kv-assoc-all (:mal::kv-assoc kvs (:wat::core::first args) (:wat::core::second args)) (:wat::core::rest (:wat::core::rest args)))))

(:wat::core::defn :mal::kv-dissoc-all [kvs <- :mal::Vals ks <- :mal::Vals] -> :mal::Vals
  (:wat::core::if (:wat::core::empty? ks)
    kvs
    (:wat::core::let [i (:mal::kv-index kvs (:wat::core::first ks) 0)]
      (:mal::kv-dissoc-all
        (:wat::core::if (:wat::core::< i 0)
          kvs
          (:wat::core::concat (:wat::core::into (:wat::core::Vector :- [:mal::Val]) (:wat::core::take kvs i))
                              (:wat::core::into (:wat::core::Vector :- [:mal::Val]) (:wat::core::drop kvs (:wat::core::+ i 2)))))
        (:wat::core::rest ks)))))

(:wat::core::defn :mal::kv-get [kvs <- :mal::Vals k <- :mal::Val] -> :mal::Val
  (:wat::core::let [i (:mal::kv-index kvs k 0)]
    (:wat::core::if (:wat::core::< i 0) (:mal::nil) (:wat::core::nth kvs (:wat::core::+ i 1)))))

(:wat::core::defn :mal::every-other [xs <- :mal::Vals] -> :mal::Vals
  (:wat::core::into (:wat::core::Vector :- [:mal::Val]) (:wat::core::take-nth 2 xs)))

(:wat::core::defn :mal::kind-is? [v <- :mal::Val k <- :wat::core::keyword] -> :mal::Res
  (:mal::ok (:mal::bool (:wat::core::= (:mal::kind-of v) k))))

;; a list's or a vector's elements, and nil's none
(:wat::core::defn :mal::items-or-none [v <- :mal::Val] -> (:wat::core::Option :- [:mal::Vals])
  (:wat::core::if (:wat::core::= (:mal::kind-of v) :nil)
    (:wat::core::Option.Some {:value (:wat::core::Vector :- [:mal::Val])})
    (:mal::seq-of v)))

(:wat::core::defn :mal::concat-all [args <- :mal::Vals acc <- :mal::Vals] -> :mal::Res
  (:wat::core::if (:wat::core::empty? args)
    (:mal::ok (:mal::list acc))
    (:wat::core::match (:mal::items-or-none (:wat::core::first args))
      [:wat::core::Option.Some {:value xs} (:mal::concat-all (:wat::core::rest args) (:wat::core::concat acc xs))]
      [:wat::core::Option.None {} (:mal::fail "concat: expected lists")])))

(:wat::core::defn :mal::arith [name <- :wat::core::String a <- :wat::core::i64 b <- :wat::core::i64] -> :mal::Val
  (:wat::core::cond
    ((:wat::core::= name "+") (:mal::int (:wat::core::+ a b)))
    ((:wat::core::= name "-") (:mal::int (:wat::core::- a b)))
    ((:wat::core::= name "*") (:mal::int (:wat::core::* a b)))
    ((:wat::core::= name "/") (:mal::int (:wat::core::/ a b)))
    ((:wat::core::= name "<") (:mal::bool (:wat::core::< a b)))
    ((:wat::core::= name "<=") (:mal::bool (:wat::core::<= a b)))
    ((:wat::core::= name ">") (:mal::bool (:wat::core::> a b)))
    (:else (:mal::bool (:wat::core::>= a b)))))

(:wat::core::defn :mal::numeric [name <- :wat::core::String args <- :mal::Vals] -> :mal::Res
  (:wat::core::if (:wat::core::not (:wat::core::= (:wat::core::length args) 2))
    (:mal::fail (:wat::string::concat name ": expected 2 arguments"))
    (:wat::core::match (:mal::int-of (:wat::core::first args))
      [:wat::core::Option.Some {:value a}
        (:wat::core::match (:mal::int-of (:wat::core::second args))
          [:wat::core::Option.Some {:value b} (:mal::ok (:mal::arith name a b))]
          [:wat::core::Option.None {} (:mal::fail (:wat::string::concat name ": expected numbers"))])]
      [:wat::core::Option.None {} (:mal::fail (:wat::string::concat name ": expected numbers"))])))

(:wat::core::defn :mal::all-equal? [xs <- :mal::Vals ys <- :mal::Vals] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? xs)
    (:wat::core::empty? ys)
    (:wat::core::if (:wat::core::empty? ys)
      false
      (:wat::core::and (:mal::equal? (:wat::core::first xs) (:wat::core::first ys))
                       (:mal::all-equal? (:wat::core::rest xs) (:wat::core::rest ys))))))

;; mal's =: a list equals a vector with equal elements; anything else is equal when it prints
;; the same
(:wat::core::defn :mal::equal? [a <- :mal::Val b <- :mal::Val] -> :wat::core::bool
  (:wat::core::match (:mal::seq-of a)
    [:wat::core::Option.Some {:value xs}
      (:wat::core::match (:mal::seq-of b)
        [:wat::core::Option.Some {:value ys} (:mal::all-equal? xs ys)]
        [:wat::core::Option.None {} false])]
    [:wat::core::Option.None {}
      (:wat::core::match (:mal::seq-of b)
        [:wat::core::Option.Some {:value ys} false]
        [:wat::core::Option.None {} (:wat::core::= (:mal::pr-str a true) (:mal::pr-str b true))])]))

(:wat::core::defn :mal::first-arg [args <- :mal::Vals] -> :mal::Val
  (:wat::core::if (:wat::core::empty? args) (:mal::nil) (:wat::core::first args)))

(:wat::core::defn :mal::count-of [v <- :mal::Val] -> :mal::Res
  (:wat::core::match (:mal::seq-of v)
    [:wat::core::Option.Some {:value xs} (:mal::ok (:mal::int (:wat::core::length xs)))]
    [:wat::core::Option.None {}
      (:wat::core::if (:mal::falsy? v) (:mal::ok (:mal::int 0)) (:mal::fail "count: expected a list"))]))

(:wat::core::defn :mal::call-builtin [name <- :wat::core::String args <- :mal::Vals] -> :mal::Res
  (:wat::core::cond
    ((:wat::string::contains? " + - * / < <= > >= " (:wat::string::concat " " name " ")) (:mal::numeric name args))
    ((:wat::core::= name "=")
      (:wat::core::if (:wat::core::= (:wat::core::length args) 2)
        (:mal::ok (:mal::bool (:mal::equal? (:wat::core::first args) (:wat::core::second args))))
        (:mal::fail "=: expected 2 arguments")))
    ((:wat::core::= name "list") (:mal::ok (:mal::list args)))
    ((:wat::core::= name "list?")
      (:mal::ok (:mal::bool (:wat::core::match (:mal::list-of (:mal::first-arg args))
                              [:wat::core::Option.Some {:value xs} true]
                              [:wat::core::Option.None {} false]))))
    ((:wat::core::= name "empty?")
      (:wat::core::match (:mal::seq-of (:mal::first-arg args))
        [:wat::core::Option.Some {:value xs} (:mal::ok (:mal::bool (:wat::core::empty? xs)))]
        [:wat::core::Option.None {} (:mal::fail "empty?: expected a list")]))
    ((:wat::core::= name "count") (:mal::count-of (:mal::first-arg args)))
    ((:wat::core::= name "not") (:mal::ok (:mal::bool (:mal::falsy? (:mal::first-arg args)))))
    ((:wat::core::= name "pr-str") (:mal::ok (:mal::str (:mal::pr-args args true " "))))
    ((:wat::core::= name "str") (:mal::ok (:mal::str (:mal::pr-args args false ""))))
    ((:wat::core::= name "prn")
      (:wat::core::do (:wat::kernel::println (:mal::pr-args args true " ")) (:mal::ok (:mal::nil))))
    ((:wat::core::= name "println")
      (:wat::core::do (:wat::kernel::println (:mal::pr-args args false " ")) (:mal::ok (:mal::nil))))
    ((:wat::core::= name "cons")
      (:wat::core::match (:mal::items-or-none (:mal::first-arg (:wat::core::rest args)))
        [:wat::core::Option.Some {:value xs} (:mal::ok (:mal::list (:wat::core::concat (:wat::core::Vector :- [:mal::Val] (:mal::first-arg args)) xs)))]
        [:wat::core::Option.None {} (:mal::fail "cons: expected a list")]))
    ((:wat::core::= name "concat") (:mal::concat-all args (:wat::core::Vector :- [:mal::Val])))
    ((:wat::core::= name "vec")
      (:wat::core::match (:mal::items-or-none (:mal::first-arg args))
        [:wat::core::Option.Some {:value xs} (:mal::ok (:mal::vec xs))]
        [:wat::core::Option.None {} (:mal::fail "vec: expected a list")]))
    ((:wat::core::= name "nth")
      (:wat::core::match (:mal::items-or-none (:mal::first-arg args))
        [:wat::core::Option.Some {:value xs}
          (:wat::core::match (:mal::int-of (:mal::first-arg (:wat::core::rest args)))
            [:wat::core::Option.Some {:value i}
              (:wat::core::if (:wat::core::and (:wat::core::>= i 0) (:wat::core::< i (:wat::core::length xs)))
                (:mal::ok (:wat::core::nth xs i))
                (:mal::fail "nth: index out of range"))]
            [:wat::core::Option.None {} (:mal::fail "nth: expected an index")])]
        [:wat::core::Option.None {} (:mal::fail "nth: expected a list")]))
    ;; first and rest are total: nil for an empty list's first, and () for its rest
    ((:wat::core::= name "first")
      (:wat::core::match (:mal::items-or-none (:mal::first-arg args))
        [:wat::core::Option.Some {:value xs} (:mal::ok (:mal::first-arg xs))]
        [:wat::core::Option.None {} (:mal::fail "first: expected a list")]))
    ((:wat::core::= name "rest")
      (:wat::core::match (:mal::items-or-none (:mal::first-arg args))
        [:wat::core::Option.Some {:value xs}
          (:mal::ok (:mal::list (:wat::core::if (:wat::core::empty? xs) xs (:wat::core::rest xs))))]
        [:wat::core::Option.None {} (:mal::fail "rest: expected a list")]))
    ((:wat::core::= name "macro?") (:mal::ok (:mal::bool (:wat::core::= (:mal::kind-of (:mal::first-arg args)) :macro))))
    ((:wat::core::= name "nil?") (:mal::kind-is? (:mal::first-arg args) :nil))
    ((:wat::core::= name "true?") (:mal::kind-is? (:mal::first-arg args) :true))
    ((:wat::core::= name "false?") (:mal::kind-is? (:mal::first-arg args) :false))
    ((:wat::core::= name "symbol?") (:mal::kind-is? (:mal::first-arg args) :sym))
    ((:wat::core::= name "keyword?") (:mal::kind-is? (:mal::first-arg args) :kw))
    ((:wat::core::= name "vector?") (:mal::kind-is? (:mal::first-arg args) :vec))
    ((:wat::core::= name "map?") (:mal::kind-is? (:mal::first-arg args) :map))
    ((:wat::core::= name "sequential?")
      (:wat::core::let [k (:mal::kind-of (:mal::first-arg args))]
        (:mal::ok (:mal::bool (:wat::core::or (:wat::core::= k :list) (:wat::core::= k :vec))))))
    ((:wat::core::= name "symbol")
      (:wat::core::match (:mal::str-of (:mal::first-arg args))
        [:wat::core::Option.Some {:value s} (:mal::ok (:mal::sym s))]
        [:wat::core::Option.None {} (:mal::fail "symbol: expected a string")]))
    ((:wat::core::= name "keyword")
      (:wat::core::if (:wat::core::= (:mal::kind-of (:mal::first-arg args)) :kw)
        (:mal::ok (:mal::first-arg args))
        (:wat::core::match (:mal::str-of (:mal::first-arg args))
          [:wat::core::Option.Some {:value s} (:mal::ok (:mal::kw s))]
          [:wat::core::Option.None {} (:mal::fail "keyword: expected a string")])))
    ((:wat::core::= name "vector") (:mal::ok (:mal::vec args)))
    ((:wat::core::= name "hash-map") (:mal::ok (:mal::map (:mal::kv-assoc-all (:wat::core::Vector :- [:mal::Val]) args))))
    ((:wat::core::= name "assoc")
      (:wat::core::match (:mal::kvs-of (:mal::first-arg args))
        [:wat::core::Option.Some {:value kvs} (:mal::ok (:mal::map (:mal::kv-assoc-all kvs (:wat::core::rest args))))]
        [:wat::core::Option.None {} (:mal::fail "assoc: expected a hash-map")]))
    ((:wat::core::= name "dissoc")
      (:wat::core::match (:mal::kvs-of (:mal::first-arg args))
        [:wat::core::Option.Some {:value kvs} (:mal::ok (:mal::map (:mal::kv-dissoc-all kvs (:wat::core::rest args))))]
        [:wat::core::Option.None {} (:mal::fail "dissoc: expected a hash-map")]))
    ;; get and contains? of anything but a hash-map (nil, above all) find nothing
    ((:wat::core::= name "get")
      (:wat::core::match (:mal::kvs-of (:mal::first-arg args))
        [:wat::core::Option.Some {:value kvs} (:mal::ok (:mal::kv-get kvs (:mal::first-arg (:wat::core::rest args))))]
        [:wat::core::Option.None {} (:mal::ok (:mal::nil))]))
    ((:wat::core::= name "contains?")
      (:wat::core::match (:mal::kvs-of (:mal::first-arg args))
        [:wat::core::Option.Some {:value kvs} (:mal::ok (:mal::bool (:wat::core::>= (:mal::kv-index kvs (:mal::first-arg (:wat::core::rest args)) 0) 0)))]
        [:wat::core::Option.None {} (:mal::ok (:mal::false))]))
    ((:wat::core::= name "keys")
      (:wat::core::match (:mal::kvs-of (:mal::first-arg args))
        [:wat::core::Option.Some {:value kvs} (:mal::ok (:mal::list (:mal::every-other kvs)))]
        [:wat::core::Option.None {} (:mal::fail "keys: expected a hash-map")]))
    ((:wat::core::= name "vals")
      (:wat::core::match (:mal::kvs-of (:mal::first-arg args))
        [:wat::core::Option.Some {:value kvs}
          (:mal::ok (:mal::list (:wat::core::if (:wat::core::empty? kvs) kvs (:mal::every-other (:wat::core::rest kvs)))))]
        [:wat::core::Option.None {} (:mal::fail "vals: expected a hash-map")]))
    (:else (:mal::fail (:wat::string::concat "unknown builtin " name)))))
