;; probes/eopl/ch02-surface-blocked.wat — EOPL ch2's representation independence, written the
;; way the chapter asks for it, and REFUSED. This is F-029's third independent sighting.
;;
;; The chapter's claim is that one client works against three representations. The natural wat
;; encoding is a parametric surface `(:c2::Env :- [R])` with three `extend-type` implementations
;; and ONE generic client. That client is refused, nine times over, at every call site:
;;
;;   :c2::client: parameter #1 expects (:c2::Env :- [:?3559]); got :c2::AsAList
;;   :c2::client: parameter #1 expects (:c2::Env :- [:?3560]); got :c2::AsRibcage
;;   :c2::client: parameter #1 expects (:c2::Env :- [:?3561]); got :c2::AsProc
;;
;; Same mechanism as F-029: a surface bound holding a fresh variable never equals the
;; extend-type edge's literal parametric string. Pinning R concretely works
;; (`(:c2::Env :- [:c2::AList])` accepts `:c2::AsAList`) -- which is exactly the "write the
;; functor once per structure" defeat F-029 already records.
;;
;; Checked 2026-09-16, wat-rs a3218644d. THIS FILE IS EXPECTED TO FAIL AT STARTUP; it is the
;; evidence, not a test. The working port is eopl/ch02-data-abstraction.wat, which uses the
;; dictionary route (C-023) instead.
;;
;; New here over the two earlier sightings: adding a second argument of type R does NOT rescue it
;; (`[d <- (:c2::Env :- [R]) seed <- R]` is refused the same way), so the variable is not resolved
;; from elsewhere in the signature -- the surface argument itself has to be the thing that pins it,
;; and it cannot.

(:wat::core::defsurface :c2::Env :- [R] :nature :wat::core::Struct
  :features [(empty  [self <- (:c2::Env :- [R])] -> R)
             (extend [self <- (:c2::Env :- [R]) e <- R  name <- :wat::core::String
                      v <- :wat::core::i64] -> R)
             (apply  [self <- (:c2::Env :- [R]) e <- R  name <- :wat::core::String] -> :wat::core::i64)])

;; ---- representation 1: an association list ----
(:wat::core::defenum :c2::AList :wat::enum::Pure
  :ANil [] :ACons [name <- :wat::core::String  v <- :wat::core::i64  rest <- :c2::AList])

(:wat::core::defstruct :c2::AsAList [])
(:wat::core::extend-type :c2::AsAList (:c2::Env :- [:c2::AList])
  (empty [self] -> :c2::AList (:c2::AList.ANil {}))
  (extend [self e name v] -> :c2::AList (:c2::AList.ACons {:name name :v v :rest e}))
  (apply [self e name] -> :wat::core::i64
    (:wat::core::match e
      [:c2::AList.ANil {} -1]
      [:c2::AList.ACons {:name n :v v :rest rest}
        (:wat::core::if (:wat::core::= n name) v (:c2::Env/apply self rest name))])))

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

(:wat::core::defstruct :c2::AsRibcage [])
(:wat::core::extend-type :c2::AsRibcage (:c2::Env :- [:c2::Rib])
  (empty [self] -> :c2::Rib (:c2::Rib.RNil {}))
  ;; one binding per frame here; the point is the LAYOUT, not the batching
  (extend [self e name v] -> :c2::Rib
    (:c2::Rib.RCons {:names (:wat::core::Vector :- [:wat::core::String] name)
                     :vals (:wat::core::Vector :- [:wat::core::i64] v)
                     :rest e}))
  (apply [self e name] -> :wat::core::i64
    (:wat::core::match e
      [:c2::Rib.RNil {} -1]
      [:c2::Rib.RCons {:names names :vals vals :rest rest}
        (:wat::core::let [i (:c2::rib-scan names name 0)]
          (:wat::core::if (:wat::core::>= i 0) (:wat::core::nth vals i)
            (:c2::Env/apply self rest name)))])))

;; ---- representation 3: the environment IS a procedure ----
(:wat::core::typealias :c2::Fn [:wat::core::String :-> :wat::core::i64])

(:wat::core::defstruct :c2::AsProc [])
(:wat::core::extend-type :c2::AsProc (:c2::Env :- [:c2::Fn])
  (empty [self] -> :c2::Fn (:wat::core::fn [n <- :wat::core::String] -> :wat::core::i64 -1))
  ;; extend returns a NEW closure that shadows the old one -- no data structure anywhere
  (extend [self e name v] -> :c2::Fn
    (:wat::core::fn [n <- :wat::core::String] -> :wat::core::i64
      (:wat::core::if (:wat::core::= n name) v (e n))))
  (apply [self e name] -> :wat::core::i64 (e name)))

;; ---- ONE client, generic over the representation. It never learns which it has. ----
(:wat::core::defn :c2::client :- [R] [d <- (:c2::Env :- [R]) name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [e0 (:c2::Env/empty d)
                    e1 (:c2::Env/extend d e0 "x" 10)
                    e2 (:c2::Env/extend d e1 "y" 20)
                    ;; shadowing must work in all three, and it is the case each representation
                    ;; gets wrong differently if `extend` is written carelessly
                    e3 (:c2::Env/extend d e2 "x" 99)]
    (:c2::Env/apply d e3 name)))

(:wat::core::defn :c2::row [label <- :wat::core::String got <- :wat::core::i64 want <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " (:wat::i64::to-string got)
      (:wat::core::if (:wat::core::= got want) "   PASS" "   FAIL"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- EOPL ch2: one client, three representations ----")
    (:wat::kernel::println "  env = extend(extend(extend(empty, x=10), y=20), x=99)")

    (:wat::kernel::println "-- lookup x (shadowed, must be 99) --")
    (:c2::row "association list " (:c2::client (:c2::AsAList) "x") 99)
    (:c2::row "ribcage          " (:c2::client (:c2::AsRibcage) "x") 99)
    (:c2::row "a PROCEDURE      " (:c2::client (:c2::AsProc) "x") 99)

    (:wat::kernel::println "-- lookup y (must be 20) --")
    (:c2::row "association list " (:c2::client (:c2::AsAList) "y") 20)
    (:c2::row "ribcage          " (:c2::client (:c2::AsRibcage) "y") 20)
    (:c2::row "a PROCEDURE      " (:c2::client (:c2::AsProc) "y") 20)

    (:wat::kernel::println "-- lookup an unbound name (must report, not guess) --")
    (:c2::row "association list " (:c2::client (:c2::AsAList) "z") -1)
    (:c2::row "ribcage          " (:c2::client (:c2::AsRibcage) "z") -1)
    (:c2::row "a PROCEDURE      " (:c2::client (:c2::AsProc) "z") -1)

    (:wat::kernel::println "---- what the port shows ----")
    (:wat::kernel::println "  :c2::client is written ONCE and never learns its representation.")
    (:wat::kernel::println "  The third one has no data structure at all -- the environment is a")
    (:wat::kernel::println "  closure, and wat instantiates the surface's type parameter at a")
    (:wat::kernel::println "  FUNCTION TYPE, [String :-> i64]. That is the chapter's punchline.")))
