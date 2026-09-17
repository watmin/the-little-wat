;; probes/paip/multiple-dispatch.wat — does a wat surface dispatch on more than `self`?
;;
;; PAIP chapter 13's generic functions pick a method by looking at EVERY argument, so
;; `collide(asteroid, ship)` and `collide(asteroid, asteroid)` run different code although the
;; first argument is the same. C-073 found wat better equipped than expected on the single-dispatch
;; side, so this asks the next question.
;;
;; Answer (F-109, measured 2026-09-16, wat-rs a3218644d): **single dispatch only.** A concrete type
;; may extend a surface at exactly ONE type parameter. Two extensions of the same type are refused
;; at startup, and the message says why:
;;
;;     (:wat::core::extend-type :d::Asteroid (:d::Collide :- [:d::Ship])     (hit …))
;;     (:wat::core::extend-type :d::Asteroid (:d::Collide :- [:d::Asteroid]) (hit …))
;;     => "duplicate define: :d::Asteroid/hit already registered"
;;
;; The method lives at `<Type>/<feature>` -- a name with no room for the argument types -- so no
;; parameterisation of the surface can recover the second axis. That pair of lines cannot live in
;; this file, because the refusal is a startup error; what runs below is the single dispatch that
;; DOES work, plus the hand-built table that is the only route to the other.

(:wat::core::defsurface :d::Collide :- [T] :nature :wat::core::Struct
  :features [(hit [self <- (:d::Collide :- [T]) other <- T] -> :wat::core::String)])

(:wat::core::defstruct :d::Asteroid [])
(:wat::core::defstruct :d::Ship [])

;; single dispatch on `self` works: two types, two implementations, chosen by the receiver
(:wat::core::extend-type :d::Asteroid (:d::Collide :- [:wat::core::i64])
  (hit [self other] -> :wat::core::String "asteroid hits something"))
(:wat::core::extend-type :d::Ship (:d::Collide :- [:wat::core::i64])
  (hit [self other] -> :wat::core::String "ship hits something"))

;; the second axis, by hand: a table keyed by the TUPLE of tags (SICP §2.4's shape, C-078)
(:wat::core::typealias :d::Fn [:wat::core::String :wat::core::String :-> :wat::core::String])

(:wat::core::defn :d::table [] -> (:wat::core::HashMap :- [:wat::core::String :d::Fn])
  (:wat::core::assoc
    (:wat::core::assoc (:wat::core::HashMap :- [:wat::core::String :d::Fn])
      "asteroid/ship" (:wat::core::fn [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String
                        "ship destroyed"))
    "asteroid/asteroid" (:wat::core::fn [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String
                          "both shatter")))

(:wat::core::defn :d::dispatch2 [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:wat::core::get (:d::table) (:wat::string::concat a "/" b))
    [:wat::core::Option.Some {:value f} (f a b)]
    [:wat::core::Option.None {} "no method"]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- single dispatch on self: the LANGUAGE does this ----")
    (:wat::kernel::println (:d::Collide/hit (:d::Asteroid) 1))
    (:wat::kernel::println (:d::Collide/hit (:d::Ship) 1))

    (:wat::kernel::println "---- dispatch on the second argument: only a TABLE does this ----")
    (:wat::kernel::println (:d::dispatch2 "asteroid" "ship"))
    (:wat::kernel::println (:d::dispatch2 "asteroid" "asteroid"))
    (:wat::kernel::println (:d::dispatch2 "ship" "asteroid"))

    (:wat::kernel::println "---- refused at startup, so recorded rather than run ----")
    (:wat::kernel::println "  a second extend-type on :d::Asteroid =>")
    (:wat::kernel::println "  \"duplicate define: :d::Asteroid/hit already registered\"")))
