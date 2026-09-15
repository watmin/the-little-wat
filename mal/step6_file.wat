;; mal/step6_file.wat: Make-a-Lisp step 6: files, eval, and atoms.
;;
;; Atoms live on the store beside the environments (lib/env.wat); a mal atom is its id. The
;; builtins that touch the store or call back into mal (atom, deref, reset!, swap!, eval,
;; read-string, slurp) are dispatched here; the rest are lib/core.wat's. load-file and *ARGV*
;; are defined in mal at startup, as the process guide defines them. Driven by mal's own runner
;; through tools/mal-shim.py (tools/mal-test.sh step6_file): each input line arrives as one EDN
;; string, and each output line goes back as one, then :mal/done (FINDINGS F-049, F-050).
;; Keyword spelling throughout.

(:wat::load-file! "lib/types.wat")
(:wat::load-file! "lib/reader.wat")
(:wat::load-file! "lib/printer.wat")
(:wat::load-file! "lib/env.wat")
(:wat::load-file! "lib/core.wat")

(:wat::core::defn :mal::store-names [] -> :mal::Strs
  ["atom" "atom?" "deref" "reset!" "swap!" "eval" "read-string" "slurp"])

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
    (:else (:mal::call-builtin name args))))

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
    [:mal::Val.Atom {:id i} (:mal::fail "an atom is not a function")]))

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

(:wat::core::defn :mal::eval-apply [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match (:mal::eval-all xs (:wat::core::Vector :- [:mal::Val]) env st)
    [:mal::Many.Ok {:vs vs} (:mal::apply (:wat::core::first vs) (:wat::core::rest vs) st)]
    [:mal::Many.Err {:e e} (:mal::err e)]))

(:wat::core::defn :mal::eval-list [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match (:mal::sym-of (:wat::core::first xs))
    [:wat::core::Option.Some {:value name}
      (:wat::core::cond
        ((:wat::core::= name "def!") (:mal::eval-def xs env st))
        ((:wat::core::= name "let*") (:mal::eval-let xs env st))
        ((:wat::core::= name "do") (:mal::eval-do (:wat::core::rest xs) env st))
        ((:wat::core::= name "if") (:mal::eval-if xs env st))
        ((:wat::core::= name "fn*") (:mal::eval-fn xs env))
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
    [:mal::Val.Atom {:id i} (:mal::ok ast)]))

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
      (:mal::repl env st))))
