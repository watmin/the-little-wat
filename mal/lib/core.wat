;; mal/lib/core.wat: mal's builtin functions, each dispatched by its name. Needs lib/types.wat
;; and lib/printer.wat. No main. Keyword spelling throughout.
;;
;; The builtins here need nothing but their arguments. Those that call back into mal (apply,
;; map, swap!) or touch the store are in the step programs that have them.

(:wat::core::defn :mal::core-names [] -> :mal::Strs
  ["+" "-" "*" "/" "<" "<=" ">" ">=" "=" "list" "list?" "empty?" "count" "not" "pr-str" "str" "prn" "println"])

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
    (:else (:mal::fail (:wat::string::concat "unknown builtin " name)))))
