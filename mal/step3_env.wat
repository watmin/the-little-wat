;; mal/step3_env.wat: Make-a-Lisp step 3, environments: def! and let*.
;;
;; The environments live on a store service (lib/env.wat). Driven by mal's own runner through
;; tools/mal-shim.py (tools/mal-test.sh step3_env): each input line arrives as one EDN string,
;; and each output line goes back as one, then :mal/done (FINDINGS F-049, F-050). Keyword
;; spelling throughout.

(:wat::load-file! "lib/types.wat")
(:wat::load-file! "lib/reader.wat")
(:wat::load-file! "lib/printer.wat")
(:wat::load-file! "lib/env.wat")

(:wat::core::defn :mal::arith [name <- :wat::core::String a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= name "+") (:wat::core::+ a b))
    ((:wat::core::= name "-") (:wat::core::- a b))
    ((:wat::core::= name "*") (:wat::core::* a b))
    (:else (:wat::core::/ a b))))

(:wat::core::defn :mal::call-builtin [name <- :wat::core::String args <- :mal::Vals] -> :mal::Res
  (:wat::core::if (:wat::core::not (:wat::core::= (:wat::core::length args) 2))
    (:mal::fail (:wat::string::concat name ": expected 2 arguments"))
    (:wat::core::match (:mal::int-of (:wat::core::first args))
      [:wat::core::Option.Some {:value a}
        (:wat::core::match (:mal::int-of (:wat::core::second args))
          [:wat::core::Option.Some {:value b} (:mal::ok (:mal::int (:mal::arith name a b)))]
          [:wat::core::Option.None {} (:mal::fail (:wat::string::concat name ": expected numbers"))])]
      [:wat::core::Option.None {} (:mal::fail (:wat::string::concat name ": expected numbers"))])))

(:wat::core::defn :mal::apply [f <- :mal::Val args <- :mal::Vals] -> :mal::Res
  (:wat::core::match (:mal::builtin-of f)
    [:wat::core::Option.Some {:value name} (:mal::call-builtin name args)]
    [:wat::core::Option.None {} (:mal::fail (:wat::string::concat (:mal::pr-str f true) " is not a function"))]))

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

;; bind each name in turn, in env, each value evaluated in env (so later ones see earlier ones)
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

(:wat::core::defn :mal::eval-apply [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match (:mal::eval-all xs (:wat::core::Vector :- [:mal::Val]) env st)
    [:mal::Many.Ok {:vs vs} (:mal::apply (:wat::core::first vs) (:wat::core::rest vs))]
    [:mal::Many.Err {:e e} (:mal::err e)]))

(:wat::core::defn :mal::eval-list [xs <- :mal::Vals env <- :wat::core::i64 st <- :mal::StoreRef] -> :mal::Res
  (:wat::core::match (:mal::sym-of (:wat::core::first xs))
    [:wat::core::Option.Some {:value name}
      (:wat::core::cond
        ((:wat::core::= name "def!") (:mal::eval-def xs env st))
        ((:wat::core::= name "let*") (:mal::eval-let xs env st))
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
    [:mal::Read.Got {:v v :next j} (:wat::core::Vector :- [:wat::core::String] (:mal::pr-res (:mal::eval v env st)))]
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

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [st (:mal::new-store)
                    env (:mal::new-env! st -1)]
    (:wat::core::do
      (:mal::env-set! st env "+" (:mal::builtin "+"))
      (:mal::env-set! st env "-" (:mal::builtin "-"))
      (:mal::env-set! st env "*" (:mal::builtin "*"))
      (:mal::env-set! st env "/" (:mal::builtin "/"))
      (:mal::repl env st))))
