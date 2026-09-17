;; eopl/ch02-data-abstraction.wat — EOPL chapter 2: data abstraction and representation
;; independence.
;;
;; The chapter's claim: a client written against an INTERFACE does not change when the
;; REPRESENTATION does. EOPL demonstrates it by building the environment three ways -- an
;; association list, a ribcage, and a PROCEDURE -- behind `empty-env`, `extend-env`, `apply-env`.
;;
;; The natural wat encoding is a parametric surface plus three `extend-type` implementations. It
;; does not work: a generic client over `(:c2::Env :- [R])` is refused at every call site, which
;; is **F-029** for the third time in this repository (The Little MLer ch 10, A Little Java's
;; visitor, and now here). The refused version is kept verbatim as
;; `probes/eopl/ch02-surface-blocked.wat`, because a chapter whose entire subject is
;; representation independence is the sharpest possible demonstration of what F-029 costs.
;;
;; So this file takes the route F-029 already names as the working one: a DICTIONARY -- a generic
;; struct of functions (C-023). The client is still written exactly once and still never learns
;; its representation; the abstraction is just carried by a struct rather than by a surface.
;;
;; The third representation is the one worth the trip: the environment IS a closure, `String ->
;; i64`, and `extend` returns a new closure that shadows the old. wat instantiates the dictionary's
;; type parameter at a FUNCTION TYPE, which is the chapter's punchline surviving the port.

(:wat::core::defstruct :c2::EnvOps :- [R]
  [empty  <- R
   extend <- [R :wat::core::String :wat::core::i64 :-> R]
   apply  <- [R :wat::core::String :-> :wat::core::i64]])

;; ---- representation 1: an association list ----
(:wat::core::defenum :c2::AList :wat::enum::Pure
  :ANil [] :ACons [name <- :wat::core::String  v <- :wat::core::i64  rest <- :c2::AList])

(:wat::core::defn :c2::alist-apply [e <- :c2::AList name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match e
    [:c2::AList.ANil {} -1]
    [:c2::AList.ACons {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:c2::alist-apply rest name))]))

;; NOTE: `:empty` cannot be written as the bare variant literal here. A generic parameter
;; inferred from `(:c2::AList.ANil {})` binds to the VARIANT type `:c2::AList.ANil`, not to the
;; enum, and then every other field is checked against the wrong R:
;;   ":c2::EnvOps: parameter #2 expects [:c2::AList.ANil … :-> :c2::AList.ANil];
;;                 got [:c2::AList … :-> :c2::AList]"
;; Routing it through a function with a declared return type pins R to the enum. See F-107.
(:wat::core::defn :c2::alist-empty [] -> :c2::AList (:c2::AList.ANil {}))

(:wat::core::defn :c2::as-alist [] -> (:c2::EnvOps :- [:c2::AList])
  (:c2::EnvOps
    :empty (:c2::alist-empty)
    :extend (:wat::core::fn [e <- :c2::AList name <- :wat::core::String v <- :wat::core::i64] -> :c2::AList
      (:c2::AList.ACons {:name name :v v :rest e}))
    :apply (:wat::core::fn [e <- :c2::AList name <- :wat::core::String] -> :wat::core::i64
      (:c2::alist-apply e name))))

;; ---- representation 2: a ribcage — each frame holds a VECTOR of names and one of values ----
(:wat::core::defenum :c2::Rib :wat::enum::Pure
  :RNil []
  :RCons [names <- (:wat::core::Vector :- [:wat::core::String])
          vals  <- (:wat::core::Vector :- [:wat::core::i64])
          rest  <- :c2::Rib])

(:wat::core::defn :c2::rib-scan
  [names <- (:wat::core::Vector :- [:wat::core::String]) name <- :wat::core::String
   i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length names)) -1
    (:wat::core::if (:wat::core::= (:wat::core::nth names i) name) i
      (:c2::rib-scan names name (:wat::core::+ i 1)))))

(:wat::core::defn :c2::rib-apply [e <- :c2::Rib name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match e
    [:c2::Rib.RNil {} -1]
    [:c2::Rib.RCons {:names names :vals vals :rest rest}
      (:wat::core::let [i (:c2::rib-scan names name 0)]
        (:wat::core::if (:wat::core::>= i 0) (:wat::core::nth vals i)
          (:c2::rib-apply rest name)))]))

(:wat::core::defn :c2::rib-empty [] -> :c2::Rib (:c2::Rib.RNil {}))

(:wat::core::defn :c2::as-ribcage [] -> (:c2::EnvOps :- [:c2::Rib])
  (:c2::EnvOps
    :empty (:c2::rib-empty)
    ;; one binding per frame here; the point is the LAYOUT, not the batching
    :extend (:wat::core::fn [e <- :c2::Rib name <- :wat::core::String v <- :wat::core::i64] -> :c2::Rib
      (:c2::Rib.RCons {:names (:wat::core::Vector :- [:wat::core::String] name)
                       :vals (:wat::core::Vector :- [:wat::core::i64] v)
                       :rest e}))
    :apply (:wat::core::fn [e <- :c2::Rib name <- :wat::core::String] -> :wat::core::i64
      (:c2::rib-apply e name))))

;; ---- representation 3: the environment IS a procedure ----
(:wat::core::typealias :c2::Fn [:wat::core::String :-> :wat::core::i64])

(:wat::core::defn :c2::as-proc [] -> (:c2::EnvOps :- [:c2::Fn])
  (:c2::EnvOps
    :empty (:wat::core::fn [n <- :wat::core::String] -> :wat::core::i64 -1)
    ;; extend returns a NEW closure that shadows the old one -- no data structure anywhere
    :extend (:wat::core::fn [e <- :c2::Fn name <- :wat::core::String v <- :wat::core::i64] -> :c2::Fn
      (:wat::core::fn [n <- :wat::core::String] -> :wat::core::i64
        (:wat::core::if (:wat::core::= n name) v (e n))))
    :apply (:wat::core::fn [e <- :c2::Fn name <- :wat::core::String] -> :wat::core::i64 (e name))))

;; ---- ONE client, generic over the representation. It never learns which it has. ----
(:wat::core::defn :c2::client :- [R] [d <- (:c2::EnvOps :- [R]) name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [ext (:c2::EnvOps/extend d)
                    app (:c2::EnvOps/apply d)
                    e1 (ext (:c2::EnvOps/empty d) "x" 10)
                    e2 (ext e1 "y" 20)
                    ;; shadowing must work in all three, and it is what each representation gets
                    ;; wrong differently if `extend` is written carelessly
                    e3 (ext e2 "x" 99)]
    (app e3 name)))

(:wat::core::defn :c2::row [label <- :wat::core::String got <- :wat::core::i64 want <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " (:wat::i64::to-string got)
      (:wat::core::if (:wat::core::= got want) "   PASS" "   FAIL"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- EOPL ch2: one client, three representations ----")
    (:wat::kernel::println "  env = extend(extend(extend(empty, x=10), y=20), x=99)")

    (:wat::kernel::println "-- lookup x (shadowed, must be 99) --")
    (:c2::row "association list " (:c2::client (:c2::as-alist) "x") 99)
    (:c2::row "ribcage          " (:c2::client (:c2::as-ribcage) "x") 99)
    (:c2::row "a PROCEDURE      " (:c2::client (:c2::as-proc) "x") 99)

    (:wat::kernel::println "-- lookup y (must be 20) --")
    (:c2::row "association list " (:c2::client (:c2::as-alist) "y") 20)
    (:c2::row "ribcage          " (:c2::client (:c2::as-ribcage) "y") 20)
    (:c2::row "a PROCEDURE      " (:c2::client (:c2::as-proc) "y") 20)

    (:wat::kernel::println "-- lookup an unbound name (must report, not guess) --")
    (:c2::row "association list " (:c2::client (:c2::as-alist) "z") -1)
    (:c2::row "ribcage          " (:c2::client (:c2::as-ribcage) "z") -1)
    (:c2::row "a PROCEDURE      " (:c2::client (:c2::as-proc) "z") -1)

    (:wat::kernel::println "---- what the port shows ----")
    (:wat::kernel::println "  :c2::client is written ONCE and never learns its representation.")
    (:wat::kernel::println "  The third one has no data structure at all -- the environment is a")
    (:wat::kernel::println "  closure, and the dictionary's type parameter is instantiated at a")
    (:wat::kernel::println "  FUNCTION TYPE, [String :-> i64]. That is the chapter's punchline.")
    (:wat::kernel::println "  Written with a SURFACE instead, this is refused -- F-029, third")
    (:wat::kernel::println "  sighting; see probes/eopl/ch02-surface-blocked.wat.")))
