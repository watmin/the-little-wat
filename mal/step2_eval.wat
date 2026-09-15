;; mal/step2_eval.wat: Make-a-Lisp step 2, eval over a fixed environment of + - * /.
;;
;; Driven by mal's own runner through tools/mal-shim.py (tools/mal-test.sh step2_eval): each
;; input line arrives as one EDN string, and each output line goes back as one, then :mal/done
;; (FINDINGS F-049, F-050). Keyword spelling throughout.

(:wat::load-file! "lib/types.wat")
(:wat::load-file! "lib/reader.wat")
(:wat::load-file! "lib/printer.wat")

;; the environment: four builtins, by name
(:wat::core::defn :mal::lookup [name <- :wat::core::String] -> :mal::Res
  (:wat::core::if (:wat::core::or (:wat::core::or (:wat::core::= name "+") (:wat::core::= name "-"))
                                  (:wat::core::or (:wat::core::= name "*") (:wat::core::= name "/")))
    (:mal::ok (:mal::builtin name))
    (:mal::fail (:wat::string::concat "'" name "' not found"))))

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

(:wat::core::defn :mal::eval-all [xs <- :mal::Vals acc <- :mal::Vals] -> :mal::Many
  (:wat::core::if (:wat::core::empty? xs)
    (:mal::many acc)
    (:wat::core::match (:mal::eval (:wat::core::first xs))
      [:mal::Res.Ok {:v v} (:mal::eval-all (:wat::core::rest xs) (:wat::core::conj acc v))]
      [:mal::Res.Err {:e e} (:mal::many-err e)])))

;; a map's values are evaluated; its keys are not
(:wat::core::defn :mal::eval-kvs [kvs <- :mal::Vals acc <- :mal::Vals] -> :mal::Many
  (:wat::core::if (:wat::core::empty? kvs)
    (:mal::many acc)
    (:wat::core::match (:mal::eval (:wat::core::second kvs))
      [:mal::Res.Ok {:v v} (:mal::eval-kvs (:wat::core::rest (:wat::core::rest kvs)) (:wat::core::conj (:wat::core::conj acc (:wat::core::first kvs)) v))]
      [:mal::Res.Err {:e e} (:mal::many-err e)])))

(:wat::core::defn :mal::eval [ast <- :mal::Val] -> :mal::Res
  (:wat::core::match ast
    [:mal::Val.Sym {:name name} (:mal::lookup name)]
    [:mal::Val.List {:items xs}
      (:wat::core::if (:wat::core::empty? xs)
        (:mal::ok ast)
        (:wat::core::match (:mal::eval-all xs (:wat::core::Vector :- [:mal::Val]))
          [:mal::Many.Ok {:vs vs} (:mal::apply (:wat::core::first vs) (:wat::core::rest vs))]
          [:mal::Many.Err {:e e} (:mal::err e)]))]
    [:mal::Val.Vec {:items xs}
      (:wat::core::match (:mal::eval-all xs (:wat::core::Vector :- [:mal::Val]))
        [:mal::Many.Ok {:vs vs} (:mal::ok (:mal::vec vs))]
        [:mal::Many.Err {:e e} (:mal::err e)])]
    [:mal::Val.Map {:kvs kvs}
      (:wat::core::match (:mal::eval-kvs kvs (:wat::core::Vector :- [:mal::Val]))
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

(:wat::core::defn :mal::rep [line <- :wat::core::String] -> :mal::Strs
  (:wat::core::match (:mal::read-str line)
    [:mal::Read.Got {:v v :next j} (:wat::core::Vector :- [:wat::core::String] (:mal::pr-res (:mal::eval v)))]
    [:mal::Read.Failed {:msg m} (:wat::core::Vector :- [:wat::core::String] m)]
    [:mal::Read.Empty {} (:wat::core::Vector :- [:wat::core::String])]))

(:wat::core::defn :mal::print-lines [lines <- :mal::Strs] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? lines)
    nil
    (:wat::core::do
      (:wat::kernel::println (:wat::core::first lines))
      (:mal::print-lines (:wat::core::rest lines)))))

(:wat::core::defn :mal::repl [] -> :wat::core::nil
  (:wat::core::match (:wat::kernel::read-frame)
    [:wat::kernel::ReadFrameOutcome.Frame {:text t}
      (:wat::core::do
        (:mal::print-lines (:mal::rep (:wat::edn::read t)))
        (:wat::kernel::println :mal/done)
        (:mal::repl))]
    [:wat::kernel::ReadFrameOutcome.Eof {} nil]
    [:wat::kernel::ReadFrameOutcome.Stopped {} nil]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:mal::repl))
