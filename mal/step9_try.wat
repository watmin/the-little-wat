;; mal/step9_try.wat: Make-a-Lisp step 9: try*/catch* and throw, apply and map, and the
;; predicates, keywords, symbols, vectors and hash-maps.
;;
;; Step 8, plus try*. A thrown value is an evaluation's Err, as every error already is, so try*
;; is a match on it. apply and map call back into mal, so they are dispatched here with the
;; store's builtins; the rest are lib/core.wat's. Driven by mal's own runner through
;; tools/mal-shim.py (tools/mal-test.sh step9_try): each input line arrives as one EDN string,
;; and each output line goes back as one, then :mal/done (FINDINGS F-049, F-050). Keyword
;; spelling throughout.

(:wat::load-file! "lib/types.wat")
(:wat::load-file! "lib/reader.wat")
(:wat::load-file! "lib/printer.wat")
(:wat::load-file! "lib/env.wat")
(:wat::load-file! "lib/core.wat")

(:wat::core::defn :mal::store-names [] -> :mal::Strs
  ["atom" "atom?" "deref" "reset!" "swap!" "eval" "read-string" "slurp" "throw" "apply" "map"])

;; the environment eval evaluates in: the REPL's, the first one the store makes
(:wat::core::defn :mal::repl-env [] -> :wat::core::i64 0)

(:wat::core::defn :mal::with-atom [name <- :wat::core::String args <- :mal::Vals f <- [:wat::core::i64 :-> :mal::Res]] -> :mal::Res
  (:wat::core::match (:mal::atom-of (:mal::first-arg args))
    [:wat::core::Option.Some {:value id} (f id)]
    [:wat::core::Option.None {} (:mal::fail (:wat::string::concat name ": expected an atom"))]))

(:wat::core::defn :mal::with-string [name <- :wat::core::String args <- :mal::Vals f <- [:wat::core::String :-> :mal::Res]] -> :mal::Res
  (:wat::core::match (:mal::str-of (:mal::first-arg args))
    [:wat::core::Option.Some {:value s} (f s)]
    [:wat::core::Option.None {} (:mal::fail (:wat::string::concat name ": expected a string"))]))

(:wat::core::defn :mal::call-store-builtin [name <- :wat::core::String args <- :mal::Vals st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::cond
    ((:wat::core::= name "atom") (:mal::ok (:mal::atom-ref (:mal::new-atom! st (:mal::first-arg args)))))
    ((:wat::core::= name "atom?")
      (:mal::ok (:mal::bool (:wat::core::match (:mal::atom-of (:mal::first-arg args))
                              [:wat::core::Option.Some {:value id} true]
                              [:wat::core::Option.None {} false]))))
    ((:wat::core::= name "deref")
      (:mal::with-atom name args (:wat::core::fn [id <- :wat::core::i64] -> :mal::Res (:mal::ok (:mal::atom-deref st id)))))
    ((:wat::core::= name "reset!")
      (:mal::with-atom name args
        (:wat::core::fn [id <- :wat::core::i64] -> :mal::Res
          (:mal::ok (:mal::atom-reset! st id (:mal::first-arg (:wat::core::rest args)))))))
    ;; (swap! a f & more): f of the atom's value and more; not atomic (a deref, then a reset)
    ((:wat::core::= name "swap!")
      (:mal::with-atom name args
        (:wat::core::fn [id <- :wat::core::i64] -> :mal::Res
          (:wat::core::match (:mal::apply (:mal::first-arg (:wat::core::rest args))
                                          (:wat::core::concat (:wat::core::Vector :- [:mal::Val] (:mal::atom-deref st id))
                                                              (:wat::core::rest (:wat::core::rest args)))
                                          st)
            [:mal::Res.Ok {:v v} (:mal::ok (:mal::atom-reset! st id v))]
            [:mal::Res.Err {:e e} (:mal::err e)]))))
    ((:wat::core::= name "eval") (:mal::eval (:mal::first-arg args) (:mal::repl-env) st))
    ((:wat::core::= name "read-string")
      (:mal::with-string name args
        (:wat::core::fn [s <- :wat::core::String] -> :mal::Res
          (:wat::core::match (:mal::read-str s)
            [:mal::Read.Got {:v v :next j} (:mal::ok v)]
            [:mal::Read.Failed {:msg m} (:mal::fail m)]
            [:mal::Read.Empty {} (:mal::ok (:mal::nil))]))))
    ((:wat::core::= name "slurp")
      (:mal::with-string name args
        (:wat::core::fn [path <- :wat::core::String] -> :mal::Res (:mal::ok (:mal::str (:wat::io::read-file path))))))
    ((:wat::core::= name "throw") (:mal::err (:mal::first-arg args)))
    ;; (apply f a b (c d)): f of a, b, c and d
    ((:wat::core::= name "apply")
      (:wat::core::if (:wat::core::< (:wat::core::length args) 2)
        (:mal::fail "apply: expected a function and a list")
        (:wat::core::let [n (:wat::core::length args)]
          (:wat::core::match (:mal::items-or-none (:wat::core::nth args (:wat::core::- n 1)))
            [:wat::core::Option.Some {:value tail}
              (:mal::apply (:wat::core::first args)
                           (:wat::core::concat (:wat::core::into (:wat::core::Vector :- [:mal::Val]) (:wat::core::take (:wat::core::rest args) (:wat::core::- n 2)))
                                               tail)
                           st)]
            [:wat::core::Option.None {} (:mal::fail "apply: expected a list last")]))))
    ((:wat::core::= name "map")
      (:wat::core::match (:mal::items-or-none (:mal::first-arg (:wat::core::rest args)))
        [:wat::core::Option.Some {:value xs} (:mal::map-each (:mal::first-arg args) xs (:wat::core::Vector :- [:mal::Val]) st)]
        [:wat::core::Option.None {} (:mal::fail "map: expected a list")]))
    (:else (:mal::call-builtin name args))))

;; f of each element, in order; the first thrown value stops it
(:wat::core::defn :mal::map-each [f <- :mal::Val xs <- :mal::Vals acc <- :mal::Vals st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::if (:wat::core::empty? xs)
    (:mal::ok (:mal::list acc))
    (:wat::core::match (:mal::apply f (:wat::core::Vector :- [:mal::Val] (:wat::core::first xs)) st)
      [:mal::Res.Ok {:v v} (:mal::map-each f (:wat::core::rest xs) (:wat::core::conj acc v) st)]
      [:mal::Res.Err {:e e} (:mal::err e)])))

;; ---- quasiquote, expanded into cons, concat and vec calls

(:wat::core::defn :mal::qq-fold [xs <- :mal::Vals] -> :mal::Val
  (:wat::core::foldl
    (:wat::core::fn [acc <- :mal::Val elt <- :mal::Val] -> :mal::Val
      (:wat::core::match (:mal::list-of elt)
        [:wat::core::Option.Some {:value ys}
          (:wat::core::if (:wat::core::and (:wat::core::not (:wat::core::empty? ys)) (:mal::sym-is? (:wat::core::first ys) "splice-unquote"))
            (:mal::list (:wat::core::Vector :- [:mal::Val] (:mal::sym "concat") (:mal::first-arg (:wat::core::rest ys)) acc))
            (:mal::list (:wat::core::Vector :- [:mal::Val] (:mal::sym "cons") (:mal::qq elt) acc)))]
        [:wat::core::Option.None {} (:mal::list (:wat::core::Vector :- [:mal::Val] (:mal::sym "cons") (:mal::qq elt) acc))]))
    (:mal::list (:wat::core::Vector :- [:mal::Val]))
    (:wat::core::reverse xs)))

(:wat::core::defn :mal::qq [ast <- :mal::Val] -> :mal::Val
  (:wat::core::let [k (:mal::kind-of ast)]
    (:wat::core::cond
      ((:wat::core::= k :list)
        (:wat::core::match (:mal::list-of ast)
          [:wat::core::Option.Some {:value xs}
            (:wat::core::if (:wat::core::and (:wat::core::not (:wat::core::empty? xs)) (:mal::sym-is? (:wat::core::first xs) "unquote"))
              (:mal::first-arg (:wat::core::rest xs))
              (:mal::qq-fold xs))]
          [:wat::core::Option.None {} ast]))
      ((:wat::core::= k :vec)
        (:wat::core::match (:mal::seq-of ast)
          [:wat::core::Option.Some {:value xs} (:mal::list (:wat::core::Vector :- [:mal::Val] (:mal::sym "vec") (:mal::qq-fold xs)))]
          [:wat::core::Option.None {} ast]))
      ((:wat::core::or (:wat::core::= k :map) (:wat::core::= k :sym))
        (:mal::list (:wat::core::Vector :- [:mal::Val] (:mal::sym "quote") ast)))
      (:else ast))))

;; ---- macros

;; defmacro!'s value: the closure, marked as a macro
(:wat::core::defn :mal::as-macro [v <- :mal::Val] -> :mal::Res
  (:wat::core::match v
    [:mal::Val.Closure {:params p :body b :env e} (:mal::ok (:mal::macro p b e))]
    [:mal::Val.Macro {:params p :body b :env e} (:mal::ok v)]
    [:mal::Val.Nil {} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.True {} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.False {} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.Int {:n n} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.Str {:s s} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.Sym {:name x} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.Kw {:name x} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.List {:items x} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.Vec {:items x} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.Map {:kvs x} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.Builtin {:name x} (:mal::fail "defmacro!: expected a function")]
    [:mal::Val.Atom {:id i} (:mal::fail "defmacro!: expected a function")]))

;; a macro applied to its arguments, unevaluated: the form it expands to
(:wat::core::defn :mal::apply-macro [m <- :mal::Val args <- :mal::Vals st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match m
    [:mal::Val.Macro {:params params :body body :env menv}
      (:wat::core::let [inner (:mal::new-env! st menv)]
        (:wat::core::match (:mal::bind-params params args inner st)
          [:mal::Res.Ok {:v x} (:mal::eval body inner st)]
          [:mal::Res.Err {:e e} (:mal::err e)]))]
    [:mal::Val.Closure {:params p :body b :env e} (:mal::fail "not a macro")]
    [:mal::Val.Nil {} (:mal::fail "not a macro")]
    [:mal::Val.True {} (:mal::fail "not a macro")]
    [:mal::Val.False {} (:mal::fail "not a macro")]
    [:mal::Val.Int {:n n} (:mal::fail "not a macro")]
    [:mal::Val.Str {:s s} (:mal::fail "not a macro")]
    [:mal::Val.Sym {:name x} (:mal::fail "not a macro")]
    [:mal::Val.Kw {:name x} (:mal::fail "not a macro")]
    [:mal::Val.List {:items x} (:mal::fail "not a macro")]
    [:mal::Val.Vec {:items x} (:mal::fail "not a macro")]
    [:mal::Val.Map {:kvs x} (:mal::fail "not a macro")]
    [:mal::Val.Builtin {:name x} (:mal::fail "not a macro")]
    [:mal::Val.Atom {:id i} (:mal::fail "not a macro")]))

;; expand ast while it is a call of a macro
(:wat::core::defn :mal::macroexpand [ast <- :mal::Val env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match (:mal::list-of ast)
    [:wat::core::Option.Some {:value xs}
      (:wat::core::if (:wat::core::empty? xs)
        (:mal::ok ast)
        (:wat::core::match (:mal::sym-of (:wat::core::first xs))
          [:wat::core::Option.Some {:value name}
            (:wat::core::match (:mal::env-get st env name)
              [:wat::core::Option.Some {:value f}
                (:wat::core::if (:wat::core::= (:mal::kind-of f) :macro)
                  (:wat::core::match (:mal::apply-macro f (:wat::core::rest xs) st)
                    [:mal::Res.Ok {:v form} (:mal::macroexpand form env st)]
                    [:mal::Res.Err {:e e} (:mal::err e)])
                  (:mal::ok ast))]
              [:wat::core::Option.None {} (:mal::ok ast)])]
          [:wat::core::Option.None {} (:mal::ok ast)]))]
    [:wat::core::Option.None {} (:mal::ok ast)]))

(:wat::core::defn :mal::eval-defmacro [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::if (:wat::core::< (:wat::core::length xs) 3)
    (:mal::fail "defmacro!: expected a name and a function")
    (:wat::core::match (:mal::sym-of (:wat::core::second xs))
      [:wat::core::Option.Some {:value name}
        (:wat::core::match (:mal::eval (:wat::core::third xs) env st)
          [:mal::Res.Ok {:v f}
            (:wat::core::match (:mal::as-macro f)
              [:mal::Res.Ok {:v m} (:mal::ok (:mal::env-set! st env name m))]
              [:mal::Res.Err {:e e} (:mal::err e)])]
          [:mal::Res.Err {:e e} (:mal::err e)])]
      [:wat::core::Option.None {} (:mal::fail "defmacro!: expected a symbol")])))

;; ---- try*

;; (try* A (catch* e B)): A's value, or, if A throws, B with e bound to what was thrown
(:wat::core::defn :mal::eval-try [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match (:mal::eval (:mal::first-arg (:wat::core::rest xs)) env st)
    [:mal::Res.Ok {:v v} (:mal::ok v)]
    [:mal::Res.Err {:e e}
      (:wat::core::if (:wat::core::< (:wat::core::length xs) 3)
        (:mal::err e)
        (:wat::core::match (:mal::list-of (:wat::core::third xs))
          [:wat::core::Option.Some {:value cs}
            (:wat::core::if (:wat::core::and (:wat::core::>= (:wat::core::length cs) 3) (:mal::sym-is? (:wat::core::first cs) "catch*"))
              (:wat::core::match (:mal::sym-of (:wat::core::second cs))
                [:wat::core::Option.Some {:value name}
                  (:wat::core::let [inner (:mal::new-env! st env)]
                    (:wat::core::do
                      (:mal::env-set! st inner name e)
                      (:mal::eval (:wat::core::third cs) inner st)))]
                [:wat::core::Option.None {} (:mal::err e)])
              (:mal::err e))]
          [:wat::core::Option.None {} (:mal::err e)]))]))

;; bind a closure's parameters to its arguments; after &, one name takes the rest as a list
(:wat::core::defn :mal::bind-params [params <- :mal::Vals args <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::if (:wat::core::empty? params)
    (:mal::ok (:mal::nil))
    (:wat::core::match (:mal::sym-of (:wat::core::first params))
      [:wat::core::Option.Some {:value name}
        (:wat::core::if (:wat::core::= name "&")
          (:wat::core::match (:mal::sym-of (:wat::core::second params))
            [:wat::core::Option.Some {:value rest-name} (:wat::core::do (:mal::env-set! st env rest-name (:mal::list args)) (:mal::ok (:mal::nil)))]
            [:wat::core::Option.None {} (:mal::fail "fn*: expected a name after &")])
          (:wat::core::do
            (:mal::env-set! st env name (:mal::first-arg args))
            (:mal::bind-params (:wat::core::rest params)
                               (:wat::core::if (:wat::core::empty? args) args (:wat::core::rest args))
                               env st)))]
      [:wat::core::Option.None {} (:mal::fail "fn*: expected a symbol")])))

(:wat::core::defn :mal::apply [f <- :mal::Val args <- :mal::Vals st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match f
    [:mal::Val.Builtin {:name name} (:mal::call-store-builtin name args st)]
    [:mal::Val.Closure {:params params :body body :env cenv}
      (:wat::core::let [inner (:mal::new-env! st cenv)]
        (:wat::core::match (:mal::bind-params params args inner st)
          [:mal::Res.Ok {:v x} (:mal::eval body inner st)]
          [:mal::Res.Err {:e e} (:mal::err e)]))]
    [:mal::Val.Nil {} (:mal::fail "nil is not a function")]
    [:mal::Val.True {} (:mal::fail "true is not a function")]
    [:mal::Val.False {} (:mal::fail "false is not a function")]
    [:mal::Val.Int {:n n} (:mal::fail (:wat::string::concat (:wat::i64::to-string n) " is not a function"))]
    [:mal::Val.Str {:s s} (:mal::fail "a string is not a function")]
    [:mal::Val.Sym {:name name} (:mal::fail (:wat::string::concat name " is not a function"))]
    [:mal::Val.Kw {:name name} (:mal::fail "a keyword is not a function")]
    [:mal::Val.List {:items xs} (:mal::fail "a list is not a function")]
    [:mal::Val.Vec {:items xs} (:mal::fail "a vector is not a function")]
    [:mal::Val.Map {:kvs kvs} (:mal::fail "a map is not a function")]
    [:mal::Val.Atom {:id i} (:mal::fail "an atom is not a function")]
    [:mal::Val.Macro {:params params :body body :env menv}
      (:wat::core::let [inner (:mal::new-env! st menv)]
        (:wat::core::match (:mal::bind-params params args inner st)
          [:mal::Res.Ok {:v x} (:mal::eval body inner st)]
          [:mal::Res.Err {:e e} (:mal::err e)]))]))

(:wat::core::defn :mal::eval-all [xs <- :mal::Vals acc <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Many
  (:wat::core::if (:wat::core::empty? xs)
    (:mal::many acc)
    (:wat::core::match (:mal::eval (:wat::core::first xs) env st)
      [:mal::Res.Ok {:v v} (:mal::eval-all (:wat::core::rest xs) (:wat::core::conj acc v) env st)]
      [:mal::Res.Err {:e e} (:mal::many-err e)])))

(:wat::core::defn :mal::eval-kvs [kvs <- :mal::Vals acc <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Many
  (:wat::core::if (:wat::core::empty? kvs)
    (:mal::many acc)
    (:wat::core::match (:mal::eval (:wat::core::second kvs) env st)
      [:mal::Res.Ok {:v v} (:mal::eval-kvs (:wat::core::rest (:wat::core::rest kvs)) (:wat::core::conj (:wat::core::conj acc (:wat::core::first kvs)) v) env st)]
      [:mal::Res.Err {:e e} (:mal::many-err e)])))

(:wat::core::defn :mal::eval-def [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::if (:wat::core::< (:wat::core::length xs) 3)
    (:mal::fail "def!: expected a name and a value")
    (:wat::core::match (:mal::sym-of (:wat::core::second xs))
      [:wat::core::Option.Some {:value name}
        (:wat::core::match (:mal::eval (:wat::core::third xs) env st)
          [:mal::Res.Ok {:v v} (:mal::ok (:mal::env-set! st env name v))]
          [:mal::Res.Err {:e e} (:mal::err e)])]
      [:wat::core::Option.None {} (:mal::fail "def!: expected a symbol")])))

(:wat::core::defn :mal::bind-all [binds <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::if (:wat::core::< (:wat::core::length binds) 2)
    (:mal::ok (:mal::nil))
    (:wat::core::match (:mal::sym-of (:wat::core::first binds))
      [:wat::core::Option.Some {:value name}
        (:wat::core::match (:mal::eval (:wat::core::second binds) env st)
          [:mal::Res.Ok {:v v}
            (:wat::core::do
              (:mal::env-set! st env name v)
              (:mal::bind-all (:wat::core::rest (:wat::core::rest binds)) env st))]
          [:mal::Res.Err {:e e} (:mal::err e)])]
      [:wat::core::Option.None {} (:mal::fail "let*: expected a symbol")])))

(:wat::core::defn :mal::eval-let [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::if (:wat::core::< (:wat::core::length xs) 3)
    (:mal::fail "let*: expected bindings and a body")
    (:wat::core::match (:mal::seq-of (:wat::core::second xs))
      [:wat::core::Option.Some {:value binds}
        (:wat::core::let [inner (:mal::new-env! st env)]
          (:wat::core::match (:mal::bind-all binds inner st)
            [:mal::Res.Ok {:v x} (:mal::eval (:wat::core::third xs) inner st)]
            [:mal::Res.Err {:e e} (:mal::err e)]))]
      [:wat::core::Option.None {} (:mal::fail "let*: expected a list of bindings")])))

(:wat::core::defn :mal::eval-do [forms <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::if (:wat::core::empty? forms)
    (:mal::ok (:mal::nil))
    (:wat::core::if (:wat::core::empty? (:wat::core::rest forms))
      (:mal::eval (:wat::core::first forms) env st)
      (:wat::core::match (:mal::eval (:wat::core::first forms) env st)
        [:mal::Res.Ok {:v v} (:mal::eval-do (:wat::core::rest forms) env st)]
        [:mal::Res.Err {:e e} (:mal::err e)]))))

(:wat::core::defn :mal::eval-if [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::if (:wat::core::< (:wat::core::length xs) 3)
    (:mal::fail "if: expected a test and a branch")
    (:wat::core::match (:mal::eval (:wat::core::second xs) env st)
      [:mal::Res.Ok {:v test}
        (:wat::core::if (:mal::falsy? test)
          (:wat::core::if (:wat::core::> (:wat::core::length xs) 3) (:mal::eval (:wat::core::nth xs 3) env st) (:mal::ok (:mal::nil)))
          (:mal::eval (:wat::core::third xs) env st))]
      [:mal::Res.Err {:e e} (:mal::err e)])))

(:wat::core::defn :mal::eval-fn [xs <- :mal::Vals env <- :wat::core::i64] -> :mal::Res
  (:wat::core::if (:wat::core::< (:wat::core::length xs) 3)
    (:mal::fail "fn*: expected parameters and a body")
    (:wat::core::match (:mal::seq-of (:wat::core::second xs))
      [:wat::core::Option.Some {:value params} (:mal::ok (:mal::closure params (:wat::core::third xs) env))]
      [:wat::core::Option.None {} (:mal::fail "fn*: expected a list of parameters")])))

;; the head first: a macro gets the arguments unevaluated, and its expansion is evaluated
(:wat::core::defn :mal::eval-apply [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match (:mal::eval (:wat::core::first xs) env st)
    [:mal::Res.Ok {:v f}
      (:wat::core::if (:wat::core::= (:mal::kind-of f) :macro)
        (:wat::core::match (:mal::apply-macro f (:wat::core::rest xs) st)
          [:mal::Res.Ok {:v form} (:mal::eval form env st)]
          [:mal::Res.Err {:e e} (:mal::err e)])
        (:wat::core::match (:mal::eval-all (:wat::core::rest xs) (:wat::core::Vector :- [:mal::Val]) env st)
          [:mal::Many.Ok {:vs vs} (:mal::apply f vs st)]
          [:mal::Many.Err {:e e} (:mal::err e)]))]
    [:mal::Res.Err {:e e} (:mal::err e)]))

(:wat::core::defn :mal::eval-list [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match (:mal::sym-of (:wat::core::first xs))
    [:wat::core::Option.Some {:value name}
      (:wat::core::cond
        ((:wat::core::= name "def!") (:mal::eval-def xs env st))
        ((:wat::core::= name "let*") (:mal::eval-let xs env st))
        ((:wat::core::= name "do") (:mal::eval-do (:wat::core::rest xs) env st))
        ((:wat::core::= name "if") (:mal::eval-if xs env st))
        ((:wat::core::= name "fn*") (:mal::eval-fn xs env))
        ((:wat::core::= name "quote") (:mal::ok (:mal::first-arg (:wat::core::rest xs))))
        ((:wat::core::= name "quasiquoteexpand") (:mal::ok (:mal::qq (:mal::first-arg (:wat::core::rest xs)))))
        ((:wat::core::= name "quasiquote") (:mal::eval (:mal::qq (:mal::first-arg (:wat::core::rest xs))) env st))
        ((:wat::core::= name "defmacro!") (:mal::eval-defmacro xs env st))
        ((:wat::core::= name "macroexpand") (:mal::macroexpand (:mal::first-arg (:wat::core::rest xs)) env st))
        ((:wat::core::= name "try*") (:mal::eval-try xs env st))
        (:else (:mal::eval-apply xs env st)))]
    [:wat::core::Option.None {} (:mal::eval-apply xs env st)]))

(:wat::core::defn :mal::eval [ast <- :mal::Val env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match ast
    [:mal::Val.Sym {:name name}
      (:wat::core::match (:mal::env-get st env name)
        [:wat::core::Option.Some {:value v} (:mal::ok v)]
        [:wat::core::Option.None {} (:mal::fail (:wat::string::concat "'" name "' not found"))])]
    [:mal::Val.List {:items xs}
      (:wat::core::if (:wat::core::empty? xs) (:mal::ok ast) (:mal::eval-list xs env st))]
    [:mal::Val.Vec {:items xs}
      (:wat::core::match (:mal::eval-all xs (:wat::core::Vector :- [:mal::Val]) env st)
        [:mal::Many.Ok {:vs vs} (:mal::ok (:mal::vec vs))]
        [:mal::Many.Err {:e e} (:mal::err e)])]
    [:mal::Val.Map {:kvs kvs}
      (:wat::core::match (:mal::eval-kvs kvs (:wat::core::Vector :- [:mal::Val]) env st)
        [:mal::Many.Ok {:vs vs} (:mal::ok (:mal::map vs))]
        [:mal::Many.Err {:e e} (:mal::err e)])]
    [:mal::Val.Nil {} (:mal::ok ast)]
    [:mal::Val.True {} (:mal::ok ast)]
    [:mal::Val.False {} (:mal::ok ast)]
    [:mal::Val.Int {:n n} (:mal::ok ast)]
    [:mal::Val.Str {:s s} (:mal::ok ast)]
    [:mal::Val.Kw {:name name} (:mal::ok ast)]
    [:mal::Val.Builtin {:name name} (:mal::ok ast)]
    [:mal::Val.Closure {:params p :body b :env e} (:mal::ok ast)]
    [:mal::Val.Atom {:id i} (:mal::ok ast)]
    [:mal::Val.Macro {:params p :body b :env e} (:mal::ok ast)]))

(:wat::core::defn :mal::rep [line <- :wat::core::String env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Strs
  (:wat::core::match (:mal::read-str line)
    [:mal::Read.Got {:v v :next j} (:wat::core::Vector :- [:wat::core::String] (:mal::pr-res (:mal::show-res (:mal::eval v env st) st)))]
    [:mal::Read.Failed {:msg m} (:wat::core::Vector :- [:wat::core::String] m)]
    [:mal::Read.Empty {} (:wat::core::Vector :- [:wat::core::String])]))

(:wat::core::defn :mal::print-lines [lines <- :mal::Strs] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? lines)
    nil
    (:wat::core::do
      (:wat::kernel::println (:wat::core::first lines))
      (:mal::print-lines (:wat::core::rest lines)))))

(:wat::core::defn :mal::repl [env <- :wat::core::i64 st <- :mal::StoreRef] -> :wat::core::nil
  (:wat::core::match (:wat::kernel::read-frame)
    [:wat::kernel::ReadFrameOutcome.Frame {:text t}
      (:wat::core::do
        (:mal::print-lines (:mal::rep (:wat::edn::read t) env st))
        (:wat::kernel::println :mal/done)
        (:mal::repl env st))]
    [:wat::kernel::ReadFrameOutcome.Eof {} nil]
    [:wat::kernel::ReadFrameOutcome.Stopped {} nil]))

(:wat::core::defn :mal::define-builtins [names <- :mal::Strs env <- :wat::core::i64 st <- :mal::StoreRef] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? names)
    nil
    (:wat::core::do
      (:mal::env-set! st env (:wat::core::first names) (:mal::builtin (:wat::core::first names)))
      (:mal::define-builtins (:wat::core::rest names) env st))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [st (:mal::new-store)
                    env (:mal::new-env! st -1)]
    (:wat::core::do
      (:mal::define-builtins (:mal::core-names) env st)
      (:mal::define-builtins (:mal::store-names) env st)
      (:mal::rep "(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \"\\nnil)\")))))" env st)
      (:mal::rep "(def! *ARGV* (list))" env st)
      (:mal::rep "(defmacro! cond (fn* (& xs) (if (> (count xs) 0) (list 'if (first xs) (if (> (count xs) 1) (nth xs 1) (throw \"odd number of forms to cond\")) (cons 'cond (rest (rest xs)))))))" env st)
      (:mal::repl env st))))
